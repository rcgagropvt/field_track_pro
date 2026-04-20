import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';

class AdminLeaveSettingsScreen extends StatefulWidget {
  const AdminLeaveSettingsScreen({super.key});

  @override
  State<AdminLeaveSettingsScreen> createState() =>
      _AdminLeaveSettingsScreenState();
}

class _AdminLeaveSettingsScreenState extends State<AdminLeaveSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> _leaveBalances = [];
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic> _leaveSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('leave_types')
            .select()
            .order('name'),
        SupabaseService.client
            .from('leave_balances')
            .select('*, profiles!leave_balances_user_id_fkey(full_name), leave_types!inner(code, name)')
            .eq('year', DateTime.now().year)
            .order('created_at'),
        SupabaseService.client
            .from('profiles')
            .select('id, full_name, role')
            .neq('role', 'admin'),
        SupabaseService.client
            .from('company_settings')
            .select('setting_key, setting_value')
            .inFilter('setting_key', [
          'leave_cycle',
          'sandwich_rule',
          'max_consecutive_leaves',
          'min_days_advance_leave',
          'negative_balance_allowed',
        ]),
      ]);

      _leaveTypes = List<Map<String, dynamic>>.from(results[0] as List);
      _leaveBalances = List<Map<String, dynamic>>.from(results[1] as List);
      _employees = List<Map<String, dynamic>>.from(results[2] as List);

      _leaveSettings = {};
      for (final s in results[3] as List) {
        _leaveSettings[s['setting_key']] = s['setting_value'];
      }
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Settings'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Leave Types'),
            Tab(text: 'Balances'),
            Tab(text: 'Policies'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _leaveTypesTab(),
                _balancesTab(),
                _policiesTab(),
              ],
            ),
    );
  }

  // ── LEAVE TYPES TAB ──
  Widget _leaveTypesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaveTypes.length + 1,
      itemBuilder: (context, index) {
        if (index == _leaveTypes.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showLeaveTypeDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Leave Type'),
            ),
          );
        }
        final lt = _leaveTypes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: lt['is_paid'] == true
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              child: Text(lt['code'] ?? '',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: lt['is_paid'] == true
                          ? Colors.green.shade800
                          : Colors.red.shade800)),
            ),
            title: Text(lt['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${lt['annual_quota'] ?? 0} days/yr • '
                '${lt['is_paid'] == true ? 'Paid' : 'Unpaid'} • '
                'Carry: ${lt['max_carry_forward'] ?? 0}',
                style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: lt['is_active'] ?? true,
                  onChanged: (v) => _toggleLeaveType(lt['id'], v),
                  activeColor: const Color(0xFF006A61),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showLeaveTypeDialog(lt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLeaveTypeDialog(Map<String, dynamic>? existing) {
    final isNew = existing == null;
    final nameC = TextEditingController(text: existing?['name'] ?? '');
    final codeC = TextEditingController(text: existing?['code'] ?? '');
    final quotaC = TextEditingController(
        text: (existing?['annual_quota'] ?? 0).toString());
    final carryC = TextEditingController(
        text: (existing?['max_carry_forward'] ?? 0).toString());
    final accrualC = TextEditingController(
        text: (existing?['monthly_accrual'] ?? 0).toString());
    final maxEncashC = TextEditingController(
        text: (existing?['max_encashment'] ?? 0).toString());
    final minDaysC = TextEditingController(
        text: (existing?['min_days_per_application'] ?? 0.5).toString());
    final maxDaysC = TextEditingController(
        text: (existing?['max_days_per_application'] ?? 0).toString());
    bool isPaid = existing?['is_paid'] ?? true;
    bool requiresApproval = existing?['requires_approval'] ?? true;
    bool requiresAttachment = existing?['requires_attachment'] ?? false;
    bool isAccrual = existing?['is_accrual_based'] ?? false;
    String applicableGender = existing?['applicable_gender'] ?? 'all';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Add Leave Type' : 'Edit ${existing!['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    decoration:
                        const InputDecoration(labelText: 'Leave Name')),
                const SizedBox(height: 8),
                TextField(
                    controller: codeC,
                    decoration: const InputDecoration(labelText: 'Code (e.g., CL)'),
                    textCapitalization: TextCapitalization.characters),
                const SizedBox(height: 8),
                TextField(
                    controller: quotaC,
                    decoration: const InputDecoration(labelText: 'Annual Quota (days)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Paid Leave', style: TextStyle(fontSize: 14)),
                  value: isPaid,
                  onChanged: (v) => setDialogState(() => isPaid = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Requires Approval', style: TextStyle(fontSize: 14)),
                  value: requiresApproval,
                  onChanged: (v) => setDialogState(() => requiresApproval = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Requires Attachment', style: TextStyle(fontSize: 14)),
                  value: requiresAttachment,
                  onChanged: (v) =>
                      setDialogState(() => requiresAttachment = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Accrual Based', style: TextStyle(fontSize: 14)),
                  value: isAccrual,
                  onChanged: (v) => setDialogState(() => isAccrual = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (isAccrual) ...[
                  TextField(
                      controller: accrualC,
                      decoration: const InputDecoration(
                          labelText: 'Monthly Accrual (days)'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                ],
                TextField(
                    controller: carryC,
                    decoration: const InputDecoration(
                        labelText: 'Max Carry Forward (days)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(
                    controller: maxEncashC,
                    decoration: const InputDecoration(
                        labelText: 'Max Encashment (days)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: minDaysC,
                          decoration: const InputDecoration(labelText: 'Min Days'),
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                          controller: maxDaysC,
                          decoration: const InputDecoration(labelText: 'Max Days (0=unlimited)'),
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: applicableGender,
                  decoration: const InputDecoration(labelText: 'Applicable Gender'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'male', child: Text('Male Only')),
                    DropdownMenuItem(
                        value: 'female', child: Text('Female Only')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => applicableGender = v ?? 'all'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final data = {
                  'name': nameC.text.trim(),
                  'code': codeC.text.trim().toUpperCase(),
                  'annual_quota': double.tryParse(quotaC.text) ?? 0,
                  'is_paid': isPaid,
                  'requires_approval': requiresApproval,
                  'requires_attachment': requiresAttachment,
                  'is_accrual_based': isAccrual,
                  'monthly_accrual': double.tryParse(accrualC.text) ?? 0,
                  'max_carry_forward': double.tryParse(carryC.text) ?? 0,
                  'max_encashment': double.tryParse(maxEncashC.text) ?? 0,
                  'min_days_per_application':
                      double.tryParse(minDaysC.text) ?? 0.5,
                  'max_days_per_application':
                      double.tryParse(maxDaysC.text) ?? 0,
                  'applicable_gender': applicableGender,
                };
                try {
                  if (isNew) {
                    await SupabaseService.client
                        .from('leave_types')
                        .insert(data);
                  } else {
                    await SupabaseService.client
                        .from('leave_types')
                        .update(data)
                        .eq('id', existing!['id']);
                  }
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isNew ? 'Leave type added!' : 'Updated!'),
                      backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isNew ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLeaveType(String id, bool active) async {
    await SupabaseService.client
        .from('leave_types')
        .update({'is_active': active}).eq('id', id);
    _loadData();
  }

  // ── BALANCES TAB ──
  Widget _balancesTab() {
    if (_employees.isEmpty) {
      return const Center(child: Text('No employees found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final emp = _employees[index];
        final empBalances = _leaveBalances
            .where((b) => b['user_id'] == emp['id'])
            .toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF006A61),
              child: Text(
                  (emp['full_name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white)),
            ),
            title: Text(emp['full_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${empBalances.length} leave types',
                style: const TextStyle(fontSize: 12)),
            children: [
              ...empBalances.map((b) {
                final lt = b['leave_types'] as Map<String, dynamic>?;
                final credited = (b['credited'] as num?)?.toDouble() ?? 0;
                final used = (b['used'] as num?)?.toDouble() ?? 0;
                final available = credited - used;
                return ListTile(
                  dense: true,
                  title: Text('${lt?['name'] ?? lt?['code'] ?? ''}',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      'Credited: $credited • Used: $used',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${available.toStringAsFixed(1)} left',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: available > 0
                                  ? Colors.green
                                  : Colors.red)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () =>
                            _editBalance(b, emp['full_name']),
                      ),
                    ],
                  ),
                );
              }),
              if (empBalances.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No balances assigned. Run balance initialization.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        );
      },
    );
  }

  void _editBalance(Map<String, dynamic> balance, String empName) {
    final lt = balance['leave_types'] as Map<String, dynamic>?;
    final creditedC = TextEditingController(
        text: (balance['credited'] as num?)?.toString() ?? '0');
    final adjustedC = TextEditingController(
        text: (balance['adjusted'] as num?)?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${lt?['name']} — $empName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: creditedC,
                decoration: const InputDecoration(labelText: 'Credited (total quota)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: adjustedC,
                decoration:
                    const InputDecoration(labelText: 'Adjustment (+/−)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            Text(
                'Used: ${balance['used']} • Current available: ${((balance['credited'] as num?)?.toDouble() ?? 0) - ((balance['used'] as num?)?.toDouble() ?? 0)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await SupabaseService.client
                    .from('leave_balances')
                    .update({
                  'credited': double.tryParse(creditedC.text) ?? 0,
                  'adjusted': double.tryParse(adjustedC.text) ?? 0,
                }).eq('id', balance['id']);
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Balance updated!'),
                    backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── POLICIES TAB ──
  Widget _policiesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _policyCard(
          'Leave Cycle',
          _leaveSettings['leave_cycle']?.toString().replaceAll('"', '') ??
              'financial_year',
          Icons.calendar_month,
          options: ['financial_year', 'calendar_year'],
          settingKey: 'leave_cycle',
        ),
        _togglePolicy(
          'Sandwich Rule',
          'Count weekends/holidays between leaves as leave days',
          _leaveSettings['sandwich_rule']?.toString().replaceAll('"', '') ==
              'true',
          'sandwich_rule',
        ),
        _togglePolicy(
          'Negative Balance Allowed',
          'Allow employees to take more leaves than available',
          _leaveSettings['negative_balance_allowed']
                  ?.toString()
                  .replaceAll('"', '') ==
              'true',
          'negative_balance_allowed',
        ),
        _numberPolicy(
          'Max Consecutive Leaves',
          _leaveSettings['max_consecutive_leaves']
                  ?.toString()
                  .replaceAll('"', '') ??
              '10',
          'max_consecutive_leaves',
        ),
        _numberPolicy(
          'Min Days Advance for Leave',
          _leaveSettings['min_days_advance_leave']
                  ?.toString()
                  .replaceAll('"', '') ??
              '1',
          'min_days_advance_leave',
        ),
      ],
    );
  }

  Widget _policyCard(String title, String currentValue, IconData icon,
      {required List<String> options, required String settingKey}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF006A61)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: DropdownButton<String>(
          value: options.contains(currentValue) ? currentValue : options.first,
          underline: const SizedBox(),
          items: options
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) => _updateSetting(settingKey, v ?? options.first),
        ),
      ),
    );
  }

  Widget _togglePolicy(
      String title, String subtitle, bool value, String settingKey) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeColor: const Color(0xFF006A61),
        onChanged: (v) => _updateSetting(settingKey, v.toString()),
      ),
    );
  }

  Widget _numberPolicy(
      String title, String currentValue, String settingKey) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: SizedBox(
          width: 80,
          child: TextField(
            controller: TextEditingController(text: currentValue),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => _updateSetting(settingKey, v),
          ),
        ),
      ),
    );
  }

  Future<void> _updateSetting(String key, String value) async {
    try {
      await SupabaseService.client
          .from('company_settings')
          .update({'setting_value': '"$value"'}).eq('setting_key', key);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setting updated!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
