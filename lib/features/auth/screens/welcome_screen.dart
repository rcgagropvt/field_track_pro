import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../router/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _proceed(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/launcher_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 800.ms, curve: Curves.elasticOut, begin: const Offset(0.5, 0.5))
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 32),

                // App name
                const Text(
                  'Vartmaan',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),

                const Text(
                  'PULSE',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF6C63FF),
                    letterSpacing: 12,
                    height: 1.1,
                  ),
                )
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 16),

                // Tagline
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Field Sales Intelligence Platform',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 1),

                // Feature highlights
                _featureRow(Icons.location_on_rounded, 'Real-time field tracking & visits')
                    .animate(delay: 900.ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(height: 12),
                _featureRow(Icons.analytics_rounded, 'AI-powered sales intelligence')
                    .animate(delay: 1050.ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(height: 12),
                _featureRow(Icons.emoji_events_rounded, 'Gamification & incentive targets')
                    .animate(delay: 1200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(height: 12),
                _featureRow(Icons.handshake_rounded, 'Distributor loyalty & rewards')
                    .animate(delay: 1350.ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0),

                const Spacer(flex: 2),

                // Get Started button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _proceed(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Started',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                )
                    .animate(delay: 1500.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 24),

                // Version
                Text(
                  'v1.0.0',
                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
                ).animate(delay: 1700.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
