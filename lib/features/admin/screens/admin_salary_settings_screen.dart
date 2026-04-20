import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';

class AdminSalarySettingsScreen extends StatefulWidget {
  const AdminSalarySettingsScreen({super.key});

  @override
  State<AdminSalarySettingsScreen> createState() =>
      _AdminSalarySettingsScreenState();
}

class _AdminSalarySettingsScreenState extends State<AdminSalarySettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _ptSlabs = [];
  List<Map<String, dynamic>> _components = [];
  bool _isLoading = true;

  final _settingKeys = [
    'basic_percent',
    'hra_percent',
    'pf_employee_percent',
    'pf_employer_percent',
    'pf_wage_ceiling',
    'esi_employee_percent',
    'esi_employer_percent',
    'esi_wage_ceiling',
    'gratuity_percent',
    'professional_tax_state',
    'tds_old_regime',
    'tds_new_regime',
    'late_marks_for_deduction',
    'overtime_multiplier',
  ];

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
            .from('company_settings')
            .select('setting_key, setting_value')
            .inFilter('setting_key', _settingKeys),
        SupabaseService.client
            .from('professional_tax_slabs')
            .select()
            .eq('is_active', true)
            .order('state')
            .order('monthly_salary_from'),
        SupabaseService.client
            .from('salary_components')
            .select()
            .order('sort_order'),
      ]);

      _settings = {};
      for (final s in results[0] as List) {
        _settings[s['setting_key']] =
            s['setting_value']?.toString().replaceAll('"', '') ?? '';
      }
      _ptSlabs = List<Map<String, dynamic>>.from(results[1] as List);
      _components = List<Map<String, dynamic>>.from(results[2] as List);
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
        title: const Text('Salary & Payroll Settings'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Structure'),
            Tab(text: 'Statutory'),
            Tab(text: 'PT Slabs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _structureTab(),
                _statutoryTab(),
                _ptSlabsTab(),
              ],
            ),
    );
  }

  // ── SALARY STRUCTURE TAB ──
  Widget _structureTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _settingHeader('Salary Split', Icons.pie_chart),
        _settingSlider('Basic % of CTC', 'basic_percent', 30, 50),
        _settingSlider('HRA % of Basic', 'hra_percent', 30, 60),
        const SizedBox(height: 16),
        _settingHeader('Penalties', Icons.warning_amber),
        _settingNumber('Late Marks for 1 Day Deduction', 'late_marks_for_deduction'),
        _settingNumber('Overtime Multiplier (1x, 1.5x, 2x)', 'overtime_multiplier'),
        const SizedBox(height: 24),
        _settingHeader('Salary Components', Icons.list_alt),
        const SizedBox(height: 8),
        ..._components.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: Icon(
                  c['type'] == 'earning'
                      ? Icons.add_circle_outline
                      : c['type'] == 'deduction'
                          ? Icons.remove_circle_outline
                          : Icons.business,
                  color: c['type'] == 'earning'
                      ? Colors.green
                      : c['type'] == 'deduction'
                          ? Colors.red
                          : Colors.blue,
                  size: 20,
                ),
                title: Text('${c['name']}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    '${c['code']} • ${c['type']} • ${c['calculation_type']}',
                    style: const TextStyle(fontSize: 11)),
                trailing: Switch(
                  value: c['is_active'] ?? true,
                  onChanged: (v) => _toggleComponent(c['id'], v),
                  activeColor: const Color(0xFF006A61),
                ),
              ),
            )),
      ],
    );
  }

  // ── STATUTORY TAB ──
  Widget _statutoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _settingHeader('Provident Fund (PF)', Icons.account_balance),
        _settingNumber('Employee PF %', 'pf_employee_percent'),
        _settingNumber('Employer PF %', 'pf_employer_percent'),
        _settingNumber('PF Wage Ceiling (₹)', 'pf_wage_ceiling'),
        const SizedBox(height: 16),
        _settingHeader('ESI', Icons.health_and_safety),
        _settingNumber('Employee ESI %', 'esi_employee_percent'),
        _settingNumber('Employer ESI %', 'esi_employer_percent'),
        _settingNumber('ESI Wage Ceiling (₹)', 'esi_wage_ceiling'),
        const SizedBox(height: 16),
        _settingHeader('Gratuity', Icons.card_giftcard),
        _settingNumber('Gratuity % of Basic', 'gratuity_percent'),
        const SizedBox(height: 16),
        _settingHeader('Professional Tax', Icons.receipt_long),
        _settingDropdown('State', 'professional_tax_state', [
          'karnataka',
          'maharashtra',
          'uttar_pradesh',
          'tamil_nadu',
          'west_bengal',
          'gujarat',
          'madhya_pradesh',
          'delhi',
          'rajasthan',
        ]),
        const SizedBox(height: 16),
        _settingHeader('Tax Regime', Icons.gavel),
        _settingDropdown('Default Tax Regime', 'tds_new_regime', [
          'new',
          'old',
        ]),
      ],
    );
  }

  // ── PT SLABS TAB ──
  Widget _ptSlabsTab() {
    final states = _ptSlabs.map((s) => s['state'].toString()).toSet().toList()
      ..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...states.map((state) {
          final slabs = _ptSlabs.where((s) => s['state'] == state).toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                  state.replaceAll('_', ' ').split(' ').map((w) =>
                      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${slabs.length} slabs',
                  style: const TextStyle(fontSize: 12)),
              children: [
                DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(
                        label: Text('From',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('To',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Tax ₹',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                  rows: slabs
                      .map((s) => DataRow(cells: [
                            DataCell(Text('₹${s['monthly_salary_from']}',
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text('₹${s['monthly_salary_to']}',
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text('₹${s['tax_amount']}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                          ]))
                      .toList(),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: OutlinedButton.icon(
                    onPressed: () => _addPTSlab(state),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Slab', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _addPTSlab(String state) {
    final fromC = TextEditingController();
    final toC = TextEditingController();
    final taxC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add PT Slab — ${state.replaceAll('_', ' ')}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: fromC,
                decoration: const InputDecoration(labelText: 'Salary From (₹)'),
                keyboardType: TextInputType.number),
            TextField(
                controller: toC,
                decoration: const InputDecoration(labelText: 'Salary To (₹)'),
                keyboardType: TextInputType.number),
            TextField(
                controller: taxC,
                decoration: const InputDecoration(labelText: 'Tax Amount (₹)'),
                keyboardType: TextInputType.number),
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
                    .from('professional_tax_slabs')
                    .insert({
                  'state': state,
                  'monthly_salary_from': double.tryParse(fromC.text) ?? 0,
                  'monthly_salary_to': double.tryParse(toC.text) ?? 0,
                  'tax_amount': double.tryParse(taxC.text) ?? 0,
                  'is_active': true,
                });
                Navigator.pop(ctx);
                _loadData();
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ──
  Widget _settingHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF006A61)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF006A61))),
        ],
      ),
    );
  }

  Widget _settingSlider(String label, String key, double min, double max) {
    final current =
        double.tryParse(_settings[key] ?? '40') ?? 40;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                Text('${current.toInt()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006A61))),
              ],
            ),
            Slider(
              value: current.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) * 2).toInt(),
              activeColor: const Color(0xFF006A61),
              onChangeEnd: (v) =>
                  _updateSetting(key, v.toInt().toString()),
              onChanged: (v) {
                setState(() => _settings[key] = v.toInt().toString());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingNumber(String label, String key) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: SizedBox(
          width: 90,
          child: TextField(
            controller:
                TextEditingController(text: _settings[key] ?? ''),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => _updateSetting(key, v),
          ),
        ),
      ),
    );
  }

  Widget _settingDropdown(
      String label, String key, List<String> options) {
    final current = _settings[key] ?? options.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: DropdownButton<String>(
          value: options.contains(current) ? current : options.first,
          underline: const SizedBox(),
          items: options
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(
                      o.replaceAll('_', ' ').split(' ').map((w) =>
                          w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '),
                      style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) => _updateSetting(key, v ?? options.first),
        ),
      ),
    );
  }

  Future<void> _toggleComponent(String id, bool active) async {
    await SupabaseService.client
        .from('salary_components')
        .update({'is_active': active}).eq('id', id);
    _loadData();
  }

  Future<void> _updateSetting(String key, String value) async {
    try {
      await SupabaseService.client
          .from('company_settings')
          .update({'setting_value': '"$value"'}).eq('setting_key', key);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Setting saved!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
