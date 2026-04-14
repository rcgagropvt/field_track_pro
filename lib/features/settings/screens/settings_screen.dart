import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../router/app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Account'),
          _tile(Icons.person_outline, 'Edit Profile', () =>
              Navigator.pushNamed(context, AppRouter.profile)),
          _tile(Icons.lock_outline, 'Change Password', () =>
              _showChangePassword(context)),

          const SizedBox(height: 8),
          _sectionHeader('Preferences'),
          _tile(Icons.language_rounded, 'Language', () {}, trailing:
              const Text('English', style: TextStyle(color: AppColors.textSecondary))),
          _tile(Icons.notifications_outlined, 'Notifications', () {}),

          const SizedBox(height: 8),
          _sectionHeader('Support'),
          _tile(Icons.help_outline_rounded, 'Help & Support', () =>
              Navigator.pushNamed(context, AppRouter.helpSupport)),
          _tile(Icons.info_outline_rounded, 'About App', () =>
              Navigator.pushNamed(context, AppRouter.about)),

          const SizedBox(height: 8),
          _sectionHeader('Danger Zone'),
          _tile(Icons.logout_rounded, 'Sign Out', () =>
              _confirmSignOut(context), color: AppColors.error),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.5)),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap,
      {Color? color, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color ?? AppColors.primary, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? AppColors.textPrimary)),
        trailing: trailing ??
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRouter.login, (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    // Placeholder — wire up later
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Password reset email will be sent to your registered email'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}