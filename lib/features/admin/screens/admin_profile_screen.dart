import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_shell.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = true, _saving = false;
  bool _showCurrent = false, _showNew = false, _showConfirm = false;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _deptCtrl,
      _currentPassCtrl,
      _newPassCtrl,
      _confirmPassCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;
    final data = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', uid)
        .single();
    setState(() {
      _profile = data;
      _nameCtrl.text = data['full_name'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _deptCtrl.text = data['department'] ?? '';
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final uid = SupabaseService.client.auth.currentUser?.id!;
    await SupabaseService.client.from('profiles').update({
      'full_name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'department': _deptCtrl.text.trim(),
    }).eq('id', uid!);
    setState(() => _saving = false);
    _toast('✅ Profile updated', Colors.green);
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _toast('Passwords do not match', Colors.red);
      return;
    }
    if (_newPassCtrl.text.length < 8) {
      _toast('Minimum 8 characters', Colors.red);
      return;
    }
    setState(() => _saving = true);
    try {
      // Re-authenticate first
      final email = SupabaseService.client.auth.currentUser?.email ?? '';
      await SupabaseService.client.auth
          .signInWithPassword(email: email, password: _currentPassCtrl.text);
      // Now update
      await SupabaseService.client.auth
          .updateUser(UserAttributes(password: _newPassCtrl.text));
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _toast('✅ Password changed successfully', Colors.green);
    } catch (e) {
      _toast('❌ Current password is incorrect', Colors.red);
    }
    setState(() => _saving = false);
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
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        bottom: TabBar(
            controller: _tab,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Edit Profile'),
              Tab(text: 'Change Password'),
            ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tab, children: [
              _profileTab(),
              _passwordTab(),
            ]),
    );
  }

  Widget _profileTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Avatar
          Center(
              child: Stack(children: [
            CircleAvatar(
                radius: 44,
                backgroundColor: Colors.blue.shade700,
                child: Text(
                    (_profile['full_name'] ?? 'A').toString()[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white))),
            Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.edit, size: 14, color: Colors.white))),
          ])),
          const SizedBox(height: 6),
          Text(_profile['email'] ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_profile['role'] ?? 'admin',
                  style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDec(),
            child: Column(children: [
              _formField('Full Name', _nameCtrl, Icons.person),
              const SizedBox(height: 14),
              _formField('Phone', _phoneCtrl, Icons.phone,
                  type: TextInputType.phone),
              const SizedBox(height: 14),
              _formField('Department', _deptCtrl, Icons.business),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
            ]),
          ),

          // Account info read-only
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDec(),
            child: Column(children: [
              _infoRow('Email', _profile['email'] ?? '', Icons.email),
              const Divider(height: 20),
              _infoRow('Role', _profile['role'] ?? '', Icons.badge),
              const Divider(height: 20),
              _infoRow(
                  'Status',
                  (_profile['is_active'] ?? true) ? 'Active' : 'Inactive',
                  Icons.circle,
                  (_profile['is_active'] ?? true) ? Colors.green : Colors.red),
            ]),
          ),
        ]),
      );

  Widget _passwordTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200)),
            child: const Row(children: [
              Icon(Icons.lock_outline, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Enter your current password to verify your identity before changing it.',
                      style: TextStyle(fontSize: 12, color: Colors.black87))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDec(),
            child: Column(children: [
              _passField('Current Password', _currentPassCtrl, _showCurrent,
                  () => setState(() => _showCurrent = !_showCurrent)),
              const SizedBox(height: 14),
              _passField('New Password', _newPassCtrl, _showNew,
                  () => setState(() => _showNew = !_showNew)),
              const SizedBox(height: 14),
              _passField('Confirm New Password', _confirmPassCtrl, _showConfirm,
                  () => setState(() => _showConfirm = !_showConfirm)),
              const SizedBox(height: 20),
              // Password rules
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Password requirements:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      _rule('At least 8 characters'),
                      _rule('Mix of letters and numbers recommended'),
                    ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Update Password',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
            ]),
          ),
        ]),
      );

  Widget _passField(String label, TextEditingController ctrl, bool visible,
          VoidCallback toggle) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            obscureText: !visible,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              suffixIcon: IconButton(
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                  onPressed: toggle),
            )),
      ]);

  Widget _formField(String label, TextEditingController ctrl, IconData icon,
          {TextInputType? type}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            keyboardType: type,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            )),
      ]);

  Widget _infoRow(String label, String value, IconData icon,
          [Color? valueColor]) =>
      Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ])),
      ]);

  Widget _rule(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 13, color: Colors.green),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );

  BoxDecoration _cardDec() => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ]);
}


