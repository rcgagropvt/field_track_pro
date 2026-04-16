import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';

class AddPartyScreen extends StatefulWidget {
  const AddPartyScreen({super.key});

  @override
  State<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  String _type = 'dealer';
  bool _isLoading = false;
  bool _useCurrentLocation = false;
  double? _lat, _lng;

  Future<void> _captureLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _useCurrentLocation = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await SupabaseService.client.from('parties').insert({
        'user_id': SupabaseService.userId,
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'contact_person': _contactCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'is_active': true,
        'credit_limit': double.tryParse(_creditLimitCtrl.text) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Party added successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
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
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Party'),
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              const Text('Party Type',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  'dealer',
                  'distributor',
                  'retailer',
                  'wholesaler',
                  'customer'
                ].map((t) {
                  final isSelected = _type == t;
                  return ChoiceChip(
                    label: Text(t.toUpperCase()),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.white : AppColors.primary,
                    ),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              CustomTextField(
                controller: _nameCtrl,
                label: 'Business Name *',
                prefixIcon: Icons.store_rounded,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _contactCtrl,
                label: 'Contact Person',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _phoneCtrl,
                label: 'Phone',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _emailCtrl,
                label: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _addressCtrl,
                label: 'Address',
                prefixIcon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _cityCtrl,
                label: 'City',
                prefixIcon: Icons.location_city_rounded,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _creditLimitCtrl,
                label: 'Credit Limit (₹) — 0 = No limit',
                prefixIcon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),
              // GPS Location Capture
              GestureDetector(
                onTap: _captureLocation,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _useCurrentLocation
                        ? AppColors.successLight
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _useCurrentLocation
                          ? AppColors.success
                          : AppColors.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _useCurrentLocation
                            ? Icons.check_circle
                            : Icons.my_location,
                        color: _useCurrentLocation
                            ? AppColors.success
                            : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _useCurrentLocation
                              ? 'Location captured (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})'
                              : 'Tap to capture current GPS location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _useCurrentLocation
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              CustomButton(
                text: 'Save Party',
                onPressed: _save,
                isLoading: _isLoading,
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

