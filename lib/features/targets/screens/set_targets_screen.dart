import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/custom_button.dart';

class SetTargetsScreen extends StatefulWidget {
  const SetTargetsScreen({super.key});
  @override
  State<SetTargetsScreen> createState() => _SetTargetsScreenState();
}

class _SetTargetsScreenState extends State<SetTargetsScreen> {
  List<Map<String, dynamic>> _employees = [];
  String? _selectedUserId;
  String? _selectedUserName;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _loading = false;
  bool _saving = false;

  final _visitsCtrl = TextEditingController();
  final _ordersCtrl = TextEditingController();
  final _revenueCtrl = TextEditingController();
  final _partiesCtrl = TextEditingController();

  final _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final emps = await SupabaseService.client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'employee')
        .eq('is_active', true)
        .order('full_name');
    setState(() => _employees = List<Map<String, dynamic>>.from(emps as List));
  }

  Future<void> _loadExistingTarget() async {
    if (_selectedUserId == null) return;
    setState(() => _loading = true);
    try {
      final targets = await SupabaseService.client
          .from('targets')
          .select()
          .eq('user_id', _selectedUserId!)
          .eq('month', _selectedMonth)
          .eq('year', _selectedYear)
          .limit(1);

      if ((targets as List).isNotEmpty) {
        final t = targets.first;
        _visitsCtrl.text = (t['target_visits'] ?? '').toString();
        _ordersCtrl.text = (t['target_orders'] ?? '').toString();
        _revenueCtrl.text = (t['target_revenue'] ?? '').toString();
        _partiesCtrl.text = (t['target_parties'] ?? '').toString();
      } else {
        _visitsCtrl.clear();
        _ordersCtrl.clear();
        _revenueCtrl.clear();
        _partiesCtrl.clear();
      }
    } catch (e) {
      debugPrint('Load target error: \$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an employee first')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'user_id': _selectedUserId,
        'month': _selectedMonth,
        'year': _selectedYear,
        'target_visits': int.tryParse(_visitsCtrl.text) ?? 0,
        'target_orders': int.tryParse(_ordersCtrl.text) ?? 0,
        'target_revenue': double.tryParse(_revenueCtrl.text) ?? 0,
        'target_parties': int.tryParse(_partiesCtrl.text) ?? 0,
        'set_by': SupabaseService.userId,
      };

      await SupabaseService.client
          .from('targets')
          .upsert(data, onConflict: 'user_id,month,year');

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Target set for \$_selectedUserName - \${_months[_selectedMonth]} \$_selectedYear'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Set Targets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Employee + Month selector
          _card([
            const Text('Select Employee & Period',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              hint: const Text('Choose employee'),
              decoration: _inputDec('Employee'),
              items: _employees.map((e) => DropdownMenuItem(
                value: e['id'] as String,
                child: Text(e['full_name'] as String),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedUserId = v;
                  _selectedUserName = _employees
                      .firstWhere((e) => e['id'] == v)['full_name'] as String;
                });
                _loadExistingTarget();
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: _inputDec('Month'),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1, child: Text(_months[i + 1]),
                  )),
                  onChanged: (v) {
                    setState(() => _selectedMonth = v!);
                    _loadExistingTarget();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: _inputDec('Year'),
                  items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
                    value: y, child: Text(y.toString()),
                  )).toList(),
                  onChanged: (v) {
                    setState(() => _selectedYear = v!);
                    _loadExistingTarget();
                  },
                ),
              ),
            ]),
          ]),

          const SizedBox(height: 16),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _card([
              const Text('Set Monthly Targets',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              _targetField(_visitsCtrl, Icons.store, 'Visits Target', 'e.g. 25', Colors.blue),
              const SizedBox(height: 12),
              _targetField(_ordersCtrl, Icons.shopping_cart, 'Orders Target', 'e.g. 15', Colors.orange),
              const SizedBox(height: 12),
              _targetField(_revenueCtrl, Icons.currency_rupee, 'Revenue Target (₹)', 'e.g. 150000', Colors.green),
              const SizedBox(height: 12),
              _targetField(_partiesCtrl, Icons.person_add, 'New Parties Target', 'e.g. 5', Colors.purple),
            ]),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Save Targets',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _targetField(TextEditingController ctrl, IconData icon,
      String label, String hint, Color color) => TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );
}
