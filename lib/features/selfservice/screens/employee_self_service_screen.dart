import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import 'tax_declaration_screen.dart';

class EmployeeSelfServiceScreen extends StatefulWidget {
  const EmployeeSelfServiceScreen({super.key});

  @override
  State<EmployeeSelfServiceScreen> createState() =>
      _EmployeeSelfServiceScreenState();
}

class _EmployeeSelfServiceScreenState extends State<EmployeeSelfServiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _taxDeclarations = [];
  Map<String, dynamic>? _salary;
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

  void _viewRepayments(Map<String, dynamic> loan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LoanRepaymentScreen(loan: loan),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.userId ?? '';

      final loansResult = await SupabaseService.client
          .from('employee_loans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final salaryResult = await SupabaseService.client
          .from('employee_salary')
          .select()
          .eq('user_id', userId)
          .isFilter('effective_to', null)
          .maybeSingle();

      _loans = List<Map<String, dynamic>>.from(loansResult as List);
      _salary = salaryResult;
    } catch (e) {
      debugPrint('Self-service load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Service'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.account_balance_wallet, size: 18),
                text: 'Loans'),
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Tax'),
            Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Salary Info'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _loansTab(),
                _taxTab(),
                _salaryInfoTab(),
              ],
            ),
    );
  }

  // ── LOANS TAB ──
  Widget _loansTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _summaryCard(
                    'Active Loans',
                    _loans
                        .where((l) => l['status'] == 'active')
                        .length
                        .toString(),
                    Icons.account_balance,
                    Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                    'Total Balance',
                    '₹${NumberFormat('#,##,###').format(_loans.where((l) => l['status'] == 'active').fold<double>(0, (sum, l) => sum + ((l['balance'] as num?)?.toDouble() ?? 0)))}',
                    Icons.currency_rupee,
                    Colors.orange),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _applyForLoan,
              icon: const Icon(Icons.add),
              label: const Text('Apply for Loan / Advance'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('No loan applications',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _loans.length,
                  itemBuilder: (context, index) {
                    final loan = _loans[index];
                    final status = loan['status'] ?? 'pending';
                    final amount = (loan['amount'] as num?)?.toDouble() ?? 0;
                    final balance = (loan['balance'] as num?)?.toDouble() ?? 0;
                    final emi = (loan['emi_amount'] as num?)?.toDouble() ?? 0;
                    final paid =
                        (loan['installments_paid'] as num?)?.toInt() ?? 0;
                    final total =
                        (loan['total_installments'] as num?)?.toInt() ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      loan['type'] == 'advance'
                                          ? Icons.flash_on
                                          : Icons.account_balance,
                                      size: 18,
                                      color: const Color(0xFF006A61),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        (loan['type'] ?? 'loan')
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ],
                                ),
                                _statusChip(status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                'Amount: ₹${NumberFormat('#,##,###').format(amount)}',
                                style: const TextStyle(fontSize: 13)),
                            if (status == 'active') ...[
                              const SizedBox(height: 4),
                              Text(
                                  'EMI: ₹${NumberFormat('#,##,###').format(emi)} • Balance: ₹${NumberFormat('#,##,###').format(balance)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: total > 0 ? paid / total : 0,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF006A61)),
                              ),
                              const SizedBox(height: 4),
                              Text('$paid / $total installments paid',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                            ],
                            if (loan['reason'] != null &&
                                loan['reason'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Reason: ${loan['reason']}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic)),
                            ],
                            Text(
                                'Applied: ${DateFormat('dd MMM yyyy').format(DateTime.parse(loan['created_at']))}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400)),
                            if (status == 'active') ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _viewRepayments(loan),
                                  icon:
                                      const Icon(Icons.receipt_long, size: 16),
                                  label: const Text('View Repayments'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _applyForLoan() {
    final amountC = TextEditingController();
    final reasonC = TextEditingController();
    final emiC = TextEditingController();
    String type = 'loan';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Apply for Loan / Advance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'loan', label: Text('Loan')),
                    ButtonSegment(
                        value: 'advance', label: Text('Salary Advance')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) =>
                      setDialogState(() => type = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountC,
                  decoration: const InputDecoration(
                      labelText: 'Amount (₹)', prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                ),
                if (type == 'loan') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: emiC,
                    decoration: const InputDecoration(
                        labelText: 'Preferred EMI (₹/month)', prefixText: '₹ '),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: reasonC,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 3,
                ),
                if (type == 'advance')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        'Salary advance will be deducted from next month\'s salary.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade700)),
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
                final amount = double.tryParse(amountC.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')));
                  return;
                }
                final emi = double.tryParse(emiC.text) ?? 0;
                final installments = type == 'advance'
                    ? 1
                    : (emi > 0 ? (amount / emi).ceil() : 0);

                try {
                  await SupabaseService.client.from('employee_loans').insert({
                    'user_id': SupabaseService.userId,
                    'type': type,
                    'amount': amount,
                    'balance': amount,
                    'emi_amount': type == 'advance' ? amount : emi,
                    'total_installments': installments,
                    'installments_paid': 0,
                    'reason': reasonC.text.trim(),
                    'status': 'pending',
                  });
                  Navigator.pop(ctx);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Application submitted!'),
                        backgroundColor: Colors.green));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAX TAB ──
  Widget _taxTab() {
    final taxRegime = _salary?['tax_regime'] ?? 'new';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current regime
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF006A61).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Tax Regime',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(taxRegime == 'old' ? Icons.history : Icons.new_releases,
                      color: const Color(0xFF006A61)),
                  const SizedBox(width: 8),
                  Text(taxRegime == 'old' ? 'Old Regime' : 'New Regime',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  taxRegime == 'old'
                      ? 'Higher tax rates but eligible for deductions (80C, 80D, HRA etc.)'
                      : 'Lower tax rates with minimal deductions. Standard deduction of ₹75,000.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tax declaration sections
        _taxSection(
            'Section 80C — Investments',
            Icons.savings,
            [
              'PPF / VPF',
              'ELSS Mutual Funds',
              'Life Insurance Premium',
              'NSC',
              'Children Tuition Fee (max 2)',
              'Home Loan Principal',
              'Sukanya Samriddhi',
              'Tax Saver FD (5yr)',
            ],
            '₹1,50,000'),

        _taxSection(
            'Section 80D — Health Insurance',
            Icons.health_and_safety,
            [
              'Self & Family Premium',
              'Parents Premium',
              'Preventive Health Checkup',
            ],
            '₹25,000 – ₹1,00,000'),

        _taxSection(
            'Section 24(b) — Home Loan Interest',
            Icons.home,
            [
              'Home Loan Interest (Self-Occupied)',
              'Home Loan Interest (Let Out)',
            ],
            '₹2,00,000'),

        _taxSection(
            'HRA Exemption',
            Icons.apartment,
            [
              'Monthly Rent Paid',
              'Landlord Name & PAN (if rent > ₹1L/yr)',
            ],
            'As per HRA rules'),

        _taxSection(
            'Other Deductions',
            Icons.more_horiz,
            [
              '80CCD(1B) — NPS (₹50,000)',
              '80E — Education Loan Interest',
              '80G — Donations',
              '80TTA — Savings Interest (₹10,000)',
              '80U / 80DD — Disability',
            ],
            'Various'),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaxDeclarationScreen()),
              );
            },
            icon: const Icon(Icons.edit_document),
            label: const Text('Submit Tax Declaration'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF006A61),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _taxSection(
      String title, IconData icon, List<String> items, String limit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF006A61), size: 22),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('Limit: $limit',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          ...items.map((item) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.grey),
                title: Text(item, style: const TextStyle(fontSize: 13)),
                trailing: Text('₹ —',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              )),
        ],
      ),
    );
  }

  // ── SALARY INFO TAB ──
  Widget _salaryInfoTab() {
    if (_salary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Salary not configured yet',
                style: TextStyle(color: Colors.grey.shade500)),
            const Text('Contact your admin.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final annualCTC = (_salary!['annual_ctc'] as num).toDouble();
    final monthly = annualCTC / 12;
    final basic = annualCTC * 0.40 / 12;
    final hra = basic * 0.50;
    final isPF = _salary!['is_pf_applicable'] ?? true;
    final isESI = _salary!['is_esi_applicable'] ?? false;
    final pfBase = isPF ? (basic > 15000 ? 15000.0 : basic) : 0.0;
    final empPF = isPF ? pfBase * 0.12 : 0.0;
    final erPF = isPF ? pfBase * 0.12 : 0.0;
    final gratuity = basic * 0.0481;
    final gross = monthly - erPF - gratuity;
    final esiEmp = isESI && gross <= 21000 ? gross * 0.0075 : 0.0;
    final sa = gross - basic - hra;
    final netApprox = gross - empPF - esiEmp;
    final fmt = NumberFormat('#,##,###');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF006A61), Color(0xFF00897B)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Annual CTC',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('₹${fmt.format(annualCTC)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('₹${fmt.format(monthly)} / month',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _salarySection(
            'Earnings (Monthly)',
            Colors.green,
            [
              _salaryRow('Basic Salary (40%)', basic, fmt),
              _salaryRow('HRA (50% of Basic)', hra, fmt),
              _salaryRow('Special Allowance', sa, fmt),
            ],
            gross,
            fmt,
            'Gross Salary'),

        const SizedBox(height: 8),

        _salarySection(
            'Employee Deductions',
            Colors.red,
            [
              if (isPF) _salaryRow('Employee PF (12%)', empPF, fmt),
              if (isESI && esiEmp > 0)
                _salaryRow('Employee ESI (0.75%)', esiEmp, fmt),
            ],
            empPF + esiEmp,
            fmt,
            'Total Deductions'),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Approx. Net Pay / Month',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${fmt.format(netApprox.round())}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green.shade700)),
            ],
          ),
        ),

        const SizedBox(height: 8),

        _salarySection(
            'Employer Contributions (from CTC)',
            Colors.blue,
            [
              if (isPF) _salaryRow('Employer PF', erPF, fmt),
              _salaryRow('Gratuity (4.81%)', gratuity, fmt),
            ],
            erPF + gratuity,
            fmt,
            'Total'),

        const SizedBox(height: 16),

        // Flags
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuration',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _configRow('PF Applicable', isPF),
                _configRow('ESI Applicable', isESI),
                _configRow('PF Capped at ₹15,000',
                    _salary!['pf_capped_at_ceiling'] ?? true),
                _configRow('Tax Regime', null,
                    text: (_salary!['tax_regime'] ?? 'new')
                        .toString()
                        .toUpperCase()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _salarySection(String title, Color color, List<Widget> rows,
      double total, NumberFormat fmt, String totalLabel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 8),
            ...rows,
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${fmt.format(total.round())}',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _salaryRow(String label, double amount, NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text('₹${fmt.format(amount.round())}',
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _configRow(String label, bool? value, {String? text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          text != null
              ? Text(text,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))
              : Icon(value == true ? Icons.check_circle : Icons.cancel,
                  size: 18, color: value == true ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'active'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : status == 'rejected'
                ? Colors.red
                : status == 'completed'
                    ? Colors.blue
                    : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _LoanRepaymentScreen extends StatefulWidget {
  final Map<String, dynamic> loan;
  const _LoanRepaymentScreen({required this.loan});

  @override
  State<_LoanRepaymentScreen> createState() => _LoanRepaymentScreenState();
}

class _LoanRepaymentScreenState extends State<_LoanRepaymentScreen> {
  List<Map<String, dynamic>> _repayments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('loan_repayments')
          .select()
          .eq('loan_id', widget.loan['id'])
          .order('repayment_date', ascending: false);
      _repayments = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Repayment load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final amount = (loan['amount'] as num?)?.toDouble() ?? 0;
    final balance = (loan['balance'] as num?)?.toDouble() ?? 0;
    final emi = (loan['emi_amount'] as num?)?.toDouble() ?? 0;
    final paid = (loan['installments_paid'] as num?)?.toInt() ?? 0;
    final total = (loan['total_installments'] as num?)?.toInt() ?? 0;
    final fmt = NumberFormat('#,##,###');

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${(loan['type'] ?? 'Loan').toString().toUpperCase()} Repayments'),
      ),
      body: Column(
        children: [
          // Loan summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF006A61), Color(0xFF00897B)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryItem('Loan Amount', '₹${fmt.format(amount)}'),
                    _summaryItem('Balance', '₹${fmt.format(balance)}'),
                    _summaryItem('EMI', '₹${fmt.format(emi)}'),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: total > 0 ? paid / total : 0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                const SizedBox(height: 6),
                Text('$paid / $total installments paid',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                    '₹${fmt.format(amount - balance)} repaid • ₹${fmt.format(balance)} remaining',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Repayments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _repayments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No repayments recorded yet',
                                style: TextStyle(color: Colors.grey.shade500)),
                            const Text(
                                'Repayments are auto-deducted during payroll',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _repayments.length,
                        itemBuilder: (context, index) {
                          final r = _repayments[index];
                          final repAmount =
                              (r['amount'] as num?)?.toDouble() ?? 0;
                          final date = r['repayment_date'] ?? r['created_at'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.check_circle,
                                      color: Colors.green.shade700, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Installment #${index + 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          DateFormat('dd MMM yyyy').format(
                                              DateTime.parse(date.toString())),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Text('₹${fmt.format(repAmount)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.green)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
