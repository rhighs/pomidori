// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

const int DEFAULT_SESSION_MINUTES = 25;
const int DEFAULT_BREAK_MINUTES = 5;
const int MINUTE = 60;

void main() => runApp(const MyApp());

enum TimerState {
  sessionTime,
  breakTime,
}

String timerStateStr(TimerState ts) =>
    ts == TimerState.sessionTime ? 'SESSION_TIME' : 'BREAK_TIME';

enum AppTheme {
  light,
  dark,
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class Settings {
  int sessionMinutes;
  int breakMinutes;
  bool soundEnabled;
  bool vibrationEnabled;

  Settings({
    this.sessionMinutes = DEFAULT_SESSION_MINUTES,
    this.breakMinutes = DEFAULT_BREAK_MINUTES,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  Settings copyWith({
    int? sessionMinutes,
    int? breakMinutes,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return Settings(
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<TimerState> timerStateNotifier =
      ValueNotifier(TimerState.sessionTime);
  final ValueNotifier<AppTheme> appThemeNotifier = ValueNotifier(AppTheme.dark);
  final ValueNotifier<Settings> settingsNotifier = ValueNotifier(Settings());

  @override
  void dispose() {
    timerStateNotifier.dispose();
    appThemeNotifier.dispose();
    settingsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, appTheme, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Pomidori',
          themeMode:
              appTheme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.light,
              seedColor: timerStateNotifier.value == TimerState.sessionTime
                  ? Colors.red
                  : Colors.blue,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: timerStateNotifier.value == TimerState.sessionTime
                  ? Colors.red
                  : Colors.blue,
            ),
            scaffoldBackgroundColor: Colors.black,
            useMaterial3: true,
          ),
          home: Scaffold(
            body: PomidoriTimer(
              timerStateNotifier: timerStateNotifier,
              appThemeNotifier: appThemeNotifier,
              settingsNotifier: settingsNotifier,
            ),
          ),
        );
      },
    );
  }
}

class PomidoriTimer extends StatefulWidget {
  final ValueNotifier<TimerState> timerStateNotifier;
  final ValueNotifier<AppTheme> appThemeNotifier;
  final ValueNotifier<Settings> settingsNotifier;

  const PomidoriTimer({
    super.key,
    required this.timerStateNotifier,
    required this.appThemeNotifier,
    required this.settingsNotifier,
  });

  @override
  State<PomidoriTimer> createState() => _PomidoriTimerState();
}

class SoundBoard {
  final AudioPlayer _pausePlayer = AudioPlayer();
  final AudioPlayer _switchPlayer = AudioPlayer();
  final AudioPlayer _resetPlayer = AudioPlayer();

  SoundBoard() {
    _init();
  }

  Future<void> _init() async {
    _pausePlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      if (kDebugMode) {
        print('pause_player: a stream error occurred: $e');
      }
    });
    _switchPlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      if (kDebugMode) {
        print('switch_player: A stream error occurred: $e');
      }
    });
    _resetPlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      if (kDebugMode) {
        print('reset_playre: a stream error occurred: $e');
      }
    });

    await _pausePlayer.setAsset('assets/pomo-click.wav');
    await _switchPlayer.setAsset('assets/pomo-switch.wav');
    await _resetPlayer.setAsset('assets/pomo-reset.wav');
  }

  Future<void> clickSound() async =>
      await _pausePlayer.seek(Duration.zero).then((_) => _pausePlayer.play());
  Future<void> swtichSound() async =>
      await _switchPlayer.seek(Duration.zero).then((_) => _switchPlayer.play());
  Future<void> resetSound() async =>
      await _resetPlayer.seek(Duration.zero).then((_) => _resetPlayer.play());

  void dispose() {
    _pausePlayer.dispose();
    _switchPlayer.dispose();
    _resetPlayer.dispose();
  }
}

