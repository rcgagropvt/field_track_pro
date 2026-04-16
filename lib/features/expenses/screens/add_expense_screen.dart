import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'travel';
  bool _isLoading = false;
  final _picker = ImagePicker();
  final List<String> _receiptUrls = [];

  final _categories = [
    {
      'key': 'travel',
      'icon': Icons.directions_car_rounded,
      'label': 'Travel / Fuel'
    },
    {'key': 'food', 'icon': Icons.restaurant_rounded, 'label': 'Food / Meals'},
    {
      'key': 'accommodation',
      'icon': Icons.hotel_rounded,
      'label': 'Stay / Hotel'
    },
    {
      'key': 'supplies',
      'icon': Icons.shopping_bag_rounded,
      'label': 'Supplies'
    },
    {
      'key': 'communication',
      'icon': Icons.phone_rounded,
      'label': 'Phone / Internet'
    },
    {
      'key': 'entertainment',
      'icon': Icons.celebration_rounded,
      'label': 'Client Entertainment'
    },
    {'key': 'other', 'icon': Icons.receipt_rounded, 'label': 'Other'},
  ];

  Future<void> _takeReceiptPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo == null) return;

    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          'expenses/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes);
      final url =
          SupabaseService.client.storage.from('uploads').getPublicUrl(fileName);
      setState(() => _receiptUrls.add(url));
    } catch (e) {
      _showSnack('Upload failed', isError: true);
    }
  }

  Future<void> _pickFromGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo == null) return;

    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          'expenses/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes);
      final url =
          SupabaseService.client.storage.from('uploads').getPublicUrl(fileName);
      setState(() => _receiptUrls.add(url));
    } catch (e) {
      _showSnack('Upload failed', isError: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await SupabaseService.createExpense({
        'amount': double.parse(_amountCtrl.text),
        'category': _category,
        'description': _descCtrl.text.trim(),
        'receipt_url': _receiptUrls.isNotEmpty ? _receiptUrls.first : null,
        'receipt_photos': _receiptUrls,
      });

      if (mounted) {
        _showSnack('Expense submitted for approval!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Expense'),
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
              // Amount
              const Text('Amount',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _amountCtrl,
                hint: '0.00',
                prefixIcon: Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Category selection
              const Text('Category',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _category == cat['key'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _category = cat['key'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat['icon'] as IconData,
                              size: 16,
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.primary),
                          const SizedBox(width: 6),
                          Text(cat['label'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Description
              CustomTextField(
                controller: _descCtrl,
                label: 'Description / Notes',
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              // Receipt Photos
              const Text('Receipt / Proof',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Attach photos of bills, receipts, or fuel slips',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._receiptUrls.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(entry.value,
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _receiptUrls.removeAt(entry.key)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 14, color: AppColors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  // Camera button
                  GestureDetector(
                    onTap: _takeReceiptPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: AppColors.primary, size: 22),
                          Text('Camera',
                              style: TextStyle(
                                  fontSize: 9, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  // Gallery button
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded,
                              color: AppColors.textSecondary, size: 22),
                          Text('Gallery',
                              style: TextStyle(
                                  fontSize: 9, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              CustomButton(
                text: 'Submit Expense',
                onPressed: _save,
                isLoading: _isLoading,
                icon: Icons.send_rounded,
              ),

              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Will be sent to manager for approval',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


