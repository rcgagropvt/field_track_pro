import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'admin_shell.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});
  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _role = 'employee';
  bool _loading = false;
  bool _passVisible = false;
  bool _confirmVisible = false;

  final _departments = [
    'Sales',
    'Marketing',
    'Operations',
    'Finance',
    'HR',
    'Tech',
    'Other'
  ];
  String _selectedDept = 'Sales';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) {
        _toast('Session expired. Please log in again.', Colors.red);
        setState(() => _loading = false);
        return;
      }

      // ✅ Call function directly via HTTP — bypasses SDK JWT check
      final url = Uri.parse(
          'https://wruxzfvpnhzihmboggyu.supabase.co/functions/v1/create-employee');

      debugPrint('Calling: $url');
      debugPrint('Token starts with: ${session.accessToken.substring(0, 30)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey':
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndydXh6ZnZwbmh6aWhtYm9nZ3l1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjQ1NTQsImV4cCI6MjA5MTA0MDU1NH0.PZQEJTgm_kTFcZLUAyIlqkwIFApOc4FXkPBua4F-tbE',
        },
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
          'full_name': _nameCtrl.text.trim(),
          'role': _role,
          'department': _selectedDept,
          'phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        }),
      );

      debugPrint('HTTP Status: ${response.statusCode}');
      debugPrint('HTTP Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _toast('✅ Employee created successfully!', Colors.green);
        _nameCtrl.clear();
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _passCtrl.clear();
        _confirmPassCtrl.clear();
        setState(() => _selectedDept = 'Sales');
      } else {
        _toast('Error: ${data['error'] ?? response.body}', Colors.red);
      }
    } catch (e) {
      debugPrint('Exception: $e');
      _toast('Error: $e', Colors.red);
    }
    setState(() => _loading = false);
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Create Employee',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'The employee will receive login credentials via email. '
                        'They can change their password after first login.',
                        style: TextStyle(fontSize: 12, color: Colors.blue))),
              ]),
            ),
            const SizedBox(height: 20),
            _section('Personal Information'),
            _field('Full Name *', _nameCtrl, Icons.person,
                validator: (v) => v!.isEmpty ? 'Enter full name' : null),
            _field('Email Address *', _emailCtrl, Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    !v!.contains('@') ? 'Enter valid email' : null),
            _field('Phone Number', _phoneCtrl, Icons.phone,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            _section('Role & Department'),
            const Text('Role',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _roleCard('employee', 'Employee', Icons.badge, Colors.blue),
              const SizedBox(width: 10),
              _roleCard(
                  'admin', 'Admin', Icons.admin_panel_settings, Colors.purple),
              const SizedBox(width: 10),
              _roleCard('manager', 'Manager', Icons.supervisor_account,
                  Colors.orange),
            ]),
            const SizedBox(height: 14),
            const Text('Department',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDept,
              decoration: _inputDec('Select department', Icons.business),
              items: _departments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDept = v!),
            ),
            const SizedBox(height: 16),
            _section('Set Password'),
            _passwordField('Password *', _passCtrl, _passVisible,
                () => setState(() => _passVisible = !_passVisible),
                validator: (v) =>
                    v!.length < 8 ? 'Minimum 8 characters' : null),
            _passwordField(
                'Confirm Password *',
                _confirmPassCtrl,
                _confirmVisible,
                () => setState(() => _confirmVisible = !_confirmVisible),
                validator: (v) =>
                    v != _passCtrl.text ? 'Passwords do not match' : null),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add),
                label: Text(_loading ? 'Creating...' : 'Create Employee',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.8))),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ]),
      );

  Widget _field(String hint, TextEditingController ctrl, IconData icon,
          {TextInputType? keyboardType,
          String? Function(String?)? validator}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: ctrl,
              keyboardType: keyboardType,
              decoration: _inputDec(hint, icon),
              validator: validator));

  Widget _passwordField(String hint, TextEditingController ctrl, bool visible,
          VoidCallback toggle,
          {String? Function(String?)? validator}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: ctrl,
            obscureText: !visible,
            decoration: _inputDec(hint, Icons.lock).copyWith(
                suffixIcon: IconButton(
                    icon:
                        Icon(visible ? Icons.visibility_off : Icons.visibility),
                    onPressed: toggle)),
            validator: validator,
          ));

  Widget _roleCard(String val, String label, IconData icon, Color color) {
    final isSelected = _role == val;
    return Expanded(
        child: GestureDetector(
      onTap: () => setState(() => _role = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: isSelected ? color : Colors.grey, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : Colors.grey)),
        ]),
      ),
    ));
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}


