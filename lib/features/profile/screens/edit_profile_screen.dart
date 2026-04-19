import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _designCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['full_name'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile['phone'] ?? '');
    _deptCtrl = TextEditingController(text: widget.profile['department'] ?? '');
    _designCtrl =
        TextEditingController(text: widget.profile['designation'] ?? '');
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'designation': _designCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _designCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CustomTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                prefixIcon: Icons.person_outline),
            const SizedBox(height: 14),
            CustomTextField(
                controller: _phoneCtrl,
                label: 'Phone',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            CustomTextField(
                controller: _deptCtrl,
                label: 'Department',
                prefixIcon: Icons.business_rounded),
            const SizedBox(height: 14),
            CustomTextField(
                controller: _designCtrl,
                label: 'Designation',
                prefixIcon: Icons.badge_rounded),
            const SizedBox(height: 14),

            // Email (read only)
            CustomTextField(
              label: 'Email',
              prefixIcon: Icons.email_outlined,
              readOnly: true,
              controller:
                  TextEditingController(text: widget.profile['email'] ?? ''),
            ),

            const SizedBox(height: 32),
            CustomButton(
                text: 'Save Changes',
                onPressed: _save,
                isLoading: _isLoading,
                icon: Icons.save_rounded),
          ],
        ),
      ),
    );
  }
}
