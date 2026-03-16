import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/theme/app_theme.dart';
import '../../core/models/app_models.dart';
import '../../core/services/firestore_service.dart';


class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCred.user ?? FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _ensureUserProfile(user);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: $e'),
          backgroundColor: AColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureUserProfile(User user) async {
    final existing = await UserRepository.get(user.uid);
    if (existing != null) return;

    final profile = UserProfile(
      uid: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Warrior',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );

    await UserRepository.create(profile);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AColors.bg,
      body: Stack(children: [
        Positioned(top: -150, right: -100, child: Container(
          width: 400, height: 400,
          decoration: const BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0x1500C97B), Colors.transparent])),
        )),
        Positioned(bottom: -100, left: -100, child: Container(
          width: 300, height: 300,
          decoration: const BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0x0D00C97B), Colors.transparent])),
        )),
        SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(flex: 2),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: AColors.gradientPrimary,
                borderRadius: ARadius.xl,
                boxShadow: [BoxShadow(color: AColors.primary.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2)],
              ),
              child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 28),
            const Text('Welcome to', style: AText.bodyLarge),
            const SizedBox(height: 4),
            const Text('Arise', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AColors.textPrimary, letterSpacing: -1.5)),
            const SizedBox(height: 12),
            const Text('Build habits. Crush goals.\nBecome who you want to be.', style: AText.bodyMedium),
            const Spacer(flex: 3),
            _FeatureRow(icon: Icons.check_circle_rounded, text: 'Track tasks, habits & goals', color: AColors.primary),
            const SizedBox(height: 14),
            _FeatureRow(icon: Icons.timer_rounded, text: 'Pomodoro focus sessions', color: AColors.info),
            const SizedBox(height: 14),
            _FeatureRow(icon: Icons.emoji_events_rounded, text: 'Earn XP & level up', color: AColors.warning),
            const SizedBox(height: 14),
            _FeatureRow(icon: Icons.balance_rounded, text: 'Life balance tracker', color: const Color(0xFFBF7FF5)),
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: const Color(0xFF1A1A1A),
                  elevation: 0, shape: const RoundedRectangleBorder(borderRadius: ARadius.md),
                ),
                child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AColors.primary))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.g_mobiledata_rounded, size: 28, color: Color(0xFF4285F4)),
                      SizedBox(width: 10),
                      Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                    ]),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('By continuing you agree to our Terms & Privacy Policy', style: AText.bodySmall, textAlign: TextAlign.center)),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _FeatureRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: ARadius.sm),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 14),
      Text(text, style: AText.bodyLarge),
    ]);
  }
}
