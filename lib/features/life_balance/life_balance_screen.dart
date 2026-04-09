import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class LifeSphere {
  final String id, name;
  final IconData iconData;
  final Color color;
  double score; // 0..10

  LifeSphere({
    required this.id,
    required this.name,
    required this.iconData,
    required this.color,
    this.score = 5.0,
  });
}

class LifeBalanceScreen extends ConsumerStatefulWidget {
  const LifeBalanceScreen({super.key});

  @override
  ConsumerState<LifeBalanceScreen> createState() => _LifeBalanceScreenState();
}

class _LifeBalanceScreenState extends ConsumerState<LifeBalanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Neutral defaults (NOT fake success data). Real values come from Firestore snapshots.
  final List<LifeSphere> _spheres = [
    LifeSphere(id: 'health', name: 'Health', iconData: Icons.fitness_center_rounded, color: const Color(0xFF00C97B), score: 5.0),
    LifeSphere(id: 'career', name: 'Career', iconData: Icons.work_outline_rounded, color: const Color(0xFF4D9FFF), score: 5.0),
    LifeSphere(id: 'finance', name: 'Finance', iconData: Icons.attach_money_rounded, color: const Color(0xFFFFD700), score: 5.0),
    LifeSphere(id: 'relations', name: 'Relations', iconData: Icons.favorite_border_rounded, color: const Color(0xFFFF6B9D), score: 5.0),
    LifeSphere(id: 'learning', name: 'Learning', iconData: Icons.menu_book_rounded, color: const Color(0xFFBF7FF5), score: 5.0),
    LifeSphere(id: 'mindset', name: 'Mindset', iconData: Icons.psychology_rounded, color: const Color(0xFFFF8C69), score: 5.0),
    LifeSphere(id: 'social', name: 'Social', iconData: Icons.people_outline_rounded, color: const Color(0xFF00D4D4), score: 5.0),
    LifeSphere(id: 'fun', name: 'Fun', iconData: Icons.sports_esports_rounded, color: const Color(0xFFFF6B6B), score: 5.0),
  ];

  bool _loadedFromFirestore = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _loadLatestIfNeeded(LifeBalanceSnapshot? latest) {
    if (_loadedFromFirestore || latest == null) return;
    _loadedFromFirestore = true;

    setState(() {
      for (final s in _spheres) {
        final v = latest.scores[s.id];
        if (v != null) {
          s.score = v.clamp(0.0, 10.0);
        }
      }
    });
  }

  double get _overallScore =>
      _spheres.fold(0.0, (sum, s) => sum + s.score) / _spheres.length;

  String get _balanceLabel {
    final score = _overallScore;
    if (score >= 8) return 'Thriving';
    if (score >= 6.5) return 'Balanced';
    if (score >= 5) return 'Growing';
    if (score >= 3.5) return 'Struggling';
    return 'Needs Attention';
  }

  Future<void> _saveSnapshot() async {
    HapticFeedback.mediumImpact();
    final scores = Map<String, double>.fromEntries(
      _spheres.map((s) => MapEntry(s.id, s.score)),
    );

    await ref.read(lifeBalanceActionsProvider.notifier).saveSnapshot(scores);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Balance snapshot saved'),
        backgroundColor: AColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: ARadius.md),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = ref.watch(lifeBalanceProvider).valueOrNull ?? <LifeBalanceSnapshot>[];
    final latest = ref.watch(latestBalanceProvider);

    _loadLatestIfNeeded(latest);

    final history = snapshots
        .map(
          (snap) => _BalanceSnapshot(
        date: snap.date,
        scores: Map<String, double>.from(snap.scores),
      ),
    )
        .toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AColors.bg,
      body: SafeArea(
        child: Column(
          children: [
                  Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Life Balance', style: AText.displayMedium),
                      Text('How balanced is your life?', style: AText.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ATabBar(controller: _tabCtrl, tabs: const ['Adjust', 'History']),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _AdjustTab(
                    spheres: _spheres,
                    overallScore: _overallScore,
                    balanceLabel: _balanceLabel,
                    onChanged: (s, v) => setState(() => s.score = v),
                    onSave: _saveSnapshot,
                  ),
                  _HistoryTab(spheres: _spheres, history: history),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceSnapshot {
  final DateTime date;
  final Map<String, double> scores;
  _BalanceSnapshot({required this.date, required this.scores});
}

class _AdjustTab extends StatelessWidget {
  final List<LifeSphere> spheres;
  final double overallScore;
  final String balanceLabel;
  final Function(LifeSphere, double) onChanged;
  final Future<void> Function() onSave;

  const _AdjustTab({
    required this.spheres,
    required this.overallScore,
    required this.balanceLabel,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        _RadarChart(spheres: spheres, size: 280),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AColors.gradientPrimary,
            borderRadius: ARadius.lg,
            boxShadow: [
              BoxShadow(
                color: AColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      balanceLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    overallScore.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...spheres.map((s) => _SphereSlider(sphere: s, onChanged: (v) => onChanged(s, v))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onSave,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AColors.gradientPrimary,
              borderRadius: ARadius.lg,
              boxShadow: [
                BoxShadow(
                  color: AColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Save Snapshot',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarChart extends StatelessWidget {
  final List<LifeSphere> spheres;
  final double size;

  const _RadarChart({required this.spheres, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RadarPainter(spheres: spheres)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<LifeSphere> spheres;

  _RadarPainter({required this.spheres});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;
    final n = spheres.length;

    for (int ring = 1; ring <= 5; ring++) {
      final r = radius * ring / 5;
      final paint = Paint()
        ..color = AColors.border.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = (2 * math.pi * i / n) - math.pi / 2;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    final spokePaint = Paint()
      ..color = AColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 1;

    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      canvas.drawLine(
        center,
        Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
        spokePaint,
      );
    }

    final fillPath = Path();
    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      final r = radius * spheres[i].score / 10;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = AColors.primary.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = AColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      final r = radius * spheres[i].score / 10;
      final dotX = center.dx + r * math.cos(angle);
      final dotY = center.dy + r * math.sin(angle);

      final labelR = radius + 22;
      final labelX = center.dx + labelR * math.cos(angle);
      final labelY = center.dy + labelR * math.sin(angle);

      canvas.drawCircle(
        Offset(dotX, dotY),
        5,
        Paint()
          ..color = spheres[i].color
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        Offset(dotX, dotY),
        5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(spheres[i].iconData.codePoint),
          style: TextStyle(
            fontSize: 16,
            fontFamily: spheres[i].iconData.fontFamily,
            package: spheres[i].iconData.fontPackage,
            color: spheres[i].color,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(labelX - tp.width / 2, labelY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}

class _SphereSlider extends StatelessWidget {
  final LifeSphere sphere;
  final Function(double) onChanged;

        _SphereSlider({required this.sphere, required this.onChanged});

  String get _scoreLabel {
    final s = sphere.score;
    if (s >= 9) return 'Excellent';
    if (s >= 7) return 'Good';
    if (s >= 5) return 'Average';
    if (s >= 3) return 'Needs Work';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:       EdgeInsets.only(bottom: 14),
      child: Container(
        padding:       EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: AColors.bgCard,
          borderRadius: ARadius.lg,
          border: Border.all(color: AColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sphere.iconData, size: 20, color: sphere.color),
                const SizedBox(width: 10),
                Expanded(child: Text(sphere.name, style: AText.titleSmall)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sphere.color.withValues(alpha: 0.12),
                    borderRadius: ARadius.full,
                  ),
                  child: Text(
                    '${sphere.score.toStringAsFixed(1)} • $_scoreLabel',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sphere.color),
                  ),
                ),
              ],
            ),
                  SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: sphere.color,
                thumbColor: sphere.color,
                inactiveTrackColor: AColors.border,
                overlayColor: sphere.color.withValues(alpha: 0.15),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: sphere.score,
                min: 0,
                max: 10,
                divisions: 20,
                onChanged: (v) {
                  onChanged(v);
                  HapticFeedback.selectionClick();
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['0', '2.5', '5', '7.5', '10']
                  .map((l) => Text(l, style: AText.bodySmall))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<LifeSphere> spheres;
  final List<_BalanceSnapshot> history;

        _HistoryTab({required this.spheres, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:       [
            Icon(Icons.explore_off_rounded, size: 52, color: AColors.primary),
            SizedBox(height: 16),
            Text('No snapshots yet', style: AText.titleMedium),
            SizedBox(height: 6),
            Text('Save your first balance check', style: AText.bodyMedium),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        Text('Trends (recent)', style: AText.titleSmall),
        const SizedBox(height: 12),
        ...spheres.map((s) => _TrendRow(sphere: s, history: history)),
        const SizedBox(height: 24),
        Text('Saved Snapshots', style: AText.titleSmall),
        const SizedBox(height: 12),
        ...history.reversed.map((snap) => _SnapshotCard(snap: snap, spheres: spheres)),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  final LifeSphere sphere;
  final List<_BalanceSnapshot> history;

  const _TrendRow({required this.sphere, required this.history});

  @override
  Widget build(BuildContext context) {
    final scores = history.map((h) => h.scores[sphere.id] ?? 0.0).toList();
    final latest = scores.isNotEmpty ? scores.last : 0.0;
    final prev = scores.length > 1 ? scores[scores.length - 2] : latest;
    final trend = latest - prev;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AColors.bgCard,
          borderRadius: ARadius.lg,
          border: Border.all(color: AColors.border),
        ),
        child: Row(
          children: [
            Icon(sphere.iconData, size: 18, color: sphere.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(sphere.name, style: AText.bodyLarge),
                      const Spacer(),
                      Text(
                        latest.toStringAsFixed(1),
                        style: AText.titleSmall.copyWith(color: sphere.color),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        trend > 0.1
                            ? Icons.arrow_upward_rounded
                            : trend < -0.1
                            ? Icons.arrow_downward_rounded
                            : Icons.remove_rounded,
                        size: 14,
                        color: trend > 0.1
                            ? AColors.primary
                            : trend < -0.1
                            ? AColors.error
                            : AColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 28,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: scores.map((score) {
                        final frac = (score / 10).clamp(0.0, 1.0);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: 28 * frac,
                              decoration: BoxDecoration(
                                color: sphere.color.withValues(alpha: frac > 0.6 ? 0.8 : 0.35),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final _BalanceSnapshot snap;
  final List<LifeSphere> spheres;

  const _SnapshotCard({required this.snap, required this.spheres});

  @override
  Widget build(BuildContext context) {
    final avg = snap.scores.isEmpty
        ? 0.0
        : snap.scores.values.fold(0.0, (a, b) => a + b) / snap.scores.length;

    final isToday = DateUtils.isSameDay(snap.date, DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AColors.bgCard,
          borderRadius: ARadius.lg,
          border: Border.all(
            color: isToday ? AColors.primary.withValues(alpha: 0.4) : AColors.border,
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isToday ? 'Today' : DateFormat('EEE, MMM d').format(snap.date),
                  style: AText.titleSmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AColors.primaryGlow,
                    borderRadius: ARadius.full,
                  ),
                  child: Text(
                    'Avg ${avg.toStringAsFixed(1)}',
                    style:       TextStyle(
                      color: AColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: spheres.map((s) {
                final score = snap.scores[s.id] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.1),
                    borderRadius: ARadius.full,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.iconData, size: 12, color: s.color),
                      const SizedBox(width: 4),
                      Text(
                        score.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s.color,
                    ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ATabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _ATabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AColors.bgCard,
        borderRadius: ARadius.md,
        border: Border.all(color: AColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: AColors.gradientPrimary,
          borderRadius: ARadius.md,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: AText.labelLarge,
        labelColor: Colors.white,
        unselectedLabelColor: AColors.textMuted,
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}