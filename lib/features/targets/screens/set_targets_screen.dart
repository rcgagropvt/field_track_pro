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
  final _incentiveCtrl = TextEditingController();
  final _incentiveNoteCtrl = TextEditingController();
  String _incentiveType = 'fixed';

  final _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _visitsCtrl.dispose();
    _ordersCtrl.dispose();
    _revenueCtrl.dispose();
    _partiesCtrl.dispose();
    _incentiveCtrl.dispose();
    _incentiveNoteCtrl.dispose();
    super.dispose();
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
        _incentiveCtrl.text = (t['incentive_amount'] ?? '0').toString();
        _incentiveNoteCtrl.text = (t['incentive_note'] ?? '').toString();
        _incentiveType = (t['incentive_type'] ?? 'fixed').toString();
      } else {
        _visitsCtrl.clear();
        _ordersCtrl.clear();
        _revenueCtrl.clear();
        _partiesCtrl.clear();
        _incentiveCtrl.clear();
        _incentiveNoteCtrl.clear();
        _incentiveType = 'fixed';
      }
    } catch (e) {
      debugPrint('Load target error: $e');
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
        'incentive_amount': double.tryParse(_incentiveCtrl.text) ?? 0,
        'incentive_type': _incentiveType,
        'incentive_note': _incentiveNoteCtrl.text.trim(),
        'set_by': SupabaseService.userId,
      };

      await SupabaseService.client
          .from('targets')
          .upsert(data, onConflict: 'user_id,month,year');

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Target + Incentive set for $_selectedUserName — ${_months[_selectedMonth]} $_selectedYear'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Set Targets & Incentives',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee + Month selector
              _card([
                const Text('Select Employee & Period',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedUserId,
                  hint: const Text('Choose employee'),
                  decoration: _inputDec('Employee'),
                  items: _employees
                      .map((e) => DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(e['full_name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedUserId = v;
                      _selectedUserName = _employees.firstWhere(
                          (e) => e['id'] == v)['full_name'] as String;
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
                      items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(_months[i + 1]),
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
                      items: [2024, 2025, 2026, 2027]
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              ))
                          .toList(),
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
                // Targets section
                _card([
                  const Text('Monthly Targets',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  _targetField(_visitsCtrl, Icons.store, 'Visits Target',
                      'e.g. 25', Colors.blue),
                  const SizedBox(height: 12),
                  _targetField(_ordersCtrl, Icons.shopping_cart,
                      'Orders Target', 'e.g. 15', Colors.orange),
                  const SizedBox(height: 12),
                  _targetField(_revenueCtrl, Icons.currency_rupee,
                      'Revenue Target (₹)', 'e.g. 150000', Colors.green),
                  const SizedBox(height: 12),
                  _targetField(_partiesCtrl, Icons.person_add,
                      'New Parties Target', 'e.g. 5', Colors.purple),
                ]),

                const SizedBox(height: 16),

                // Incentive section
                _card([
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.emoji_events,
                          color: Colors.amber.shade700, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Incentive Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Set the reward amount the rep earns on hitting targets',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Incentive type selector
                  const Text('Incentive Type',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _typeChip('fixed', 'Fixed', Icons.payments),
                    const SizedBox(width: 8),
                    _typeChip('per_unit', 'Per Order', Icons.add_shopping_cart),
                  ]),
                  const SizedBox(height: 16),

                  // Incentive amount
                  _targetField(
                    _incentiveCtrl,
                    Icons.currency_rupee,
                    _incentiveType == 'fixed'
                        ? 'Total Incentive Amount (₹)'
                        : 'Amount Per Extra Order (₹)',
                    _incentiveType == 'fixed' ? 'e.g. 5000' : 'e.g. 50',
                    Colors.amber.shade700,
                  ),
                  const SizedBox(height: 12),

                  // Incentive note
                  TextField(
                    controller: _incentiveNoteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Note for Rep (optional)',
                      hintText:
                          'e.g. "Hit 100% to earn full bonus + dinner voucher"',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payout rules explanation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payout Rules',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue.shade700)),
                        const SizedBox(height: 6),
                        if (_incentiveType == 'fixed') ...[
                          _ruleRow('100%+ achievement', '100% of incentive'),
                          _ruleRow('90-99% achievement', '90% of incentive'),
                          _ruleRow('80-89% achievement', '75% of incentive'),
                          _ruleRow('70-79% achievement', '50% of incentive'),
                          _ruleRow('Below 70%', 'No incentive'),
                        ] else ...[
                          _ruleRow('Per extra order',
                              '₹${_incentiveCtrl.text.isNotEmpty ? _incentiveCtrl.text : '0'} for each order above target'),
                          _ruleRow('Example',
                              'Target: ${_ordersCtrl.text.isNotEmpty ? _ordersCtrl.text : '0'} orders, Actual: ${int.tryParse(_ordersCtrl.text) != null ? (int.parse(_ordersCtrl.text) + 5).toString() : '?'} → 5 × ₹${_incentiveCtrl.text.isNotEmpty ? _incentiveCtrl.text : '0'}'),
                        ],
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),
                CustomButton(
                  text: 'Save Targets & Incentive',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
              const SizedBox(height: 20),
            ]),
      ),
    );
  }

  Widget _typeChip(String value, String label, IconData icon) {
    final selected = _incentiveType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _incentiveType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected
                    ? Colors.amber.shade400
                    : Colors.grey.shade300,
                width: selected ? 2 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.amber.shade700 : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: selected
                        ? Colors.amber.shade700
                        : Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }

  Widget _ruleRow(String left, String right) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text('• $left: ',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade600)),
          Expanded(
              child: Text(right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800))),
        ]),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _targetField(TextEditingController ctrl, IconData icon, String label,
          String hint, Color color) =>
      TextField(
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );
}
