import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class CreateSchemeScreen extends StatefulWidget {
  final Map<String, dynamic>? scheme; // null = create, non-null = edit
  const CreateSchemeScreen({super.key, this.scheme});
  @override
  State<CreateSchemeScreen> createState() => _CreateSchemeScreenState();
}

class _CreateSchemeScreenState extends State<CreateSchemeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _buyQtyCtrl = TextEditingController();
  final _freeQtyCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();

  String _type = 'percentage';
  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.scheme != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.scheme!;
      _nameCtrl.text = s['name'] ?? '';
      _type = s['type'] ?? 'percentage';
      _discountCtrl.text = (s['discount_value'] ?? '').toString();
      _buyQtyCtrl.text = (s['buy_qty'] ?? '').toString();
      _freeQtyCtrl.text = (s['free_qty'] ?? '').toString();
      _minOrderCtrl.text = (s['min_order_amount'] ?? '').toString();
      _isActive = s['is_active'] ?? true;
      _validFrom = DateTime.tryParse(s['valid_from'] ?? '') ?? _validFrom;
      _validTo = DateTime.tryParse(s['valid_to'] ?? '') ?? _validTo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _discountCtrl.dispose();
    _buyQtyCtrl.dispose();
    _freeQtyCtrl.dispose();
    _minOrderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _validFrom : _validTo,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _validFrom = picked;
        else _validTo = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'discount_value': double.tryParse(_discountCtrl.text) ?? 0,
        'buy_qty': int.tryParse(_buyQtyCtrl.text) ?? 0,
        'free_qty': int.tryParse(_freeQtyCtrl.text) ?? 0,
        'min_order_amount': double.tryParse(_minOrderCtrl.text) ?? 0,
        'valid_from': _validFrom.toIso8601String().substring(0, 10),
        'valid_to': _validTo.toIso8601String().substring(0, 10),
        'is_active': _isActive,
      };

      if (_isEdit) {
        await SupabaseService.client
            .from('schemes')
            .update(data)
            .eq('id', widget.scheme!['id'] as String);
      } else {
        await SupabaseService.client.from('schemes').insert(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Scheme' : 'New Scheme',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_saving)
            const Center(
                child: Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Update' : 'Save',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Scheme Details', [
              _field('Scheme Name', _nameCtrl,
                  hint: 'e.g. Summer Sale 10% Off',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),

              // Type selector
              const Text('Scheme Type',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _typeChip('percentage', '% Discount', Icons.percent),
                  _typeChip('flat', 'Flat Off', Icons.currency_rupee),
                  _typeChip('buy_x_get_y', 'Buy X Get Y', Icons.redeem),
                  _typeChip('min_order', 'Min Order', Icons.shopping_bag),
                ],
              ),
            ]),

            const SizedBox(height: 16),

            // Conditional fields based on type
            _section('Scheme Value', [
              if (_type == 'percentage') ...[
                _field('Discount %', _discountCtrl,
                    hint: 'e.g. 10',
                    keyboardType: TextInputType.number,
                    suffix: '%',
                    validator: (v) => _validateNum(v, min: 1, max: 100)),
              ],
              if (_type == 'flat') ...[
                _field('Flat Discount (₹)', _discountCtrl,
                    hint: 'e.g. 500',
                    keyboardType: TextInputType.number,
                    prefix: '₹',
                    validator: (v) => _validateNum(v, min: 1)),
              ],
              if (_type == 'buy_x_get_y') ...[
                Row(children: [
                  Expanded(
                    child: _field('Buy Qty', _buyQtyCtrl,
                        hint: 'e.g. 6',
                        keyboardType: TextInputType.number,
                        validator: (v) => _validateNum(v, min: 1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Free Qty', _freeQtyCtrl,
                        hint: 'e.g. 1',
                        keyboardType: TextInputType.number,
                        validator: (v) => _validateNum(v, min: 1)),
                  ),
                ]),
              ],
              if (_type == 'min_order') ...[
                _field('Minimum Order (₹)', _minOrderCtrl,
                    hint: 'e.g. 5000',
                    keyboardType: TextInputType.number,
                    prefix: '₹',
                    validator: (v) => _validateNum(v, min: 1)),
                const SizedBox(height: 12),
                _field('Discount Amount (₹)', _discountCtrl,
                    hint: 'e.g. 200',
                    keyboardType: TextInputType.number,
                    prefix: '₹',
                    validator: (v) => _validateNum(v, min: 1)),
              ],
            ]),

            const SizedBox(height: 16),

            _section('Validity Period', [
              Row(children: [
                Expanded(child: _dateTile('From', _validFrom,
                    () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(child: _dateTile('To', _validTo,
                    () => _pickDate(false))),
              ]),
            ]),

            const SizedBox(height: 16),

            _section('Status', [
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Active',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(_isActive
                    ? 'Scheme will apply to new orders'
                    : 'Scheme is paused'),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String? _validateNum(String? v, {double min = 0, double? max}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n < min) return 'Must be at least $min';
    if (max != null && n > max) return 'Must be at most $max';
    return null;
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint,
      TextInputType? keyboardType,
      String? suffix,
      String? prefix,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : null,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _typeChip(String value, String label, IconData icon) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15,
              color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.black87)),
        ]),
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ]),
        ]),
      ),
    );
  }
}

