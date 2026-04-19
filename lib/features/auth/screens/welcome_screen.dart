import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../router/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          // ──────────────────────────────────────────────
          // OPTION A: Gradient background (current demo)
          // Replace this entire BoxDecoration with OPTION B
          // when your Canva design is ready.
          // ──────────────────────────────────────────────
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF006A61), // your brand color
              Color(0xFF004D47), // darker shade
              Color(0xFF00332F), // darkest shade
            ],
          ),

          // ──────────────────────────────────────────────
          // OPTION B: Canva full-screen image
          // 1. Export your Canva design as PNG (1080x1920)
          // 2. Save to assets/welcome_bg.png
          // 3. Add to pubspec.yaml under assets:
          //      - assets/welcome_bg.png
          // 4. Uncomment below & delete the gradient above:
          //
          // image: DecorationImage(
          //   image: AssetImage('assets/welcome_bg.png'),
          //   fit: BoxFit.cover,
          // ),
          // ──────────────────────────────────────────────
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/launcher_icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 24),

                // App name
                const Text(
                  'Vartmaan Pulse',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Field Intelligence Platform',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 1.0,
                  ),
                ),

                const Spacer(flex: 1),

                // Feature highlights
                _featureRow(
                    Icons.location_on_rounded, 'Real-time Field Tracking'),
                const SizedBox(height: 16),
                _featureRow(Icons.analytics_rounded, 'AI-Powered Analytics'),
                const SizedBox(height: 16),
                _featureRow(Icons.emoji_events_rounded, 'Gamified Performance'),
                const SizedBox(height: 16),
                _featureRow(Icons.card_giftcard_rounded, 'Loyalty & Rewards'),

                const Spacer(flex: 2),

                // Get Started button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('has_seen_welcome', true);
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(
                            context, AppRouter.login);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF006A61),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    child: const Text('Get Started'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Powering smart field operations',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
