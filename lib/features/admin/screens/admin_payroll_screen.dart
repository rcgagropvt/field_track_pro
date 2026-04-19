import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class AdminPayrollScreen extends StatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _salaryRecords = [];
  List<Map<String, dynamic>> _payrollRuns = [];
  Map<String, dynamic> _settings = {};
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
            .from('profiles')
            .select('id, full_name, department, designation, employee_id')
            .eq('is_active', true)
            .neq('role', 'admin')
            .order('full_name'),
        SupabaseService.client
            .from('employee_salary')
            .select('*, profiles!employee_salary_user_id_fkey(full_name, department)')
            .order('created_at', ascending: false),
        SupabaseService.client
            .from('payroll_runs')
            .select()
            .order('year', ascending: false)
            .order('month', ascending: false)
            .limit(12),
        SupabaseService.client
            .from('company_settings')
            .select('setting_key, setting_value')
            .eq('category', 'payroll'),
      ]);

      _employees = List<Map<String, dynamic>>.from(results[0] as List);
      _salaryRecords = List<Map<String, dynamic>>.from(results[1] as List);
      _payrollRuns = List<Map<String, dynamic>>.from(results[2] as List);

      _settings = {};
      for (final s in (results[3] as List)) {
        _settings[s['setting_key']] = s['setting_value'];
      }
    } catch (e) {
      debugPrint('Payroll load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Management'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Salary Setup'),
            Tab(text: 'Process Payroll'),
            Tab(text: 'Payroll History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _salarySetupTab(),
                _processPayrollTab(),
                _payrollHistoryTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // SALARY SETUP TAB
  // ═══════════════════════════════════════════
  Widget _salarySetupTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Employees without salary
          ..._employees.where((emp) {
            return !_salaryRecords
                .any((s) => s['user_id'] == emp['id'] && s['effective_to'] == null);
          }).map((emp) => _employeeSalaryCard(emp, null)),

          // Employees with salary
          ..._employees.where((emp) {
            return _salaryRecords
                .any((s) => s['user_id'] == emp['id'] && s['effective_to'] == null);
          }).map((emp) {
            final salary = _salaryRecords.firstWhere(
                (s) => s['user_id'] == emp['id'] && s['effective_to'] == null);
            return _employeeSalaryCard(emp, salary);
          }),
        ],
      ),
    );
  }

  Widget _employeeSalaryCard(
      Map<String, dynamic> emp, Map<String, dynamic>? salary) {
    final hasSalary = salary != null;
    final ctc = hasSalary ? (salary['annual_ctc'] as num).toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasSalary
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  (emp['full_name'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      '${emp['designation'] ?? ''} ${emp['department'] != null ? '• ${emp['department']}' : ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (hasSalary)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${NumberFormat('#,##,###').format(ctc)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('CTC/yr',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasSalary) ...[
            Row(
              children: [
                _miniChip('Monthly',
                    '₹${NumberFormat('#,##,###').format(ctc / 12)}'),
                const SizedBox(width: 8),
                _miniChip(
                    'PF', salary['is_pf_applicable'] == true ? 'Yes' : 'No'),
                _miniChip(
                    'ESI', salary['is_esi_applicable'] == true ? 'Yes' : 'No'),
                _miniChip('Tax', salary['tax_regime'] ?? 'new'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSalaryDialog(emp, salary),
              icon: Icon(hasSalary ? Icons.edit : Icons.add, size: 18),
              label: Text(hasSalary ? 'Edit Salary' : 'Set Salary'),
              style: OutlinedButton.styleFrom(
                foregroundColor: hasSalary ? AppColors.primary : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  void _showSalaryDialog(
      Map<String, dynamic> emp, Map<String, dynamic>? existing) {
    final ctcCtrl = TextEditingController(
        text: existing != null
            ? (existing['annual_ctc'] as num).toStringAsFixed(0)
            : '');
    bool isPF = existing?['is_pf_applicable'] ?? true;
    bool isESI = existing?['is_esi_applicable'] ?? false;
    bool pfCapped = existing?['pf_capped_at_ceiling'] ?? true;
    String taxRegime = existing?['tax_regime'] ?? 'new';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              '${existing != null ? 'Edit' : 'Set'} Salary — ${emp['full_name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctcCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Annual CTC (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 300000',
                  ),
                ),
                const SizedBox(height: 12),
                // Live breakdown
                if (ctcCtrl.text.isNotEmpty) ...[
                  Builder(builder: (_) {
                    final ctc =
                        double.tryParse(ctcCtrl.text.replaceAll(',', '')) ?? 0;
                    if (ctc <= 0) return const SizedBox.shrink();
                    return _ctcBreakdown(ctc, isPF, isESI, pfCapped);
                  }),
                  const SizedBox(height: 12),
                ],
                SwitchListTile(
                  title: const Text('PF Applicable'),
                  subtitle: const Text('12% employee + 12% employer'),
                  value: isPF,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isPF = v),
                ),
                if (isPF)
                  SwitchListTile(
                    title: const Text('PF Capped at ₹15,000'),
                    subtitle: const Text('Max PF on ₹15,000 Basic'),
                    value: pfCapped,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => pfCapped = v),
                  ),
                SwitchListTile(
                  title: const Text('ESI Applicable'),
                  subtitle: const Text('Only if gross ≤ ₹21,000/month'),
                  value: isESI,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isESI = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: taxRegime,
                  decoration: const InputDecoration(
                    labelText: 'Tax Regime',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('New Regime')),
                    DropdownMenuItem(value: 'old', child: Text('Old Regime')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => taxRegime = v ?? 'new'),
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
                final ctc =
                    double.tryParse(ctcCtrl.text.replaceAll(',', '')) ?? 0;
                if (ctc <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid CTC')),
                  );
                  return;
                }

                try {
                  // Close existing salary record
                  if (existing != null) {
                    await SupabaseService.client
                        .from('employee_salary')
                        .update({
                      'effective_to': DateTime.now()
                          .toIso8601String()
                          .split('T')[0],
                    }).eq('id', existing['id']);
                  }

                  // Create new salary record
                  await SupabaseService.client
                      .from('employee_salary')
                      .insert({
                    'user_id': emp['id'],
                    'annual_ctc': ctc,
                    'is_pf_applicable': isPF,
                    'is_esi_applicable': isESI,
                    'pf_capped_at_ceiling': pfCapped,
                    'tax_regime': taxRegime,
                    'effective_from':
                        DateTime.now().toIso8601String().split('T')[0],
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Salary saved!'),
                        backgroundColor: Colors.green),
                  );
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctcBreakdown(double ctc, bool isPF, bool isESI, bool pfCapped) {
    final monthly = ctc / 12;
    final basic = ctc * 0.40 / 12;
    final hra = basic * 0.50;
    final pfBase = pfCapped ? (basic > 15000 ? 15000 : basic) : basic;
    final empPF = isPF ? pfBase * 0.12 : 0;
    final erPF = isPF ? pfBase * 0.12 : 0;
    final gratuity = basic * 0.0481;
    final gross = monthly - erPF - gratuity;
    final esiEmp = isESI ? gross * 0.0075 : 0;
    final sa = gross - basic - hra;
    final netApprox = gross - empPF - esiEmp;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Breakdown (approx)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          _breakdownRow('Basic', basic),
          _breakdownRow('HRA', hra),
          _breakdownRow('Special Allowance', sa),
          const Divider(height: 8),
          _breakdownRow('Gross', gross, bold: true),
          if (isPF) _breakdownRow('- Employee PF', empPF, isDeduction: true),
          if (isESI) _breakdownRow('- Employee ESI', esiEmp, isDeduction: true),
          const Divider(height: 8),
          _breakdownRow('≈ Net Pay', netApprox,
              bold: true, color: Colors.green),
          const Divider(height: 8),
          _breakdownRow('Employer PF', erPF, color: Colors.blue),
          _breakdownRow('Gratuity', gratuity, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double amount,
      {bool bold = false, bool isDeduction = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? (isDeduction ? Colors.red : Colors.black87))),
          Text(
              '${isDeduction ? "-" : ""}₹${NumberFormat('#,##,###').format(amount.round())}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? (isDeduction ? Colors.red : Colors.black87))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PROCESS PAYROLL TAB
  // ═══════════════════════════════════════════
  Widget _processPayrollTab() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final existingRun = _payrollRuns.where(
        (r) => r['month'] == currentMonth && r['year'] == currentYear);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Current month info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(DateFormat('MMMM yyyy').format(now),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '${_salaryRecords.where((s) => s['effective_to'] == null).length} employees with salary setup',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (existingRun.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 48),
                  const SizedBox(height: 8),
                  Text('Payroll already processed for this month',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold)),
                  Text('Status: ${existingRun.first['status']}',
                      style: TextStyle(color: Colors.green.shade600)),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _processPayroll,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text('Process Payroll',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will calculate salary for all employees with salary setup, factoring in attendance, leaves, late marks, and deductions.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _processPayroll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Process Payroll?'),
        content: Text(
            'This will generate payslips for ${_salaryRecords.where((s) => s['effective_to'] == null).length} employees for ${DateFormat('MMMM yyyy').format(DateTime.now())}.\n\nThis action considers attendance, leaves, late marks, and all deductions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Process')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);
      final totalCalendarDays = monthEnd.day;

      // Create payroll run
      final runResult = await SupabaseService.client
          .from('payroll_runs')
          .insert({
        'month': month,
        'year': year,
        'status': 'processing',
        'processed_by': SupabaseService.userId,
      }).select().single();

      final runId = runResult['id'];

      final activeSalaries =
          _salaryRecords.where((s) => s['effective_to'] == null).toList();

      double totalGross = 0;
      double totalDeductions = 0;
      double totalNet = 0;
      double totalEmployerCost = 0;

      // Settings
      final pfEmpPct =
          (_settings['pf_employee_percent'] as num?)?.toDouble() ?? 12;
      final pfErPct =
          (_settings['pf_employer_percent'] as num?)?.toDouble() ?? 12;
      final pfCeiling =
          (_settings['pf_wage_ceiling'] as num?)?.toDouble() ?? 15000;
      final esiEmpPct =
          (_settings['esi_employee_percent'] as num?)?.toDouble() ?? 0.75;
      final esiErPct =
          (_settings['esi_employer_percent'] as num?)?.toDouble() ?? 3.25;
      final gratuityPct =
          (_settings['gratuity_percent'] as num?)?.toDouble() ?? 4.81;
      final ptState = (_settings['professional_tax_state'] ?? 'uttar_pradesh')
          .toString()
          .replaceAll('"', '');
      final fullDayHours =
          (_settings['full_day_threshold_hours'] as num?)?.toDouble() ?? 7;
      final halfDayHours =
          (_settings['half_day_threshold_hours'] as num?)?.toDouble() ?? 4;
      final weekOffs = ['sunday'];
      final latePenaltyCount =
          (_settings['late_marks_for_deduction'] as num?)?.toInt() ?? 3;

      // Get holidays
      final holidays = await SupabaseService.client
          .from('holidays')
          .select('date')
          .gte('date', monthStart.toIso8601String().split('T')[0])
          .lte('date', monthEnd.toIso8601String().split('T')[0]);
      final holidayDates = (holidays as List)
          .map((h) => h['date'].toString())
          .toSet();

      // Calculate working days
      int workingDays = 0;
      int weekoffDays = 0;
      int holidayCount = 0;
      for (var d = monthStart;
          !d.isAfter(monthEnd);
          d = d.add(const Duration(days: 1))) {
        final dayName = DateFormat('EEEE').format(d).toLowerCase();
        if (weekOffs.contains(dayName)) {
          weekoffDays++;
        } else if (holidayDates
            .contains(d.toIso8601String().split('T')[0])) {
          holidayCount++;
        } else {
          workingDays++;
        }
      }

      // Get PT slabs
      final ptSlabs = await SupabaseService.client
          .from('professional_tax_slabs')
          .select()
          .eq('state', ptState)
          .eq('is_active', true)
          .order('monthly_salary_from');

      for (final salary in activeSalaries) {
        final userId = salary['user_id'];
        final annualCTC = (salary['annual_ctc'] as num).toDouble();
        final isPF = salary['is_pf_applicable'] ?? true;
        final isESI = salary['is_esi_applicable'] ?? false;
        final pfCapped = salary['pf_capped_at_ceiling'] ?? true;

        // Monthly CTC
        final monthlyCTC = annualCTC / 12;

        // Calculate components
        final basic = annualCTC * 0.40 / 12;
        final hra = basic * 0.50;
        final pfBase = isPF ? (pfCapped && basic > pfCeiling ? pfCeiling : basic) : 0.0;
        final empPF = isPF ? pfBase * pfEmpPct / 100 : 0.0;
        final erPF = isPF ? pfBase * pfErPct / 100 : 0.0;
        final gratuity = basic * gratuityPct / 100;
        final grossBase = monthlyCTC - erPF - gratuity;
        final esiEmp = isESI && grossBase <= 21000 ? grossBase * esiEmpPct / 100 : 0.0;
        final esiEr = isESI && grossBase <= 21000 ? grossBase * esiErPct / 100 : 0.0;
        final sa = grossBase - basic - hra;

        // Get attendance for the month
        final attendance = await SupabaseService.client
            .from('attendance')
            .select()
            .eq('user_id', userId)
            .gte('date', monthStart.toIso8601String().split('T')[0])
            .lte('date', monthEnd.toIso8601String().split('T')[0]);

        double daysPresent = 0;
        double daysHalfDay = 0;
        int lateCount = 0;
        double otHours = 0;

        for (final a in attendance as List) {
          final type = a['attendance_type'] ?? 'full_day';
          final hours = (a['work_hours'] as num?)?.toDouble() ?? 0;
          if (type == 'half_day' || (hours >= halfDayHours && hours < fullDayHours)) {
            daysHalfDay++;
            daysPresent += 0.5;
          } else if (hours >= fullDayHours || type == 'full_day') {
            daysPresent += 1;
          }
          if (a['is_late'] == true) lateCount++;
          otHours += (a['overtime_hours'] as num?)?.toDouble() ?? 0;
        }

        // Get approved leaves
        final leaves = await SupabaseService.client
            .from('leave_applications')
            .select('days, leave_types!inner(is_paid, code)')
            .eq('user_id', userId)
            .eq('status', 'approved')
            .gte('from_date', monthStart.toIso8601String().split('T')[0])
            .lte('to_date', monthEnd.toIso8601String().split('T')[0]);

        double paidLeaveDays = 0;
        double lwpDays = 0;
        for (final l in leaves as List) {
          final days = (l['days'] as num).toDouble();
          final lt = l['leave_types'] as Map<String, dynamic>;
          if (lt['is_paid'] == true) {
            paidLeaveDays += days;
          } else {
            lwpDays += days;
          }
        }

        final effectivePresent = daysPresent + paidLeaveDays;
        final absent = workingDays - effectivePresent - lwpDays;
        final totalLWP = lwpDays + (absent > 0 ? absent : 0);

        // LWP deduction
        final perDaySalary = grossBase / totalCalendarDays;
        final lwpDeduction = totalLWP * perDaySalary;

        // Late penalty
        final latePenaltyDays = (lateCount ~/ latePenaltyCount);
        final latePenalty = latePenaltyDays * perDaySalary;

        // Professional tax
        double ptAmount = 0;
        for (final slab in ptSlabs as List) {
          final from = (slab['monthly_salary_from'] as num).toDouble();
          final to = (slab['monthly_salary_to'] as num).toDouble();
          if (grossBase >= from && grossBase <= to) {
            ptAmount = (slab['tax_amount'] as num).toDouble();
            break;
          }
        }

        // Final calculations
        final grossEarnings = grossBase - lwpDeduction - latePenalty;
        final totalDeductionsAmt = empPF + esiEmp + ptAmount;
        final netPay = grossEarnings - totalDeductionsAmt;
        final employerCost = grossEarnings + erPF + esiEr + gratuity;

        // Earnings breakdown
        final earnings = [
          {'code': 'BASIC', 'name': 'Basic Salary', 'amount': basic},
          {'code': 'HRA', 'name': 'HRA', 'amount': hra},
          {'code': 'SA', 'name': 'Special Allowance', 'amount': sa > 0 ? sa : 0},
        ];

        // Deductions breakdown
        final deductions = <Map<String, dynamic>>[];
        if (isPF) {
          deductions
              .add({'code': 'EPF_EE', 'name': 'Employee PF', 'amount': empPF});
        }
        if (isESI && esiEmp > 0) {
          deductions.add(
              {'code': 'ESI_EE', 'name': 'Employee ESI', 'amount': esiEmp});
        }
        if (ptAmount > 0) {
          deductions.add(
              {'code': 'PT', 'name': 'Professional Tax', 'amount': ptAmount});
        }
        if (lwpDeduction > 0) {
          deductions.add({
            'code': 'LWP_DED',
            'name': 'LWP Deduction ($totalLWP days)',
            'amount': lwpDeduction
          });
        }
        if (latePenalty > 0) {
          deductions.add({
            'code': 'LATE_PEN',
            'name': 'Late Penalty ($lateCount lates)',
            'amount': latePenalty
          });
        }

        // Insert payslip
        await SupabaseService.client.from('payslips').insert({
          'payroll_run_id': runId,
          'user_id': userId,
          'month': month,
          'year': year,
          'total_working_days': workingDays,
          'days_present': daysPresent,
          'days_absent': absent > 0 ? absent : 0,
          'days_half_day': daysHalfDay,
          'days_leave': paidLeaveDays,
          'days_lwp': totalLWP,
          'days_holiday': holidayCount,
          'days_weekoff': weekoffDays,
          'late_count': lateCount,
          'overtime_hours': otHours,
          'annual_ctc': annualCTC,
          'monthly_ctc': monthlyCTC,
          'gross_earnings': grossEarnings > 0 ? grossEarnings : 0,
          'total_deductions': totalDeductionsAmt,
          'net_pay': netPay > 0 ? netPay : 0,
          'employer_pf': erPF,
          'employer_esi': esiEr,
          'gratuity_provision': gratuity,
          'total_employer_cost': employerCost > 0 ? employerCost : 0,
          'earnings_breakdown': earnings,
          'deductions_breakdown': deductions,
          'payment_status': 'unpaid',
        });

        totalGross += grossEarnings > 0 ? grossEarnings : 0;
        totalDeductions += totalDeductionsAmt;
        totalNet += netPay > 0 ? netPay : 0;
        totalEmployerCost += employerCost > 0 ? employerCost : 0;
      }

      // Update payroll run
      await SupabaseService.client.from('payroll_runs').update({
        'status': 'completed',
        'total_employees': activeSalaries.length,
        'total_gross': totalGross,
        'total_deductions': totalDeductions,
        'total_net_pay': totalNet,
        'total_employer_cost': totalEmployerCost,
        'processed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', runId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Payroll processed for ${activeSalaries.length} employees!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } catch (e) {
      debugPrint('Payroll error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payroll error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════
  // PAYROLL HISTORY TAB
  // ═══════════════════════════════════════════
  Widget _payrollHistoryTab() {
    if (_payrollRuns.isEmpty) {
      return const Center(
          child: Text('No payroll runs yet',
              style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payrollRuns.length,
        itemBuilder: (context, index) {
          final run = _payrollRuns[index];
          final monthDate = DateTime(run['year'], run['month']);
          final status = run['status'] ?? 'draft';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: status == 'completed'
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        status == 'completed'
                            ? Icons.check_circle
                            : Icons.pending,
                        color: status == 'completed'
                            ? Colors.green
                            : Colors.orange),
                    const SizedBox(width: 10),
                    Text(DateFormat('MMMM yyyy').format(monthDate),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Text('${run['total_employees'] ?? 0} employees',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _runStat(
                        'Gross',
                        '₹${NumberFormat('#,##,###').format((run['total_gross'] as num?)?.toInt() ?? 0)}',
                        Colors.blue),
                    _runStat(
                        'Deductions',
                        '₹${NumberFormat('#,##,###').format((run['total_deductions'] as num?)?.toInt() ?? 0)}',
                        Colors.red),
                    _runStat(
                        'Net Pay',
                        '₹${NumberFormat('#,##,###').format((run['total_net_pay'] as num?)?.toInt() ?? 0)}',
                        Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _viewPayslips(run),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Payslips'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _runStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  void _viewPayslips(Map<String, dynamic> run) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PayslipListScreen(payrollRunId: run['id'], run: run),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PAYSLIP LIST SCREEN (sub-screen)
// ═══════════════════════════════════════════════
class _PayslipListScreen extends StatefulWidget {
  final String payrollRunId;
  final Map<String, dynamic> run;
  const _PayslipListScreen(
      {required this.payrollRunId, required this.run});

  @override
  State<_PayslipListScreen> createState() => _PayslipListScreenState();
}

class _PayslipListScreenState extends State<_PayslipListScreen> {
  List<Map<String, dynamic>> _payslips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('payslips')
          .select('*, profiles!payslips_user_id_fkey(full_name, department, designation, employee_id)')
          .eq('payroll_run_id', widget.payrollRunId)
          .order('net_pay', ascending: false);
      _payslips = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Payslip load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final monthDate =
        DateTime(widget.run['year'], widget.run['month']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payslips — ${DateFormat('MMM yyyy').format(monthDate)}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _payslips.length,
              itemBuilder: (context, index) {
                final ps = _payslips[index];
                final profile =
                    ps['profiles'] as Map<String, dynamic>? ?? {};

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile['full_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(
                                  '${profile['designation'] ?? ''} • ${profile['department'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${NumberFormat('#,##,###').format((ps['net_pay'] as num).toInt())}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green),
                              ),
                              Text('Net Pay',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _payslipStat('Present',
                              '${ps['days_present']}/${ps['total_working_days']}'),
                          _payslipStat('Late', '${ps['late_count']}'),
                          _payslipStat('LWP', '${ps['days_lwp']}'),
                          _payslipStat(
                              'Gross',
                              '₹${NumberFormat('#,##,###').format((ps['gross_earnings'] as num).toInt())}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _viewPayslipDetail(ps, profile),
                              child: const Text('View Detail'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: ps['payment_status'] == 'paid'
                                  ? null
                                  : () => _markPaid(ps['id']),
                              icon: Icon(
                                  ps['payment_status'] == 'paid'
                                      ? Icons.check
                                      : Icons.payments,
                                  size: 18),
                              label: Text(ps['payment_status'] == 'paid'
                                  ? 'Paid'
                                  : 'Mark Paid'),
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      ps['payment_status'] == 'paid'
                                          ? Colors.grey
                                          : Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _payslipStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Future<void> _markPaid(String id) async {
    try {
      await SupabaseService.client.from('payslips').update({
        'payment_status': 'paid',
        'payment_date':
            DateTime.now().toIso8601String().split('T')[0],
      }).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _viewPayslipDetail(
      Map<String, dynamic> ps, Map<String, dynamic> profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayslipDetailScreen(payslip: ps, profile: profile),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PAYSLIP DETAIL + PDF SCREEN
// ═══════════════════════════════════════════════
class PayslipDetailScreen extends StatelessWidget {
  final Map<String, dynamic> payslip;
  final Map<String, dynamic> profile;
  const PayslipDetailScreen(
      {super.key, required this.payslip, required this.profile});

  @override
  Widget build(BuildContext context) {
    final monthDate =
        DateTime(payslip['year'], payslip['month']);
    final earnings =
        List<Map<String, dynamic>>.from(payslip['earnings_breakdown'] ?? []);
    final deductions =
        List<Map<String, dynamic>>.from(payslip['deductions_breakdown'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payslip — ${DateFormat('MMM yyyy').format(monthDate)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printPayslip(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow('Name', profile['full_name'] ?? ''),
                  _infoRow('Employee ID', profile['employee_id'] ?? '-'),
                  _infoRow('Department', profile['department'] ?? '-'),
                  _infoRow('Designation', profile['designation'] ?? '-'),
                  _infoRow('Pay Period',
                      DateFormat('MMMM yyyy').format(monthDate)),
                  _infoRow(
                      'CTC',
                      '₹${NumberFormat('#,##,###').format((payslip['annual_ctc'] as num).toInt())}/yr'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Attendance summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Summary',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _attStat('Working', '${payslip['total_working_days']}'),
                      _attStat('Present', '${payslip['days_present']}'),
                      _attStat('Leave', '${payslip['days_leave']}'),
                      _attStat('LWP', '${payslip['days_lwp']}'),
                      _attStat('Late', '${payslip['late_count']}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Earnings
            _sectionTitle('Earnings'),
            ...earnings.map((e) => _amountRow(
                e['name'] ?? e['code'],
                (e['amount'] as num).toDouble(),
                Colors.black87)),
            _divider(),
            _amountRow('Gross Earnings',
                (payslip['gross_earnings'] as num).toDouble(), Colors.green,
                bold: true),
            const SizedBox(height: 16),

            // Deductions
            _sectionTitle('Deductions'),
            ...deductions.map((d) => _amountRow(
                d['name'] ?? d['code'],
                (d['amount'] as num).toDouble(),
                Colors.red)),
            _divider(),
            _amountRow('Total Deductions',
                (payslip['total_deductions'] as num).toDouble(), Colors.red,
                bold: true),
            const SizedBox(height: 16),

            // Net Pay
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.green.shade600,
                  Colors.green.shade400
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NET PAY',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  Text(
                      '₹${NumberFormat('#,##,###').format((payslip['net_pay'] as num).toInt())}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Employer cost
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employer Contributions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  _amountRow('Employer PF',
                      (payslip['employer_pf'] as num).toDouble(), Colors.blue),
                  _amountRow('Employer ESI',
                      (payslip['employer_esi'] as num).toDouble(), Colors.blue),
                  _amountRow(
                      'Gratuity',
                      (payslip['gratuity_provision'] as num).toDouble(),
                      Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _attStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _amountRow(String label, double amount, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${NumberFormat('#,##,###').format(amount.round())}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Colors.grey.shade300),
    );
  }

  void _printPayslip(BuildContext context) {
    // Will be implemented with PDF package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export coming soon!')),
    );
  }
}
