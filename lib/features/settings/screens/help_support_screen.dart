import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need Help?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white)),
                SizedBox(height: 4),
                Text('Our support team is here to help you',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _contactTile(
            icon: Icons.email_outlined,
            label: 'Email Support',
            value: 'info@vartmaan.com',
            onTap: () => launchUrl(Uri.parse('mailto:info@vartmaan.com')),
          ),
          _contactTile(
            icon: Icons.email_rounded,
            label: 'Sales Queries',
            value: 'sales@vartmaan.com',
            onTap: () => launchUrl(Uri.parse('mailto:sales@vartmaan.com')),
          ),
          _contactTile(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'www.vartmaan.com',
            onTap: () => launchUrl(Uri.parse('https://www.vartmaan.com'),
                mode: LaunchMode.externalApplication),
          ),

          const SizedBox(height: 16),

          // FAQ Section
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('FAQ',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),

          _faqTile('How do I start a visit?',
              'Go to Parties tab → tap any dealer → tap "Start Visit". A selfie and GPS location will be captured automatically.'),
          _faqTile('How do I submit an expense?',
              'Open the drawer menu → Expenses → tap the + button. Attach receipt photos and submit for manager approval.'),
          _faqTile('Why is my location not updating?',
              'Make sure location permission is set to "Allow all the time" in your phone Settings → Apps → FieldTrack Pro → Permissions.'),
          _faqTile('How do I mark attendance?',
              'On the Home screen, tap the Check In button. GPS and selfie verification are required.'),
        ],
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        trailing: const Icon(Icons.open_in_new_rounded,
            size: 16, color: AppColors.textTertiary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}