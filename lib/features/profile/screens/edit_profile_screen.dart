import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final Map<String, TextEditingController> _c;
  String? _gender;
  String? _bloodGroup;
  DateTime? _dob;
  DateTime? _doj;
  bool _isLoading = false;

  final _genders = ['male', 'female', 'other'];
  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _c = {
      'full_name': TextEditingController(text: p['full_name'] ?? ''),
      'phone': TextEditingController(text: p['phone'] ?? ''),
      'department': TextEditingController(text: p['department'] ?? ''),
      'designation': TextEditingController(text: p['designation'] ?? ''),
      'employee_id': TextEditingController(text: p['employee_id'] ?? ''),
      'emergency_contact_name':
          TextEditingController(text: p['emergency_contact_name'] ?? ''),
      'emergency_contact_phone':
          TextEditingController(text: p['emergency_contact_phone'] ?? ''),
      'pan_number': TextEditingController(text: p['pan_number'] ?? ''),
      'uan_number': TextEditingController(text: p['uan_number'] ?? ''),
      'esi_number': TextEditingController(text: p['esi_number'] ?? ''),
      'bank_name': TextEditingController(text: p['bank_name'] ?? ''),
      'bank_account_number':
          TextEditingController(text: p['bank_account_number'] ?? ''),
      'bank_ifsc': TextEditingController(text: p['bank_ifsc'] ?? ''),
      'address_current':
          TextEditingController(text: p['address_current'] ?? ''),
      'address_permanent':
          TextEditingController(text: p['address_permanent'] ?? ''),
      'city': TextEditingController(text: p['city'] ?? ''),
      'state': TextEditingController(text: p['state'] ?? ''),
    };
    _gender = p['gender'];
    _bloodGroup = p['blood_group'];
    _dob = p['date_of_birth'] != null
        ? DateTime.tryParse(p['date_of_birth'])
        : null;
    _doj = p['date_of_joining'] != null
        ? DateTime.tryParse(p['date_of_joining'])
        : null;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      for (final entry in _c.entries) {
        final val = entry.value.text.trim();
        data[entry.key] = val.isEmpty ? null : val;
      }

      data['gender'] = _gender;
      data['blood_group'] = _bloodGroup;
      data['date_of_birth'] =
          _dob != null ? _dob!.toIso8601String().split('T')[0] : null;
      data['date_of_joining'] =
          _doj != null ? _doj!.toIso8601String().split('T')[0] : null;

      await SupabaseService.updateProfile(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Personal Information'),
            _field('full_name', 'Full Name', Icons.person),
            Row(
              children: [
                Expanded(
                    child: _dropdownField('Gender', _gender, _genders,
                        (v) => setState(() => _gender = v))),
                const SizedBox(width: 12),
                Expanded(
                    child: _dropdownField('Blood Group', _bloodGroup,
                        _bloodGroups, (v) => setState(() => _bloodGroup = v))),
              ],
            ),
            _dateField('Date of Birth', _dob, (d) => setState(() => _dob = d),
                DateTime(1960), DateTime.now()),
            _field('phone', 'Phone', Icons.phone,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            _sectionHeader('Employment Details'),
            _field('employee_id', 'Employee ID', Icons.badge),
            _field('department', 'Department', Icons.business),
            _field('designation', 'Designation', Icons.work),
            _dateField('Date of Joining', _doj, (d) => setState(() => _doj = d),
                DateTime(2000), DateTime.now()),
            const SizedBox(height: 24),
            _sectionHeader('Emergency Contact'),
            _field('emergency_contact_name', 'Contact Name',
                Icons.contact_emergency),
            _field('emergency_contact_phone', 'Contact Phone',
                Icons.phone_callback,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            _sectionHeader('Bank & Statutory'),
            _field('bank_name', 'Bank Name', Icons.account_balance),
            _field('bank_account_number', 'Account Number',
                Icons.account_balance_wallet,
                keyboardType: TextInputType.number),
            _field('bank_ifsc', 'IFSC Code', Icons.code),
            _field('pan_number', 'PAN Number', Icons.credit_card),
            _field('uan_number', 'UAN (PF)', Icons.security),
            _field('esi_number', 'ESI Number', Icons.local_hospital),
            const SizedBox(height: 24),
            _sectionHeader('Address'),
            _field('address_current', 'Current Address', Icons.home,
                maxLines: 2),
            _field('address_permanent', 'Permanent Address', Icons.home_work,
                maxLines: 2),
            Row(
              children: [
                Expanded(child: _field('city', 'City', Icons.location_city)),
                const SizedBox(width: 12),
                Expanded(child: _field('state', 'State', Icons.map)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: const Icon(Icons.save),
                label:
                    const Text('Save Profile', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary)),
    );
  }

  Widget _field(String key, String label, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _dropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                value: e, child: Text(e[0].toUpperCase() + e.substring(1))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, Function(DateTime) onPicked,
      DateTime first, DateTime last) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_today),
        title: Text(
            value != null ? DateFormat('d MMM yyyy').format(value) : label),
        subtitle: value == null ? Text(label) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade400),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime(2000),
            firstDate: first,
            lastDate: last,
          );
          if (picked != null) onPicked(picked);
        },
      ),
    );
  }
}