class _PomidoriTimerState extends State<PomidoriTimer>
    with SingleTickerProviderStateMixin {
  bool paused = true;
  int seconds = DEFAULT_SESSION_MINUTES * MINUTE;
  int sessionSeconds = DEFAULT_SESSION_MINUTES * MINUTE;
  int breakSeconds = DEFAULT_BREAK_MINUTES * MINUTE;
  SoundBoard soundBoard = SoundBoard();

  Timer? _timer;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    widget.settingsNotifier.addListener(_onSettingsChange);
    sessionSeconds = widget.settingsNotifier.value.sessionMinutes * MINUTE;
    breakSeconds = widget.settingsNotifier.value.breakMinutes * MINUTE;
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.settingsNotifier.removeListener(_onSettingsChange);
    soundBoard.dispose();
    super.dispose();
  }

  void _onSettingsChange() {
    setState(() {
      sessionSeconds = widget.settingsNotifier.value.sessionMinutes * MINUTE;
      breakSeconds = widget.settingsNotifier.value.breakMinutes * MINUTE;
      if (widget.timerStateNotifier.value == TimerState.sessionTime) {
        seconds = sessionSeconds;
      } else {
        seconds = breakSeconds;
      }
    });
  }

  TimerState _currentState() => widget.timerStateNotifier.value;

  TimerState _nextState() {
    TimerState current = _currentState();
    if (kDebugMode) {
      print("TimerState current -> ${timerStateStr(current)}");
    }

    var newState = current == TimerState.sessionTime
        ? TimerState.breakTime
        : TimerState.sessionTime;
    widget.timerStateNotifier.value = newState;

    if (kDebugMode) {
      print("TimerState next -> ${timerStateStr(newState)}");
    }

    return newState;
  }

  void _setSeconds(TimerState state) => setState(() {
        seconds =
            state == TimerState.sessionTime ? sessionSeconds : breakSeconds;
      });

  void _startTimer() {
    if (!paused) {
      return;
    }

    // ensure timer restarts if double called
    if (_timer != null && _timer!.isActive) {
      return;
    }

    setState(() {
      paused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        seconds--;
        if (seconds < 0) {
          _stopTimer();
          _setSeconds(_nextState());
          _timerEndFeedback();
        }
      });
    });
  }

  void _stopTimer() {
    if (paused) {
      return;
    }

    setState(() {
      paused = true;
    });
    _timer?.cancel();
  }

  void _timerEndFeedback() {
    if (widget.settingsNotifier.value.vibrationEnabled) {
      Vibration.hasVibrator().then((v) {
        if (v ?? false) {
          if (widget.timerStateNotifier.value == TimerState.sessionTime) {
            Vibration.vibrate(duration: 3000, amplitude: 255);
          } else {
            Vibration.vibrate(
                pattern: List.generate(6, (_) => [200, 400])
                    .expand((x) => x)
                    .toList(),
                intensities: List.generate(6, (_) => [100, 255])
                    .expand((x) => x)
                    .toList());
          }
        }
      });
    }
  }

  void _tapFeedback() async {
    if (widget.settingsNotifier.value.soundEnabled) {
      await soundBoard.clickSound();
    }
    if (widget.settingsNotifier.value.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void _doubleTapFeedback() async {
    if (widget.settingsNotifier.value.soundEnabled) {
      await soundBoard.swtichSound();
    }
    if (widget.settingsNotifier.value.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _longPressFeedback() async {
    if (widget.settingsNotifier.value.soundEnabled) {
      await soundBoard.resetSound();
    }
    if (widget.settingsNotifier.value.vibrationEnabled) {
      Vibration.vibrate(duration: 1000, amplitude: 255);
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.blueGrey[900],
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'How to use Pomidori',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              _buildUsageRow(
                  Icons.play_arrow, 'Tap anywhere to Play/Pause the timer'),
              const SizedBox(height: 10),
              _buildUsageRow(Icons.replay,
                  'Double Tap to switch between Session and Break modes'),
              const SizedBox(height: 10),
              _buildUsageRow(Icons.restore, 'Long Press to Reset the timer'),
              const SizedBox(height: 10),
              _buildUsageRow(Icons.brightness_6,
                  'Top Right Icon to switch between Light and Dark themes'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsageRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.blueGrey[900],
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'About Pomidori',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pomidori is an open-source app designed to help you manage your time efficiently.\n\n'
                'Created with ❤️ by rhighs.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri githubUrl =
                      Uri.parse('https://github.com/rhighs/pomidori');
                  if (await canLaunchUrl(githubUrl)) {
                    await launchUrl(githubUrl);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch the URL')),
                    );
                  }
                },
                icon: const Icon(Icons.code, color: Colors.white),
                label: const Text(
                  'View Source Code on GitHub',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri coffeeUrl =
                      Uri.parse('https://buymeacoffee.com/rhighs');
                  if (await canLaunchUrl(coffeeUrl)) {
                    await launchUrl(coffeeUrl);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch the URL')),
                    );
                  }
                },
                icon: const Icon(Icons.coffee, color: Colors.white),
                label: const Text(
                  'Support on Buy Me a Coffee',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          settingsNotifier: widget.settingsNotifier,
        ),
      ),
    );
  }

  String renderTimer(int seconds) {
    int displayMinutes = seconds ~/ 60;
    int displaySeconds = seconds % 60;
    return '${displayMinutes.toString().padLeft(2, '0')}:${displaySeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme currentTheme = widget.appThemeNotifier.value;
    double fontSize = MediaQuery.of(context).size.width * 0.3;

    Color backgroundColor;
    if (currentTheme == AppTheme.light) {
      backgroundColor =
          widget.timerStateNotifier.value == TimerState.sessionTime
              ? Colors.red
              : Colors.blueGrey;
    } else {
      backgroundColor = Colors.black;
    }

    Color iconColor;
    if (currentTheme == AppTheme.dark) {
      iconColor = widget.timerStateNotifier.value == TimerState.sessionTime
          ? Colors.red
          : Colors.blueGrey;
    } else {
      iconColor = Colors.white70;
    }

    return Scaffold(
      key: _scaffoldKey,
      endDrawerEnableOpenDragGesture: false,
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              child: Text(
                'Pomidori',
                style: TextStyle(fontSize: 32),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                _showInfoDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
          ],
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: backgroundColor,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _tapFeedback();
                if (paused) {
                  _startTimer();
                } else {
                  _stopTimer();
                }
              },
              onDoubleTap: () {
                _doubleTapFeedback();
                _stopTimer();
                _setSeconds(_nextState());
              },
              onLongPress: () {
                _longPressFeedback();
                _stopTimer();
                _setSeconds(_currentState());
              },
              splashColor: Colors.white24,
              splashFactory: InkRipple.splashFactory,
              child: Stack(
                children: [
                  Positioned(
                      top: 20,
                      left: 20,
                      child: IconButton(
                        icon: const Icon(Icons.menu,
                            color: Colors.white, size: 30),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      )),
                  Positioned(
                    top: 30,
                    width: MediaQuery.of(context).size.width,
                    child: Center(
                      child: Icon(
                        paused ? Icons.play_arrow : Icons.pause,
                        color: iconColor,
                        size: 30,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: Icon(
                        currentTheme == AppTheme.dark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        widget.appThemeNotifier.value =
                            widget.appThemeNotifier.value == AppTheme.dark
                                ? AppTheme.light
                                : AppTheme.dark;
                      },
                    ),
                  ),
                  Center(
                    child: Text(
                      renderTimer(seconds),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.varelaRound(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: currentTheme == AppTheme.light
                              ? Colors.white
                              : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final ValueNotifier<Settings> settingsNotifier;

  const SettingsPage({super.key, required this.settingsNotifier});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _sessionController;
  late TextEditingController _breakController;
  late bool _soundEnabled;
  late bool _vibrationEnabled;

  @override
  void initState() {
    super.initState();
    _sessionController = TextEditingController(
        text: widget.settingsNotifier.value.sessionMinutes.toString());
    _breakController = TextEditingController(
        text: widget.settingsNotifier.value.breakMinutes.toString());
    _soundEnabled = widget.settingsNotifier.value.soundEnabled;
    _vibrationEnabled = widget.settingsNotifier.value.vibrationEnabled;
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _breakController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    int sessionMinutes =
        int.tryParse(_sessionController.text) ?? DEFAULT_SESSION_MINUTES;
    int breakMinutes =
        int.tryParse(_breakController.text) ?? DEFAULT_BREAK_MINUTES;

    if (sessionMinutes < 1) sessionMinutes = 1;
    if (breakMinutes < 1) breakMinutes = 1;

    widget.settingsNotifier.value = widget.settingsNotifier.value.copyWith(
      sessionMinutes: sessionMinutes,
      breakMinutes: breakMinutes,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _sessionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Session Minutes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _breakController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Break Minutes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Enable Sound'),
              value: _soundEnabled,
              onChanged: (bool value) {
                setState(() {
                  _soundEnabled = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Enable Vibration'),
              value: _vibrationEnabled,
              onChanged: (bool value) {
                setState(() {
                  _vibrationEnabled = value;
                });
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
