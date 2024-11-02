// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

const int DEFAULT_SESSION_MINUTES = 25;
const int DEFAULT_BREAK_MINUTES = 5;
const int MINUTE = 60;

void main() => runApp(const MyApp());

enum TimerState {
  sessionTime,
  breakTime,
}

enum AppTheme {
  light,
  dark,
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<TimerState> timerStateNotifier =
      ValueNotifier(TimerState.sessionTime);
  final ValueNotifier<AppTheme> appThemeNotifier = ValueNotifier(AppTheme.dark);

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

  const PomidoriTimer({
    super.key,
    required this.timerStateNotifier,
    required this.appThemeNotifier,
  });

  @override
  State<PomidoriTimer> createState() => _PomidoriTimerState();
}

class _PomidoriTimerState extends State<PomidoriTimer>
    with SingleTickerProviderStateMixin {
  late Timer _timer;

  bool paused = true;
  int seconds = DEFAULT_SESSION_MINUTES * MINUTE;
  int sessionSeconds = DEFAULT_SESSION_MINUTES * MINUTE;
  int breakSeconds = DEFAULT_BREAK_MINUTES * MINUTE;

  @override
  void initState() {
    super.initState();
    widget.timerStateNotifier.addListener(_onTimerStateChange);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.timerStateNotifier.removeListener(_onTimerStateChange);
    super.dispose();
  }

  void _onTimerStateChange() {
    setState(() {
      seconds = widget.timerStateNotifier.value == TimerState.sessionTime
          ? sessionSeconds
          : breakSeconds;
    });
  }

  void _toggleBreak() async {
    TimerState current = widget.timerStateNotifier.value;
    widget.timerStateNotifier.value = current == TimerState.sessionTime
        ? TimerState.breakTime
        : TimerState.sessionTime;

    setState(() {
      seconds =
          current == TimerState.sessionTime ? breakSeconds : sessionSeconds;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        seconds--;
        if (seconds < 0) {
          _timer.cancel();
          setState(() {
            paused = true;
          });
          _toggleBreak();

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
      });
    });
  }

  void _toggleTimer() {
    setState(() {
      paused = !paused;
    });
  }

  void _resetTimer() {
    _timer.cancel();
    setState(() {
      seconds = widget.timerStateNotifier.value == TimerState.sessionTime
          ? sessionSeconds
          : breakSeconds;
      paused = true;
    });
  }

  String renderTimer(int seconds) {
    int displayMinutes = seconds ~/ 60;
    int displaySeconds = seconds % 60;
    return '${displayMinutes.toString().padLeft(2, '0')}:${displaySeconds.toString().padLeft(2, '0')}';
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Usage of Pomidori'),
          content: const Text(
            '• Tap anywhere on the screen to Play/Pause the timer.\n'
            '• Double Tap on the screen to switch between Session and Break modes.\n'
            '• Long Press anywhere on the screen to Reset the timer.\n'
            '• Top Right Icon to switch between Light and Dark themes.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
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
              : Colors.blue;
    } else {
      backgroundColor = Colors.black;
    }

    Color iconColor;
    if (currentTheme == AppTheme.dark) {
      iconColor = widget.timerStateNotifier.value == TimerState.sessionTime
          ? Colors.red
          : Colors.blue;
    } else {
      iconColor = Colors.white70;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: backgroundColor,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (paused) {
                _startTimer();
                HapticFeedback.mediumImpact();
              } else {
                _timer.cancel();
                HapticFeedback.mediumImpact();
              }

              _toggleTimer();
            },
            onDoubleTap: () {
              HapticFeedback.heavyImpact();
              _toggleBreak();
            },
            onLongPress: () {
              HapticFeedback.heavyImpact();
              _resetTimer();
            },
            splashColor: Colors.white24,
            splashFactory: InkRipple.splashFactory,
            child: Stack(
              children: [
                Positioned(
                  top: 20,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _showInfoDialog,
                  ),
                ),
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
    );
  }
}
