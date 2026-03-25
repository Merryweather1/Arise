import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/firestore_service.dart';

// ─── PROVIDERS ────────────────────────────────────────────────────────────
final pomodoroFocusMinsProvider = StateProvider<int>((ref) => 25);
final pomodoroShortBreakMinsProvider = StateProvider<int>((ref) => 5);
final pomodoroLongBreakMinsProvider = StateProvider<int>((ref) => 15);
final pomodoroSessionsUntilLongProvider = StateProvider<int>((ref) => 4);

// ─── MODELS ───────────────────────────────────────────────────────────────
enum PomodoroPhase { focus, shortBreak, longBreak }

// ─── SCREEN ───────────────────────────────────────────────────────────────
class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with TickerProviderStateMixin {
// ─── STATE ────────────────────────────────────────────────────────────────
  PomodoroPhase _phase = PomodoroPhase.focus;
  bool _running = false;
  bool _handlingCompletion = false;
  int _secondsLeft = 25 * 60;
  int _cycleCompleted = 0;
  String? _currentTask;

  Timer? _timer;

  // Animations
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _secondsLeft = ref.read(pomodoroFocusMinsProvider) * 60;
        });
      }
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get _totalSeconds {
    switch (_phase) {
      case PomodoroPhase.focus:
        return ref.watch(pomodoroFocusMinsProvider) * 60;
      case PomodoroPhase.shortBreak:
        return ref.watch(pomodoroShortBreakMinsProvider) * 60;
      case PomodoroPhase.longBreak:
        return ref.watch(pomodoroLongBreakMinsProvider) * 60;
    }
  }

  double get _progress {
    if (_totalSeconds == 0) return 0;
    return 1 - (_secondsLeft / _totalSeconds);
  }

  Color get _phaseColor {
    switch (_phase) {
      case PomodoroPhase.focus:
        return AColors.primary;
      case PomodoroPhase.shortBreak:
        return AColors.info;
      case PomodoroPhase.longBreak:
        return AColors.warning;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case PomodoroPhase.focus:
        return 'Focus';
      case PomodoroPhase.shortBreak:
        return 'Short Break';
      case PomodoroPhase.longBreak:
        return 'Long Break';
    }
  }

  String get _timeString {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PomodoroPhase _nextPhaseAfterCompletion(PomodoroPhase current) {
    if (current == PomodoroPhase.focus) {
      final nextCount = _cycleCompleted + 1;
      final sessionsUntilLong = ref.read(pomodoroSessionsUntilLongProvider);
      return nextCount % sessionsUntilLong == 0
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
    }
    return PomodoroPhase.focus;
  }

  PomodoroPhase _nextPhaseAfterSkip(PomodoroPhase current) {
    switch (current) {
      case PomodoroPhase.focus:
        return PomodoroPhase.shortBreak;
      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        return PomodoroPhase.focus;
    }
  }

  void _startStop() {
    HapticFeedback.mediumImpact();

    if (_running) {
      _timer?.cancel();
      _pulseCtrl.stop();
      setState(() => _running = false);
      return;
    }

    _pulseCtrl.repeat(reverse: true);
    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_running || _handlingCompletion) return;

      if (_secondsLeft > 1) {
        if (mounted) {
          setState(() => _secondsLeft--);
        }
      } else {
        if (mounted) {
          setState(() => _secondsLeft = 0);
        }
        await _onPhaseComplete();
      }
    });
  }

  void _reset() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() {
      _running = false;
      _secondsLeft = _totalSeconds;
    });
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _pulseCtrl.stop();

    final nextPhase = _nextPhaseAfterSkip(_phase);

    setState(() {
      _running = false;
      if (_phase == PomodoroPhase.longBreak) {
        _cycleCompleted = 0;
      }
    });

    _setPreparedPhase(nextPhase);
  }

  Future<void> _onPhaseComplete() async {
    if (_handlingCompletion) return;
    _handlingCompletion = true;

    _timer?.cancel();
    _pulseCtrl.stop();

    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 120),
      HapticFeedback.mediumImpact,
    );

    final uid = ref.read(currentUidProvider);
    final completedPhase = _phase;
    final nextPhase = _nextPhaseAfterCompletion(completedPhase);

    if (completedPhase == PomodoroPhase.focus) {
      if (mounted) {
        setState(() {
          _cycleCompleted++;
          _running = false;
        });
      }

      if (uid != null && uid.isNotEmpty) {
        final focusMins = ref.read(pomodoroFocusMinsProvider);
        debugPrint('Pomodoro complete: phase=$_phase uid=$uid focus=$focusMins');
        await PomodoroRepository.logSession(
          uid,
          durationMinutes: focusMins,
          linkedTaskTitle: _currentTask,
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _running = false;
          if (completedPhase == PomodoroPhase.longBreak) {
            _cycleCompleted = 0;
          }
        });
      }
    }

    if (!mounted) {
      _handlingCompletion = false;
      return;
    }

    _showCompletionDialog(
      completedPhase: completedPhase,
      nextPhase: nextPhase,
    );

    _handlingCompletion = false;
  }

  void _setPreparedPhase(PomodoroPhase phase) {
    setState(() {
      _phase = phase;
      _running = false;
      _secondsLeft = _phaseSeconds(phase);
    });
  }

  int _phaseSeconds(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.focus:
        return ref.read(pomodoroFocusMinsProvider) * 60;
      case PomodoroPhase.shortBreak:
        return ref.read(pomodoroShortBreakMinsProvider) * 60;
      case PomodoroPhase.longBreak:
        return ref.read(pomodoroLongBreakMinsProvider) * 60;
    }
  }

  void _proceedToNextPhase(PomodoroPhase nextPhase, {required bool autoStart}) {
    _setPreparedPhase(nextPhase);
    if (autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startStop();
      });
    }
  }

  void _setPhase(PomodoroPhase phase) {
    if (_running) return;
    HapticFeedback.selectionClick();
    setState(() {
      _phase = phase;
      _secondsLeft = _totalSeconds;
    });
  }

  void _showCompletionDialog({
    required PomodoroPhase completedPhase,
    required PomodoroPhase nextPhase,
  }) {
    final completedFocus = completedPhase == PomodoroPhase.focus;
    final nextIsBreak = nextPhase != PomodoroPhase.focus;
    final nextLabel = nextPhase == PomodoroPhase.focus
        ? 'Start Focus'
        : nextPhase == PomodoroPhase.longBreak
        ? 'Start Long Break'
        : 'Start Break';

    final title = completedFocus ? '🎉 Session Complete!' : '⏰ Break Finished!';
    final body = completedFocus
        ? nextIsBreak
        ? 'Nice work. You can close this or start your break now.'
        : 'Nice work. You can close this or start your next focus session now.'
        : 'Break is over. You can close this or start focusing again.';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AColors.bgElevated,
        shape: const RoundedRectangleBorder(borderRadius: ARadius.xl),
        title: Text(
          title,
          style: AText.titleLarge,
          textAlign: TextAlign.center,
        ),
        content: Text(
          body,
          style: AText.bodyLarge,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _proceedToNextPhase(nextPhase, autoStart: false);
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: AColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _proceedToNextPhase(nextPhase, autoStart: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AColors.gradientPrimary,
                borderRadius: ARadius.full,
              ),
              child: Text(
                nextLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(
        onSettingsChanged: () {
          final sessionsUntilLong = ref.read(pomodoroSessionsUntilLongProvider);
          setState(() {
            if (_cycleCompleted > sessionsUntilLong) {
              _cycleCompleted = _cycleCompleted % sessionsUntilLong;
            }

            if (!_running) {
              _secondsLeft = _totalSeconds;
            }
          });
        },
      ),
    );
  }

  void _pickTask() async {
    final ctrl = TextEditingController(text: _currentTask ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AColors.bgElevated,
          shape: const RoundedRectangleBorder(borderRadius: ARadius.xl),
          title: const Text(
            'What are you working on?',
            style: AText.titleMedium,
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: AText.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'e.g. Write feature spec...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
              child: const Text(
                'Set',
                style: TextStyle(
                  color: AColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() => _currentTask = result.isEmpty ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AColors.bg,
      body: SafeArea(
        child: uid == null || uid.isEmpty
            ? const Center(
          child: Text(
            'Sign in to use Pomodoro',
            style: AText.bodyMedium,
          ),
        )
            : StreamBuilder<List<PomodoroSession>>(
          stream: PomodoroRepository.streamRecent(uid, days: 30),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];
            final today = _dateOnly(DateTime.now());
            final todaySessions = sessions
                .where((s) => _dateOnly(s.date) == today)
                .toList();
            final totalFocusToday = todaySessions.fold<int>(
              0,
                  (sum, s) => sum + s.durationMinutes,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pomodoro', style: AText.displayMedium),
                            Text('Stay in the zone', style: AText.bodyMedium),
                          ],
                        ),
                      ),
                      _IconBtn(
                        icon: Icons.settings_rounded,
                        onTap: _showSettings,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PhaseSelector(
                    current: _phase,
                    enabled: !_running,
                    onSelect: _setPhase,
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickTask,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AColors.bgCard,
                              borderRadius: ARadius.full,
                              border: Border.all(color: AColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.task_alt_rounded,
                                  size: 14,
                                  color: _phaseColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _currentTask ?? 'Set focus task',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _currentTask != null
                                        ? AColors.textPrimary
                                        : AColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: AColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        LayoutBuilder(
                          builder: (_, __) {
                            final size = (MediaQuery.of(context).size.height * 0.32)
                                .clamp(180.0, 260.0);

                            return ScaleTransition(
                              scale: _running
                                  ? _pulseAnim
                                  : const AlwaysStoppedAnimation(1.0),
                              child: SizedBox(
                                width: size,
                                height: size,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: size,
                                      height: size,
                                      decoration: BoxDecoration(
                                        color: AColors.bgCard,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AColors.border,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _phaseColor.withValues(
                                              alpha: _running ? 0.2 : 0.08,
                                            ),
                                            blurRadius: 40,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: _progress),
                                      duration: const Duration(milliseconds: 300),
                                      builder: (_, val, __) => SizedBox(
                                        width: size - 20,
                                        height: size - 20,
                                        child: CircularProgressIndicator(
                                          value: val,
                                          strokeWidth: 8,
                                          backgroundColor: AColors.bgElevated,
                                          valueColor:
                                          AlwaysStoppedAnimation(_phaseColor),
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _timeString,
                                          style: const TextStyle(
                                            fontSize: 58,
                                            fontWeight: FontWeight.w800,
                                            color: AColors.textPrimary,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _phaseLabel,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _phaseColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CircleBtn(
                              icon: Icons.replay_rounded,
                              size: 52,
                              color: AColors.textMuted,
                              bgColor: AColors.bgCard,
                              onTap: _reset,
                            ),
                            const SizedBox(width: 20),
                            _CircleBtn(
                              icon: _running
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 72,
                              color: Colors.white,
                              bgColor: _phaseColor,
                              onTap: _startStop,
                              glow: _running,
                              glowColor: _phaseColor,
                            ),
                            const SizedBox(width: 20),
                            _CircleBtn(
                              icon: Icons.skip_next_rounded,
                              size: 52,
                              color: AColors.textMuted,
                              bgColor: AColors.bgCard,
                              onTap: _skip,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _SessionDots(
                          completed: _cycleCompleted,
                          total: ref.watch(pomodoroSessionsUntilLongProvider),
                          color: _phaseColor,
                        ),
                      ],
                    ),
                  ),
                ),

                _StatsBar(
                  sessionsToday: todaySessions.length,
                  focusMinutes: totalFocusToday,
                  cycleDone: _cycleCompleted,
                  cycleTotal: ref.watch(pomodoroSessionsUntilLongProvider),
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── PHASE SELECTOR ───────────────────────────────────────────────────────
class _PhaseSelector extends StatelessWidget {
  final PomodoroPhase current;
  final bool enabled;
  final Function(PomodoroPhase) onSelect;

  const _PhaseSelector({
    required this.current,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.md,
        border: Border.all(color: AColors.border),
      ),
      child: Row(
        children: PomodoroPhase.values.map((phase) {
          final sel = current == phase;
          final label = phase == PomodoroPhase.focus
              ? 'Focus'
              : phase == PomodoroPhase.shortBreak
              ? 'Short Break'
              : 'Long Break';
          final color = phase == PomodoroPhase.focus
              ? AColors.primary
              : phase == PomodoroPhase.shortBreak
              ? AColors.info
              : AColors.warning;

          return Expanded(
            child: GestureDetector(
              onTap: enabled ? () => onSelect(phase) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: sel ? color.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: ARadius.sm,
                  border: sel
                      ? Border.all(color: color.withValues(alpha: 0.5))
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? color : AColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── SESSION DOTS ─────────────────────────────────────────────────────────
class _SessionDots extends StatelessWidget {
  final int completed;
  final int total;
  final Color color;

  const _SessionDots({
    required this.completed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            total,
                (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: i < completed ? 20 : 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i < completed ? color : AColors.bgCard,
                borderRadius: ARadius.full,
                border: Border.all(
                  color: i < completed ? color : AColors.border,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('$completed / $total in cycle', style: AText.bodySmall),
      ],
    );
  }
}

// ─── STATS BAR ────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final int sessionsToday;
  final int focusMinutes;
  final int cycleDone;
  final int cycleTotal;

  const _StatsBar({
    required this.sessionsToday,
    required this.focusMinutes,
    required this.cycleDone,
    required this.cycleTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.lg,
        border: Border.all(color: AColors.border),
      ),
      child: Row(
        children: [
          _Stat(label: 'Sessions', value: '$sessionsToday', icon: '🍅'),
          const _Divider(),
          _Stat(label: 'Focus Time', value: '${focusMinutes}m', icon: '⏱️'),
          const _Divider(),
          _Stat(label: 'Cycle', value: '$cycleDone/$cycleTotal', icon: '🔁'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: AText.titleMedium),
        Text(label, style: AText.bodySmall),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 40,
    color: AColors.border,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

// ─── SETTINGS SHEET ───────────────────────────────────────────────────────
class _SettingsSheet extends ConsumerWidget {
  final VoidCallback onSettingsChanged;

  const _SettingsSheet({
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(pomodoroFocusMinsProvider);
    final short = ref.watch(pomodoroShortBreakMinsProvider);
    final long = ref.watch(pomodoroLongBreakMinsProvider);
    final sessions = ref.watch(pomodoroSessionsUntilLongProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AColors.border,
                borderRadius: ARadius.full,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Timer Settings', style: AText.titleLarge),
          const SizedBox(height: 24),
          _TimerRow(
            label: 'Focus',
            emoji: '🎯',
            color: AColors.primary,
            value: focus,
            min: 5,
            max: 60,
            step: 5,
            onChanged: (v) {
              ref.read(pomodoroFocusMinsProvider.notifier).state = v;
              onSettingsChanged();
            },
          ),
          const SizedBox(height: 16),
          _TimerRow(
            label: 'Short Break',
            emoji: '☕',
            color: AColors.info,
            value: short,
            min: 1,
            max: 15,
            step: 1,
            onChanged: (v) {
              ref.read(pomodoroShortBreakMinsProvider.notifier).state = v;
              onSettingsChanged();
            },
          ),
          const SizedBox(height: 16),
          _TimerRow(
            label: 'Long Break',
            emoji: '🛌',
            color: AColors.warning,
            value: long,
            min: 5,
            max: 30,
            step: 5,
            onChanged: (v) {
              ref.read(pomodoroLongBreakMinsProvider.notifier).state = v;
              onSettingsChanged();
            },
          ),
          const SizedBox(height: 16),
          _TimerRow(
            label: 'Sessions until long break',
            emoji: '🔁',
            color: AColors.primary,
            value: sessions,
            min: 2,
            max: 6,
            step: 1,
            onChanged: (v) {
              ref.read(pomodoroSessionsUntilLongProvider.notifier).state = v;
              onSettingsChanged();
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.mediumImpact();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AColors.gradientPrimary,
                  borderRadius: ARadius.lg,
                ),
                child: const Center(
                  child: Text(
                    'Close Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerRow extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final int value;
  final int min;
  final int max;
  final int step;
  final Function(int) onChanged;

  const _TimerRow({
    required this.label,
    required this.emoji,
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AText.bodyLarge)),
        GestureDetector(
          onTap: value > min
              ? () {
            onChanged(value - step);
            HapticFeedback.selectionClick();
          }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: value > min
                  ? color.withValues(alpha: 0.12)
                  : AColors.bgCard,
              borderRadius: ARadius.sm,
              border: Border.all(
                color: value > min
                    ? color.withValues(alpha: 0.3)
                    : AColors.border,
              ),
            ),
            child: Icon(
              Icons.remove_rounded,
              size: 16,
              color: value > min ? color : AColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Center(
            child: Text(
              '$value',
              style: AText.titleSmall.copyWith(color: color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: value < max
              ? () {
            onChanged(value + step);
            HapticFeedback.selectionClick();
          }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: value < max
                  ? color.withValues(alpha: 0.12)
                  : AColors.bgCard,
              borderRadius: ARadius.sm,
              border: Border.all(
                color: value < max
                    ? color.withValues(alpha: 0.3)
                    : AColors.border,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 16,
              color: value < max ? color : AColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool glow;
  final Color? glowColor;

  const _CircleBtn({
    required this.icon,
    required this.size,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.glow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
          BoxShadow(
            color: (glowColor ?? bgColor).withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ]
            : null,
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.md,
        border: Border.all(color: AColors.border),
      ),
      child: Icon(icon, color: AColors.textPrimary, size: 22),
    ),
  );
}