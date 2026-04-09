import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';

// ─── SCREEN ───────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<double> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<double>(begin: 40, end: 0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _editName(UserProfile profile) async {
    final ctrl = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        title:       Text('Edit Name',
            style: TextStyle(
                color: AColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: AColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: AColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF0E1117),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AColors.primary.withAlpha(60)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AColors.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:       Text('Cancel',
                style: TextStyle(color: AColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child:       Text('Save',
                style: TextStyle(
                    color: AColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != profile.name) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        await UserRepository.update(uid, {'name': result});
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Name updated'),
              backgroundColor: AColors.primary.withAlpha(200),
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        title:       Text('Sign Out',
            style: TextStyle(color: AColors.textPrimary, fontWeight: FontWeight.w700)),
        content:       Text('Are you sure you want to sign out?',
            style: TextStyle(color: AColors.textMuted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:       Text('Cancel',
                style: TextStyle(color: AColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Sign out from Firebase AND clear the Google session so that
      // the account picker is shown on the next sign-in attempt.
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    // Always use the live Firebase Auth email — Firestore's copy may be stale
    final liveEmail = FirebaseAuth.instance.currentUser?.email
        ?? profile?.email
        ?? '';

    return Scaffold(
      backgroundColor: AColors.bg,
      body: AnimatedBuilder(
        animation: _entryCtrl,
        builder: (_, child) => Opacity(
          opacity: _entryFade.value,
          child: Transform.translate(
            offset: Offset(0, _entrySlide.value),
            child: child,
          ),
        ),
        child: Stack(
          children: [
            // Ethereal Top Glow
            Positioned(
              top: -150,
              left: -100,
              right: -100,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AColors.primary.withValues(alpha: 0.1),
                      blurRadius: 150,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(context, profile),
            if (profile != null) ...[
              SliverToBoxAdapter(child: _HeroCard(profile: profile, email: liveEmail, onEditName: () => _editName(profile))),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _XpSphereRow(profile: profile)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(child: _AccountSection(profile: profile, email: liveEmail)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _AppSettingsSection(profile: profile)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _DangerSection(onSignOut: _signOut)),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ] else ...[
                    SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AColors.primary, strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, UserProfile? profile) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF16191F),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2A2E3A)),
            ),
            child:       Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: AColors.textPrimary),
          ),
        ),
      ),
      title:       Text(
        'Profile',
        style: TextStyle(
            color: AColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3),
      ),
      centerTitle: true,
    );
  }
}

// ─── HERO CARD ────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final UserProfile profile;
  final String email;
  final VoidCallback onEditName;

  const _HeroCard({required this.profile, required this.email, required this.onEditName});

  // Deterministic avatar gradient from uid
  List<Color> _avatarGradient() {
    final hash = profile.uid.hashCode.abs();
    const palettes = [
      [Color(0xFF00C97B), Color(0xFF006B42)],
      [Color(0xFF7B61FF), Color(0xFF3D30D0)],
      [Color(0xFFFFB800), Color(0xFFB07000)],
      [Color(0xFF00BFFF), Color(0xFF005E80)],
      [Color(0xFFFF6B6B), Color(0xFF8B0000)],
    ];
    return palettes[hash % palettes.length];
  }

  String _initials() {
    final parts = profile.name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _avatarGradient();
    final pct = (profile.combinedProgress * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AColors.bgSleek,
              AColors.bg,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
              color: gradient[0].withValues(alpha: 0.15), width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AColors.bgElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: gradient[0], width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: gradient[0].withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF080A0F), width: 2),
                        ),
                        child: const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFF003D25)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Name + level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style:       TextStyle(
                                  color: AColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onEditName,
                            child:       Icon(Icons.edit_rounded,
                                size: 15, color: AColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email.isEmpty ? 'No email' : email,
                        style:       TextStyle(
                            color: AColors.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradient[0].withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: gradient[0].withAlpha(60), width: 1),
                        ),
                        child: Text(
                          'Level ${profile.combinedLevel} · Arise',
                          style: TextStyle(
                              color: gradient[0],
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Combined XP bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                          Text('Overall XP',
                        style: TextStyle(
                            color: AColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Text('$pct% to Level ${profile.combinedLevel + 1}',
                        style: TextStyle(
                            color: gradient[0],
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: profile.combinedProgress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 7,
                      backgroundColor: const Color(0xFF1E2230),
                      valueColor: AlwaysStoppedAnimation<Color>(gradient[0]),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${profile.totalXp} XP total',
                    style:       TextStyle(
                        color: AColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── XP SPHERE ROW ────────────────────────────────────────────────────────
class _XpSphereRow extends StatelessWidget {
  final UserProfile profile;
  const _XpSphereRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _SphereCard(
            label: 'Willpower',
            icon: Icons.bolt_rounded,
            xp: profile.willpowerXp,
            level: profile.willpowerLevel,
            progress: profile.willpowerProgress,
            color: const Color(0xFF7B61FF),
          ),
          const SizedBox(width: 10),
          _SphereCard(
            label: 'Intellect',
            icon: Icons.psychology_rounded,
            xp: profile.intellectXp,
            level: profile.intellectLevel,
            progress: profile.intellectProgress,
            color: const Color(0xFF00BFFF),
          ),
          const SizedBox(width: 10),
          _SphereCard(
            label: 'Health',
            icon: Icons.fitness_center_rounded,
            xp: profile.healthXp,
            level: profile.healthLevel,
            progress: profile.healthProgress,
            color: const Color(0xFF00C97B),
          ),
        ],
      ),
    );
  }
}

class _SphereCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int xp, level;
  final double progress;
  final Color color;

  const _SphereCard({
    required this.label,
    required this.icon,
    required this.xp,
    required this.level,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AColors.bgSleek,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20, spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              'Lv $level',
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:       TextStyle(
                  color: AColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            // Arc progress
            _ArcProgress(progress: progress, color: color, size: 48),
            const SizedBox(height: 6),
            Text(
              '$xp XP',
              style: TextStyle(color: AColors.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcProgress extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;

  const _ArcProgress(
      {required this.progress, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, val, __) => SizedBox(
        width: size,
        height: size * 0.5,
        child: CustomPaint(
          painter: _ArcPainter(progress: val, color: color),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = color.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
        2, 2, size.width - 4, (size.width - 4));
    const startAngle = pi;
    const sweepAngle = pi;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);
    canvas.drawArc(
        rect, startAngle, sweepAngle * progress, false, fillPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─── ACCOUNT SECTION ──────────────────────────────────────────────────────
class _AccountSection extends StatelessWidget {
  final UserProfile profile;
  final String email;

  const _AccountSection({required this.profile, required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('ACCOUNT',
                style: TextStyle(
                    color: AColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.mail_outline_rounded,
                iconColor: const Color(0xFF00BFFF),
                label: 'Email',
                trailing: Text(
                  email.isEmpty
                      ? 'Not set'
                      : (email.length > 24
                          ? '${email.substring(0, 24)}…'
                          : email),
                  style:       TextStyle(
                      color: AColors.textMuted, fontSize: 13),
                ),
                onTap: null,
              ),
              _SettingsItem(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFFFFB800),
                label: 'Member Since',
                trailing: Text(
                  _formatDate(profile.createdAt),
                  style:       TextStyle(
                      color: AColors.textMuted, fontSize: 13),
                ),
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─── APP SETTINGS SECTION ──────────────────────────────────────────────────
class _AppSettingsSection extends ConsumerWidget {
  final UserProfile profile;

  const _AppSettingsSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorTheme = ref.watch(colorThemeProvider);

    String themeModeLabel = 'System';
    if (themeMode == AppThemeMode.light) themeModeLabel = 'Light';
    if (themeMode == AppThemeMode.dark) themeModeLabel = 'Dark';

    // Capitalize first letter of color theme
    String colorThemeLabel = colorTheme.name.substring(0, 1).toUpperCase() + colorTheme.name.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('APP SETTINGS',
                style: TextStyle(
                    color: AColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.category_rounded,
                iconColor: const Color(0xFF9F7AEA),
                label: 'Custom Categories',
                trailing: Text(
                  '${profile.customCategories.length} items',
                  style: TextStyle(color: AColors.textMuted, fontSize: 13),
                ),
                onTap: () => _showCategorySheet(context, ref),
              ),
              _SettingsItem(
                icon: Icons.dark_mode_rounded,
                iconColor: const Color(0xFF5B9CF6),
                label: 'App Theme',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(themeModeLabel, style: TextStyle(color: AColors.textMuted, fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AColors.textMuted, size: 18),
                  ],
                ),
                onTap: () => _showAppThemeSheet(context, ref, themeMode),
              ),
              _SettingsItem(
                icon: Icons.palette_rounded,
                iconColor: AColors.primary,
                label: 'Color Theme',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(colorThemeLabel, style: TextStyle(color: AColors.textMuted, fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AColors.textMuted, size: 18),
                  ],
                ),
                onTap: () => _showColorThemeSheet(context, ref, colorTheme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCategorySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CategoryManagerSheet(profile: profile),
    );
  }

  void _showAppThemeSheet(BuildContext context, WidgetRef ref, AppThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AppThemeSheet(currentMode: currentMode),
    );
  }

  void _showColorThemeSheet(BuildContext context, WidgetRef ref, AppColorTheme currentTheme) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ColorThemeSheet(currentTheme: currentTheme),
    );
  }
}

class _CategoryManagerSheet extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _CategoryManagerSheet({required this.profile});

  @override
  ConsumerState<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends ConsumerState<_CategoryManagerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isNotEmpty && !widget.profile.customCategories.contains(text)) {
      ref.read(userActionsProvider.notifier).addCustomCategory(text);
      _ctrl.clear();
    }
  }

  void _remove(String text) {
    // We update via UserNotifier or directly to UserRepository. 
    // Wait, UserNotifier only had addCustomCategory. Let's fire a repo call.
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      final updated = List<String>.from(widget.profile.customCategories)..remove(text);
      UserRepository.update(uid, {'customCategories': updated});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.profile.customCategories;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Custom Categories', style: AText.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: TextStyle(color: AColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'New category...',
                      hintStyle: TextStyle(color: AColors.textMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _add,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: ARadius.md),
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(Icons.add_rounded, color: AColors.bg, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: cats.isEmpty 
                ? Center(child: Text('No custom categories yet', style: TextStyle(color: AColors.textMuted)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: cats.length,
                    itemBuilder: (_, i) {
                      final c = cats[i];
                      return ListTile(
                        title: Text(c, style: TextStyle(color: AColors.textPrimary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                          onPressed: () => _remove(c),
                        ),
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppThemeSheet extends ConsumerWidget {
  final AppThemeMode currentMode;
  const _AppThemeSheet({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('App Theme', style: AText.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _ThemeTile(
            label: 'System', icon: Icons.brightness_auto_rounded,
            isSelected: currentMode == AppThemeMode.system,
            onTap: () { ref.read(themeModeProvider.notifier).setMode(AppThemeMode.system); Navigator.pop(context); },
          ),
          _ThemeTile(
            label: 'Dark', icon: Icons.dark_mode_rounded,
            isSelected: currentMode == AppThemeMode.dark,
            onTap: () { ref.read(themeModeProvider.notifier).setMode(AppThemeMode.dark); Navigator.pop(context); },
          ),
          _ThemeTile(
            label: 'Light', icon: Icons.light_mode_rounded,
            isSelected: currentMode == AppThemeMode.light,
            onTap: () { ref.read(themeModeProvider.notifier).setMode(AppThemeMode.light); Navigator.pop(context); },
          ),
        ],
      ),
    );
  }
}

class _ColorThemeSheet extends ConsumerWidget {
  final AppColorTheme currentTheme;
  const _ColorThemeSheet({required this.currentTheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Color Theme', style: AText.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppColorTheme.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final theme = AppColorTheme.values[i];
                final isSelected = theme == currentTheme;
                final color = settings.getPrimaryColorFor(theme);
                return GestureDetector(
                  onTap: () {
                    ref.read(colorThemeProvider.notifier).setTheme(theme);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: isSelected ? Border.all(color: AColors.textPrimary, width: 3) : null,
                    ),
                    child: isSelected ? Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTile({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: ARadius.md),
      tileColor: isSelected ? AColors.primary.withValues(alpha: 0.1) : null,
      leading: Icon(icon, color: isSelected ? AColors.primary : AColors.textSecondary),
      title: Text(label, style: TextStyle(color: isSelected ? AColors.primary : AColors.textPrimary, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AColors.primary) : null,
    );
  }
}

// ─── DANGER SECTION ───────────────────────────────────────────────────────
class _DangerSection extends StatelessWidget {
  final VoidCallback onSignOut;
  const _DangerSection({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('SESSION',
                style: TextStyle(
                    color: AColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.logout_rounded,
                iconColor: Colors.redAccent,
                iconBg: Colors.redAccent.withAlpha(20),
                label: 'Sign Out',
                labelColor: Colors.redAccent,
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.redAccent, size: 18),
                onTap: onSignOut,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Arise · Built for champions',
              style: TextStyle(
                  color: AColors.textMuted.withAlpha(100),
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SETTINGS CARD / ITEM ─────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AColors.bgSleek,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AColors.borderSleek, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(
                  height: 1, color: Color(0xFF1A1E28), indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    this.iconBg,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(20),
        splashColor: iconColor.withAlpha(12),
        highlightColor: iconColor.withAlpha(6),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg ?? iconColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: labelColor ?? AColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
              ?trailing,
              if (onTap != null && trailing == null)
                      Icon(Icons.chevron_right_rounded,
                    color: AColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}