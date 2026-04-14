import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // App Logo + Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.location_on_rounded, size: 52, color: AppColors.white),
                  SizedBox(height: 12),
                  Text('FieldTrack Pro',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white)),
                  Text('Version 1.0.0',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 8),
                  Text('Field Sales & Employee Tracking',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Company Info
            _infoCard(
              title: 'Developed by',
              children: [
                _infoRow(Icons.business_rounded, 'RCG Agro Private Limited'),
                _infoRow(Icons.verified_rounded, 'Brand: Vartmaan'),
                _infoRow(Icons.language_rounded, 'www.vartmaan.com',
                    onTap: () => launchUrl(
                        Uri.parse('https://www.vartmaan.com'),
                        mode: LaunchMode.externalApplication)),
                _infoRow(Icons.email_outlined, 'info@vartmaan.com',
                    onTap: () =>
                        launchUrl(Uri.parse('mailto:info@vartmaan.com'))),
              ],
            ),

            const SizedBox(height: 12),

            _infoCard(
              title: 'Our Products',
              children: [
                _tag('Fertilizers'),
                _tag('Micronutrient Fertilizers'),
                _tag('Biostimulants'),
                _tag('Bio Fertilizers'),
                _tag('Organic Fertilizers'),
              ],
              isWrap: true,
            ),

            const SizedBox(height: 12),

            _infoCard(
              title: 'App Purpose',
              children: [
                _infoRow(Icons.check_circle_outline, 'Field employee attendance tracking'),
                _infoRow(Icons.check_circle_outline, 'GPS-based dealer visit verification'),
                _infoRow(Icons.check_circle_outline, 'Sales lead & CRM management'),
                _infoRow(Icons.check_circle_outline, 'Expense claim submission'),
                _infoRow(Icons.check_circle_outline, 'Task management for field staff'),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              '© ${DateTime.now().year} RCG Agro Private Limited. All rights reserved.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required List<Widget> children,
    bool isWrap = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary)),
          const SizedBox(height: 12),
          isWrap
              ? Wrap(spacing: 8, runSpacing: 8, children: children)
              : Column(children: children),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(text,
                style: TextStyle(
                    fontSize: 14,
                    color: onTap != null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    decoration:
                        onTap != null ? TextDecoration.underline : null)),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }
}