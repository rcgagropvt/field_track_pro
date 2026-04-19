import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Check if first launch
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

    if (!hasSeenWelcome) {
      Navigator.pushReplacementNamed(context, AppRouter.welcome);
      return;
    }

    final session = SupabaseService.client.auth.currentSession;

    if (session == null) {
      Navigator.pushReplacementNamed(context, AppRouter.login);
      return;
    }

    try {
      final profile = await SupabaseService.getProfile();
      final role = profile?['role'] ?? 'employee';

      if (role == 'admin' || role == 'manager') {
        Navigator.pushReplacementNamed(context, AppRouter.adminMain);
      } else {
        Navigator.pushReplacementNamed(context, AppRouter.main);
      }
    } catch (e) {
      Navigator.pushReplacementNamed(context, AppRouter.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── App logo ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset(
                  'assets/launcher_icon.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.location_on_rounded,
                    size: 64,
                    color: AppColors.white,
                  ),
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── App name ──────────────────────────────────────────────
              const Text(
                'Vartmaan Pulse',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  letterSpacing: -0.5,
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),

              const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentLight,
                  letterSpacing: 8,
                ),
              ).animate(delay: 500.ms).fadeIn(duration: 500.ms),

              const SizedBox(height: 48),

              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
