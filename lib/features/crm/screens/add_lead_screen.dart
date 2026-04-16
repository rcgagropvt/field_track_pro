import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/supabase_service.dart';

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  String _source = 'walk_in';
  String _priority = 'medium';
  bool _isLoading = false;

  final _sources = ['website', 'referral', 'cold_call', 'social_media', 'advertisement', 'walk_in', 'other'];
  final _priorities = ['low', 'medium', 'high', 'urgent'];

  Future<void> _saveLead() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await SupabaseService.createLead({
        'company_name': _companyController.text.trim(),
        'contact_name': _contactController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'estimated_value': double.tryParse(_valueController.text) ?? 0,
        'notes': _notesController.text.trim(),
        'source': _source,
        'priority': _priority,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lead created successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lead'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Company Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _companyController,
                label: 'Company Name *',
                prefixIcon: Icons.business_rounded,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _contactController,
                label: 'Contact Person *',
                prefixIcon: Icons.person_outline,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _phoneController,
                label: 'Phone',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _addressController,
                label: 'Address',
                prefixIcon: Icons.location_on_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 24),
              const Text(
                'Lead Info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _valueController,
                label: 'Estimated Value (\$)',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Source Dropdown
              DropdownButtonFormField<String>(
                value: _source,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  prefixIcon: Icon(Icons.source_rounded, size: 20),
                ),
                items: _sources.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _source = v!),
              ),
              const SizedBox(height: 12),

              // Priority Dropdown
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.flag_rounded, size: 20),
                ),
                items: _priorities.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _notesController,
                label: 'Notes',
                prefixIcon: Icons.notes_rounded,
                maxLines: 3,
              ),

              const SizedBox(height: 32),
              CustomButton(
                text: 'Save Lead',
                onPressed: _saveLead,
                isLoading: _isLoading,
                icon: Icons.save_rounded,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


