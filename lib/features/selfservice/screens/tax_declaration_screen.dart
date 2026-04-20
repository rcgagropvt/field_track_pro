import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';

class TaxDeclarationScreen extends StatefulWidget {
  const TaxDeclarationScreen({super.key});

  @override
  State<TaxDeclarationScreen> createState() => _TaxDeclarationScreenState();
}

class _TaxDeclarationScreenState extends State<TaxDeclarationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _taxRegime = 'new';
  final _currentFY = '2026-27';

  // Section 80C
  final _ppfC = TextEditingController();
  final _elssC = TextEditingController();
  final _licC = TextEditingController();
  final _nscC = TextEditingController();
  final _tuitionC = TextEditingController();
  final _homeLoanPrincipalC = TextEditingController();
  final _sukanyaC = TextEditingController();
  final _taxFdC = TextEditingController();

  // Section 80D
  final _healthSelfC = TextEditingController();
  final _healthParentsC = TextEditingController();
  final _preventiveC = TextEditingController();

  // Section 24b
  final _homeLoanInterestSelfC = TextEditingController();
  final _homeLoanInterestLetC = TextEditingController();

  // HRA
  final _monthlyRentC = TextEditingController();
  final _landlordNameC = TextEditingController();
  final _landlordPanC = TextEditingController();

  // Other
  final _npsC = TextEditingController();
  final _eduLoanC = TextEditingController();
  final _donationsC = TextEditingController();
  final _savingsInterestC = TextEditingController();

  Map<String, dynamic>? _existingDeclaration;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in [
      _ppfC, _elssC, _licC, _nscC, _tuitionC, _homeLoanPrincipalC,
      _sukanyaC, _taxFdC, _healthSelfC, _healthParentsC, _preventiveC,
      _homeLoanInterestSelfC, _homeLoanInterestLetC, _monthlyRentC,
      _landlordNameC, _landlordPanC, _npsC, _eduLoanC, _donationsC,
      _savingsInterestC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.userId ?? '';

      // Load salary for tax regime
      final salary = await SupabaseService.client
          .from('employee_salary')
          .select('tax_regime')
          .eq('user_id', userId)
          .isFilter('effective_to', null)
          .maybeSingle();

      if (salary != null) {
        _taxRegime = salary['tax_regime'] ?? 'new';
      }

      // Load existing declaration
      final existing = await SupabaseService.client
          .from('company_settings')
          .select('setting_value')
          .eq('setting_key', 'tax_declaration_$userId')
          .maybeSingle();

      if (existing != null && existing['setting_value'] != null) {
        try {
          final decoded = existing['setting_value'];
          if (decoded is Map<String, dynamic>) {
            _existingDeclaration = decoded;
            _populateFields(decoded);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Tax load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _ppfC.text = data['ppf']?.toString() ?? '';
    _elssC.text = data['elss']?.toString() ?? '';
    _licC.text = data['lic']?.toString() ?? '';
    _nscC.text = data['nsc']?.toString() ?? '';
    _tuitionC.text = data['tuition']?.toString() ?? '';
    _homeLoanPrincipalC.text = data['home_loan_principal']?.toString() ?? '';
    _sukanyaC.text = data['sukanya']?.toString() ?? '';
    _taxFdC.text = data['tax_fd']?.toString() ?? '';
    _healthSelfC.text = data['health_self']?.toString() ?? '';
    _healthParentsC.text = data['health_parents']?.toString() ?? '';
    _preventiveC.text = data['preventive']?.toString() ?? '';
    _homeLoanInterestSelfC.text = data['home_interest_self']?.toString() ?? '';
    _homeLoanInterestLetC.text = data['home_interest_let']?.toString() ?? '';
    _monthlyRentC.text = data['monthly_rent']?.toString() ?? '';
    _landlordNameC.text = data['landlord_name']?.toString() ?? '';
    _landlordPanC.text = data['landlord_pan']?.toString() ?? '';
    _npsC.text = data['nps']?.toString() ?? '';
    _eduLoanC.text = data['edu_loan']?.toString() ?? '';
    _donationsC.text = data['donations']?.toString() ?? '';
    _savingsInterestC.text = data['savings_interest']?.toString() ?? '';
  }

  Future<void> _saveDeclaration() async {
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.userId ?? '';

      final sec80c = (double.tryParse(_ppfC.text) ?? 0) +
          (double.tryParse(_elssC.text) ?? 0) +
          (double.tryParse(_licC.text) ?? 0) +
          (double.tryParse(_nscC.text) ?? 0) +
          (double.tryParse(_tuitionC.text) ?? 0) +
          (double.tryParse(_homeLoanPrincipalC.text) ?? 0) +
          (double.tryParse(_sukanyaC.text) ?? 0) +
          (double.tryParse(_taxFdC.text) ?? 0);

      if (sec80c > 150000) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Section 80C total cannot exceed ₹1,50,000'),
          backgroundColor: Colors.orange,
        ));
      }

      final data = {
        'fy': _currentFY,
        'tax_regime': _taxRegime,
        'ppf': double.tryParse(_ppfC.text) ?? 0,
        'elss': double.tryParse(_elssC.text) ?? 0,
        'lic': double.tryParse(_licC.text) ?? 0,
        'nsc': double.tryParse(_nscC.text) ?? 0,
        'tuition': double.tryParse(_tuitionC.text) ?? 0,
        'home_loan_principal': double.tryParse(_homeLoanPrincipalC.text) ?? 0,
        'sukanya': double.tryParse(_sukanyaC.text) ?? 0,
        'tax_fd': double.tryParse(_taxFdC.text) ?? 0,
        'sec_80c_total': sec80c,
        'health_self': double.tryParse(_healthSelfC.text) ?? 0,
        'health_parents': double.tryParse(_healthParentsC.text) ?? 0,
        'preventive': double.tryParse(_preventiveC.text) ?? 0,
        'home_interest_self': double.tryParse(_homeLoanInterestSelfC.text) ?? 0,
        'home_interest_let': double.tryParse(_homeLoanInterestLetC.text) ?? 0,
        'monthly_rent': double.tryParse(_monthlyRentC.text) ?? 0,
        'landlord_name': _landlordNameC.text.trim(),
        'landlord_pan': _landlordPanC.text.trim(),
        'nps': double.tryParse(_npsC.text) ?? 0,
        'edu_loan': double.tryParse(_eduLoanC.text) ?? 0,
        'donations': double.tryParse(_donationsC.text) ?? 0,
        'savings_interest': double.tryParse(_savingsInterestC.text) ?? 0,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'submitted',
      };

      // Store as a company_settings row per user
      final key = 'tax_declaration_$userId';
      final exists = await SupabaseService.client
          .from('company_settings')
          .select('id')
          .eq('setting_key', key)
          .maybeSingle();

      if (exists != null) {
        await SupabaseService.client
            .from('company_settings')
            .update({
          'setting_value': data,
          'category': 'tax_declaration',
          'description': 'Tax declaration for $userId',
        }).eq('setting_key', key);
      } else {
        await SupabaseService.client.from('company_settings').insert({
          'setting_key': key,
          'setting_value': data,
          'category': 'tax_declaration',
          'description': 'Tax declaration for $userId',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tax declaration submitted!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tax Declaration')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fmt = NumberFormat('#,##,###');
    final sec80c = (double.tryParse(_ppfC.text) ?? 0) +
        (double.tryParse(_elssC.text) ?? 0) +
        (double.tryParse(_licC.text) ?? 0) +
        (double.tryParse(_nscC.text) ?? 0) +
        (double.tryParse(_tuitionC.text) ?? 0) +
        (double.tryParse(_homeLoanPrincipalC.text) ?? 0) +
        (double.tryParse(_sukanyaC.text) ?? 0) +
        (double.tryParse(_taxFdC.text) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tax Declaration — FY $_currentFY'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveDeclaration,
                  tooltip: 'Submit Declaration',
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Regime info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF006A61).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel, color: Color(0xFF006A61)),
                  const SizedBox(width: 8),
                  Text('Tax Regime: ${_taxRegime.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_existingDeclaration != null)
                    const Chip(
                      label: Text('Submitted', style: TextStyle(fontSize: 11)),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 80C
            _sectionHeader('Section 80C — Investments',
                '₹${fmt.format(sec80c.toInt())} / ₹1,50,000',
                sec80c > 150000 ? Colors.red : Colors.green),
            _amountField('PPF / VPF', _ppfC),
            _amountField('ELSS Mutual Funds', _elssC),
            _amountField('Life Insurance Premium', _licC),
            _amountField('NSC', _nscC),
            _amountField('Children Tuition Fee', _tuitionC),
            _amountField('Home Loan Principal', _homeLoanPrincipalC),
            _amountField('Sukanya Samriddhi', _sukanyaC),
            _amountField('Tax Saver FD (5yr)', _taxFdC),
            const SizedBox(height: 16),

            // Section 80D
            _sectionHeader('Section 80D — Health Insurance', '', Colors.blue),
            _amountField('Self & Family Premium', _healthSelfC),
            _amountField('Parents Premium', _healthParentsC),
            _amountField('Preventive Health Checkup', _preventiveC),
            const SizedBox(height: 16),

            // Section 24b
            _sectionHeader(
                'Section 24(b) — Home Loan Interest', '', Colors.orange),
            _amountField('Self-Occupied Property', _homeLoanInterestSelfC),
            _amountField('Let-Out Property', _homeLoanInterestLetC),
            const SizedBox(height: 16),

            // HRA
            _sectionHeader('HRA Exemption', '', Colors.purple),
            _amountField('Monthly Rent Paid', _monthlyRentC),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _landlordNameC,
                decoration: const InputDecoration(
                  labelText: 'Landlord Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _landlordPanC,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Landlord PAN (required if rent > ₹1L/yr)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Other
            _sectionHeader('Other Deductions', '', Colors.teal),
            _amountField('80CCD(1B) — NPS (max ₹50,000)', _npsC),
            _amountField('80E — Education Loan Interest', _eduLoanC),
            _amountField('80G — Donations', _donationsC),
            _amountField('80TTA — Savings Interest (max ₹10,000)',
                _savingsInterestC),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveDeclaration,
                icon: const Icon(Icons.send),
                label: Text(_isSaving
                    ? 'Submitting...'
                    : _existingDeclaration != null
                        ? 'Update Declaration'
                        : 'Submit Declaration'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006A61),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
        ],
      ),
    );
  }

  Widget _amountField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '₹ ',
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
