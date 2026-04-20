import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

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
            .select(
                '*, profiles!employee_salary_user_id_fkey(full_name, department)')
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
            return !_salaryRecords.any(
                (s) => s['user_id'] == emp['id'] && s['effective_to'] == null);
          }).map((emp) => _employeeSalaryCard(emp, null)),

          // Employees with salary
          ..._employees.where((emp) {
            return _salaryRecords.any(
                (s) => s['user_id'] == emp['id'] && s['effective_to'] == null);
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
                _miniChip(
                    'Monthly', '₹${NumberFormat('#,##,###').format(ctc / 12)}'),
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
                      'effective_to':
                          DateTime.now().toIso8601String().split('T')[0],
                    }).eq('id', existing['id']);
                  }

                  // Create new salary record
                  await SupabaseService.client.from('employee_salary').insert({
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
    final pfBase = pfCapped ? (basic > 15000 ? 15000.0 : basic) : basic;
    final empPF = isPF ? pfBase * 0.12 : 0.0;
    final erPF = isPF ? pfBase * 0.12 : 0.0;
    final gratuity = basic * 0.0481;
    final gross = monthly - erPF - gratuity;
    final esiEmp = isESI ? gross * 0.0075 : 0.0;
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
          if (isPF)
            _breakdownRow('- Employee PF', empPF.toDouble(), isDeduction: true),
          if (isESI)
            _breakdownRow('- Employee ESI', esiEmp.toDouble(),
                isDeduction: true),
          const Divider(height: 8),
          _breakdownRow('≈ Net Pay', netApprox,
              bold: true, color: Colors.green),
          const Divider(height: 8),
          _breakdownRow('Employer PF', erPF.toDouble(), color: Colors.blue),
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
  // ═══════════════════════════════════════════
  // PROCESS PAYROLL TAB
  // ═══════════════════════════════════════════
  Widget _processPayrollTab() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final existingRun = _payrollRuns
        .where((r) =>
            int.tryParse(r['month'].toString()) == currentMonth &&
            int.tryParse(r['year'].toString()) == currentYear &&
            r['status'] != 'deleted')
        .toList();

    final activeRun = existingRun.isNotEmpty ? existingRun.first : null;
    final status = activeRun?['status'] ?? 'none';
    final employeesWithSalary =
        _salaryRecords.where((s) => s['effective_to'] == null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Current month header
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
                Text('$employeesWithSalary employees with salary setup',
                    style: const TextStyle(color: Colors.white70)),
                if (activeRun != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Status: ${status.toString().toUpperCase()}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status-based actions
          if (status == 'none') ...[
            // No payroll run yet — show Process button
            _actionCard(
              icon: Icons.play_arrow_rounded,
              title: 'Process Payroll',
              subtitle:
                  'Generate draft payslips for $employeesWithSalary employees based on attendance, leaves & deductions.',
              buttonText: 'Generate Draft',
              buttonColor: AppColors.primary,
              onPressed: employeesWithSalary > 0
                  ? () => _processPayroll('draft')
                  : null,
            ),
            if (employeesWithSalary == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Set up salary for employees in the Salary Setup tab first.',
                    style:
                        TextStyle(color: Colors.orange.shade700, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
          ] else if (status == 'draft') ...[
            // Draft — can review, reprocess, or finalize
            _actionCard(
              icon: Icons.edit_note,
              title: 'Draft Ready',
              subtitle:
                  'Review payslips in Payroll History tab. You can reprocess or finalize.',
              buttonText: 'View Payslips',
              buttonColor: Colors.blue,
              onPressed: () {
                _tabs.animateTo(2);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reprocessPayroll(activeRun!['id']),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reprocess'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _finalizePayroll(activeRun!['id']),
                    icon: const Icon(Icons.lock, size: 18),
                    label: const Text('Finalize'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'finalized') ...[
            // Finalized — can unlock or mark all paid
            _actionCard(
              icon: Icons.lock,
              title: 'Payroll Finalized',
              subtitle:
                  'Payslips are locked. Mark as paid after bank transfer or unlock to make changes.',
              buttonText: 'View Payslips',
              buttonColor: Colors.green,
              onPressed: () {
                _tabs.animateTo(2);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _unlockPayroll(activeRun!['id']),
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Unlock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _markAllPaid(activeRun!['id']),
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text('Mark All Paid'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'completed') ...[
            // Completed/Paid
            _actionCard(
              icon: Icons.check_circle,
              title: 'Payroll Completed',
              subtitle: 'All payslips processed and paid for this month.',
              buttonText: 'View Payslips',
              buttonColor: Colors.green,
              onPressed: () {
                _tabs.animateTo(2);
              },
            ),
          ] else if (status == 'processing') ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Text('Payroll is being processed...',
                style: TextStyle(color: Colors.grey)),
          ],

          const SizedBox(height: 24),

          // Workflow explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payroll Workflow',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                _workflowStep(
                    '1',
                    'Generate Draft',
                    'Auto-calculate from attendance & leaves',
                    status != 'none'),
                _workflowStep('2', 'Review & Adjust',
                    'Check payslips, reprocess if needed', status == 'draft'),
                _workflowStep(
                    '3',
                    'Finalize',
                    'Lock payslips, no auto-changes after this',
                    status == 'finalized'),
                _workflowStep('4', 'Disburse',
                    'Mark as paid after bank transfer', status == 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: buttonColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: buttonColor),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: buttonColor)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: buttonColor),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workflowStep(
      String num, String title, String subtitle, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isActive
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(num,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isActive ? Colors.green : Colors.grey.shade700)),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Future<void> _processPayroll(String targetStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Process Payroll?'),
        content: Text(
            'This will generate draft payslips for ${_salaryRecords.where((s) => s['effective_to'] == null).length} employees for ${DateFormat('MMMM yyyy').format(DateTime.now())}.\n\nAttendance, leaves, late marks, and all deductions will be calculated.'),
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

      // Create payroll run
      final runResult = await SupabaseService.client
          .from('payroll_runs')
          .insert({
            'month': month,
            'year': year,
            'status': targetStatus,
            'processed_by': SupabaseService.userId,
          })
          .select()
          .single();

      final runId = runResult['id'];

      final activeSalaries =
          _salaryRecords.where((s) => s['effective_to'] == null).toList();

      double totalGross = 0;
      double totalDeductions = 0;
      double totalNet = 0;
      double totalEmployerCost = 0;

      // Settings
      final basicPct = 40.0;
      final hraPct = 50.0;
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
      final holidayDates =
          (holidays as List).map((h) => h['date'].toString()).toSet();

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
        } else if (holidayDates.contains(d.toIso8601String().split('T')[0])) {
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

        final monthlyCTC = annualCTC / 12;

        // ── Full-month components (before pro-rating) ──
        final fullBasic = annualCTC * basicPct / 100 / 12;
        final fullHRA = fullBasic * hraPct / 100;
        final fullPfBase = isPF
            ? (pfCapped && fullBasic > pfCeiling ? pfCeiling : fullBasic)
            : 0.0;
        final fullErPF = isPF ? fullPfBase * pfErPct / 100 : 0.0;
        final fullGratuity = fullBasic * gratuityPct / 100;
        final fullGrossBase = monthlyCTC - fullErPF - fullGratuity;
        final fullSA = fullGrossBase - fullBasic - fullHRA;

        // ── Attendance ──
        final attendance = await SupabaseService.client
            .from('attendance')
            .select(
                'check_in_time, check_out_time, is_late, attendance_type, work_hours')
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
          if (type == 'half_day' ||
              (hours >= halfDayHours && hours < fullDayHours)) {
            daysHalfDay++;
            daysPresent += 0.5;
          } else if (hours >= fullDayHours || type == 'full_day') {
            daysPresent += 1;
          }
          if (a['is_late'] == true) lateCount++;
          otHours += (a['overtime_hours'] as num?)?.toDouble() ?? 0;
        }

        // ── Leaves ──
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

        // ── Pro-ration: paid days / working days ──
        final paidDays = daysPresent + paidLeaveDays;
        final absentDays = workingDays - paidDays - lwpDays;
        final totalUnpaidDays = lwpDays + (absentDays > 0 ? absentDays : 0.0);
        final effectivePaidDays =
            (workingDays - totalUnpaidDays).clamp(0.0, workingDays.toDouble());
        final payRatio =
            workingDays > 0 ? effectivePaidDays / workingDays : 0.0;

        // Late penalty (e.g., 3 lates = 1 day salary deduction)
        final latePenaltyDays = lateCount ~/ latePenaltyCount;
        final latePenaltyRatio =
            workingDays > 0 ? latePenaltyDays / workingDays : 0.0;

        // Final pay ratio after late penalty
        final finalPayRatio = (payRatio - latePenaltyRatio).clamp(0.0, 1.0);

        // ── Pro-rated earnings ──
        final basic = fullBasic * finalPayRatio;
        final hra = fullHRA * finalPayRatio;
        final sa = (fullSA > 0 ? fullSA : 0.0) * finalPayRatio;
        final grossEarnings = basic + hra + sa;

        // ── Statutory deductions on PRO-RATED amounts ──
        final proPfBase =
            isPF ? (pfCapped && basic > pfCeiling ? pfCeiling : basic) : 0.0;
        final empPF = isPF ? proPfBase * pfEmpPct / 100 : 0.0;
        final erPF = isPF ? proPfBase * pfErPct / 100 : 0.0;
        final esiEmp = isESI && grossEarnings <= 21000
            ? grossEarnings * esiEmpPct / 100
            : 0.0;
        final esiEr = isESI && grossEarnings <= 21000
            ? grossEarnings * esiErPct / 100
            : 0.0;
        final gratuity = basic * gratuityPct / 100;

        // Professional Tax (monthly slab — but ₹0 if no earnings)
        double ptAmount = 0;
        if (grossEarnings > 0) {
          for (final slab in ptSlabs as List) {
            final from = (slab['monthly_salary_from'] as num).toDouble();
            final to = (slab['monthly_salary_to'] as num).toDouble();
            if (fullGrossBase >= from && fullGrossBase <= to) {
              ptAmount = (slab['tax_amount'] as num).toDouble();
              break;
            }
          }
        }

        // ── Loan EMI deduction ──
        double loanEmi = 0;
        try {
          final activeLoans = await SupabaseService.client
              .from('employee_loans')
              .select(
                  'id, emi_amount, balance, installments_paid, total_installments')
              .eq('user_id', userId)
              .eq('status', 'active');

          for (final loan in activeLoans as List) {
            final emiAmt = (loan['emi_amount'] as num?)?.toDouble() ?? 0;
            final bal = (loan['balance'] as num?)?.toDouble() ?? 0;
            if (emiAmt > 0 && bal > 0) {
              final deduct =
                  emiAmt > bal ? bal : emiAmt; // Don't deduct more than balance
              loanEmi += deduct;

              // Update loan: reduce balance, increment installments
              final newBalance = bal - deduct;
              final newPaid =
                  ((loan['installments_paid'] as num?)?.toInt() ?? 0) + 1;
              final totalInst =
                  (loan['total_installments'] as num?)?.toInt() ?? 0;

              await SupabaseService.client.from('employee_loans').update({
                'balance': newBalance,
                'installments_paid': newPaid,
                'status': newBalance <= 0 ? 'completed' : 'active',
              }).eq('id', loan['id']);

              // Record repayment
              await SupabaseService.client.from('loan_repayments').insert({
                'loan_id': loan['id'],
                'amount': deduct,
                'repayment_date':
                    DateTime.now().toIso8601String().split('T')[0],
              });
            }
          }
        } catch (e) {
          debugPrint('Loan EMI error: $e');
        }

        final totalDeductionsAmt = empPF + esiEmp + ptAmount + loanEmi;
        final netPay = grossEarnings - totalDeductionsAmt;
        final employerCost = grossEarnings + erPF + esiEr + gratuity;

        // ── Earnings breakdown (pro-rated, clean) ──
        final earnings = [
          {'code': 'BASIC', 'name': 'Basic Salary', 'amount': _round(basic)},
          {'code': 'HRA', 'name': 'HRA', 'amount': _round(hra)},
          {'code': 'SA', 'name': 'Special Allowance', 'amount': _round(sa)},
        ];

        // ── Deductions breakdown (only actual statutory deductions) ──
        final deductions = <Map<String, dynamic>>[];
        if (isPF && empPF > 0) {
          deductions.add({
            'code': 'EPF_EE',
            'name': 'Employee PF',
            'amount': _round(empPF)
          });
        }
        if (isESI && esiEmp > 0) {
          deductions.add({
            'code': 'ESI_EE',
            'name': 'Employee ESI',
            'amount': _round(esiEmp)
          });
        }
        if (ptAmount > 0) {
          deductions.add({
            'code': 'PT',
            'name': 'Professional Tax',
            'amount': _round(ptAmount)
          });
        }
        if (loanEmi > 0) {
          deductions.add({
            'code': 'LOAN_EMI',
            'name': 'Loan/Advance EMI',
            'amount': _round(loanEmi),
          });
        }

        // ── Insert payslip ──
        await SupabaseService.client.from('payslips').insert({
          'payroll_run_id': runId,
          'user_id': userId,
          'month': month,
          'year': year,
          'total_working_days': workingDays,
          'days_present': daysPresent,
          'days_absent': absentDays > 0 ? absentDays : 0,
          'days_half_day': daysHalfDay,
          'days_leave': paidLeaveDays,
          'days_lwp': totalUnpaidDays,
          'days_holiday': holidayCount,
          'days_weekoff': weekoffDays,
          'late_count': lateCount,
          'overtime_hours': otHours,
          'annual_ctc': _round(annualCTC),
          'monthly_ctc': _round(monthlyCTC),
          'gross_earnings': _round(grossEarnings > 0 ? grossEarnings : 0),
          'total_deductions': _round(totalDeductionsAmt),
          'net_pay': _round(netPay > 0 ? netPay : 0),
          'employer_pf': _round(erPF),
          'employer_esi': _round(esiEr),
          'gratuity_provision': _round(gratuity),
          'total_employer_cost': _round(employerCost > 0 ? employerCost : 0),
          'earnings_breakdown': earnings,
          'deductions_breakdown': deductions,
          'payment_status': 'unpaid',
        });

        totalGross += grossEarnings > 0 ? grossEarnings : 0;
        totalDeductions += totalDeductionsAmt;
        totalNet += netPay > 0 ? netPay : 0;
        totalEmployerCost += employerCost > 0 ? employerCost : 0;
      }

      await SupabaseService.client.from('payroll_runs').update({
        'status': targetStatus,
        'total_employees': activeSalaries.length,
        'total_gross': _round(totalGross),
        'total_deductions': _round(totalDeductions),
        'total_net_pay': _round(totalNet),
        'total_employer_cost': _round(totalEmployerCost),
        'processed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', runId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Payroll processed for ${activeSalaries.length} employees!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      debugPrint('Payroll error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Payroll error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reprocessPayroll(String runId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reprocess Payroll?'),
        content: const Text(
            'This will delete all current draft payslips and regenerate them from the latest attendance & leave data.\n\nAny manual adjustments will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reprocess'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Delete existing payslips for this run
      await SupabaseService.client
          .from('payslips')
          .delete()
          .eq('payroll_run_id', runId);

      // Mark old run as deleted
      await SupabaseService.client
          .from('payroll_runs')
          .update({'status': 'deleted'}).eq('id', runId);

      // Process fresh
      await _processPayroll('draft');
    } catch (e) {
      debugPrint('Reprocess error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizePayroll(String runId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Payroll?'),
        content: const Text(
            'Once finalized, payslips will be locked. Attendance changes won\'t affect them.\n\nYou can still unlock later if needed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client.from('payroll_runs').update({
        'status': 'finalized',
        'locked_at': DateTime.now().toUtc().toIso8601String(),
        'locked_by': SupabaseService.userId,
      }).eq('id', runId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payroll finalized!'), backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _unlockPayroll(String runId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock Payroll?'),
        content: const Text(
            'This will move payroll back to draft status. You can then reprocess or make changes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client.from('payroll_runs').update({
        'status': 'draft',
        'locked_at': null,
        'locked_by': null,
      }).eq('id', runId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payroll unlocked — now in draft'),
            backgroundColor: Colors.orange),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _markAllPaid(String runId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark All Paid?'),
        content: const Text(
            'This confirms that salary has been transferred to all employees. This is the final step.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Paid'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      await SupabaseService.client.from('payslips').update({
        'payment_status': 'paid',
        'payment_date': today,
      }).eq('payroll_run_id', runId);

      await SupabaseService.client.from('payroll_runs').update({
        'status': 'completed',
      }).eq('id', runId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All payslips marked as paid!'),
            backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════
  // PAYROLL HISTORY TAB
  // ═══════════════════════════════════════════
  Widget _payrollHistoryTab() {
    final activeRuns =
        _payrollRuns.where((r) => r['status'] != 'deleted').toList();
    if (activeRuns.isEmpty) {
      return const Center(
          child: Text('No payroll runs yet',
              style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activeRuns.length,
        itemBuilder: (context, index) {
          final run = activeRuns[index];
          final runYear = int.tryParse(run['year'].toString()) ?? run['year'];
          final runMonth =
              int.tryParse(run['month'].toString()) ?? run['month'];
          final monthDate = DateTime(runYear, runMonth);
          final runStatus = run['status'] ?? 'draft';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: runStatus == 'completed'
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        runStatus == 'completed'
                            ? Icons.check_circle
                            : Icons.pending,
                        color: runStatus == 'completed'
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
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
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
  const _PayslipListScreen({required this.payrollRunId, required this.run});

  @override
  State<_PayslipListScreen> createState() => _PayslipListScreenState();
}

class _PayslipListScreenState extends State<_PayslipListScreen> {
  List<Map<String, dynamic>> _payslips = [];
  bool _isLoading = true;
  bool _isBulkProcessing = false;
  Map<String, String> _companySettings = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('payslips')
            .select(
                '*, profiles!payslips_user_id_fkey(full_name, department, designation, employee_id, pan_number, uan_number, email, phone)')
            .eq('payroll_run_id', widget.payrollRunId)
            .order('net_pay', ascending: false),
        SupabaseService.client
            .from('company_settings')
            .select('setting_key, setting_value')
            .inFilter('setting_key', [
          'company_name',
          'company_address',
          'company_logo_url',
          'company_pan',
          'company_tan',
          'brand_color',
          'payslip_footer_text',
        ]),
      ]);

      _payslips = List<Map<String, dynamic>>.from(results[0] as List);

      _companySettings = {};
      for (final s in results[1] as List) {
        _companySettings[s['setting_key']] =
            (s['setting_value'] ?? '').toString().replaceAll('"', '');
      }
    } catch (e) {
      debugPrint('Payslip load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Generate PDF for a single payslip ──
  Future<Uint8List> _generatePayslipPdf(
      Map<String, dynamic> payslip, Map<String, dynamic> profile) async {
    final pdf = pw.Document();
    final monthDate = DateTime(payslip['year'], payslip['month']);
    final earnings =
        List<Map<String, dynamic>>.from(payslip['earnings_breakdown'] ?? []);
    final deductions =
        List<Map<String, dynamic>>.from(payslip['deductions_breakdown'] ?? []);

    final grossEarnings = (payslip['gross_earnings'] as num).toDouble();
    final totalDeductions = (payslip['total_deductions'] as num).toDouble();
    final netPay = (payslip['net_pay'] as num).toDouble();
    final employerPF = (payslip['employer_pf'] as num).toDouble();
    final employerESI = (payslip['employer_esi'] as num).toDouble();
    final gratuity = (payslip['gratuity_provision'] as num).toDouble();
    final monthlyCTC = (payslip['monthly_ctc'] as num).toDouble();
    final annualCTC = (payslip['annual_ctc'] as num).toDouble();
    final fmt = NumberFormat('#,##,###.##');

    final companyName = _companySettings['company_name'] ?? 'Vartmaan Pulse';
    final companyAddress = _companySettings['company_address'] ?? '';
    final companyPAN = _companySettings['company_pan'] ?? '';
    final companyTAN = _companySettings['company_tan'] ?? '';
    final brandHex = _companySettings['brand_color'] ?? '#006A61';
    final footerText = _companySettings['payslip_footer_text'] ??
        'This is a system-generated payslip and does not require a signature.';
    final brandColor = PdfColor.fromHex(brandHex);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: brandColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName.toUpperCase(),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('PAYSLIP',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 12)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(DateFormat('MMMM yyyy').format(monthDate),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('CONFIDENTIAL',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Employee Details
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfRow('Employee Name', profile['full_name'] ?? ''),
                      _pdfRow('Employee ID', profile['employee_id'] ?? '-'),
                      _pdfRow('Department', profile['department'] ?? '-'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfRow('Designation', profile['designation'] ?? '-'),
                      _pdfRow('PAN', profile['pan_number'] ?? '-'),
                      _pdfRow('UAN', profile['uan_number'] ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // CTC
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E0F2F1'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Annual CTC: ₹${fmt.format(annualCTC)}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Monthly CTC: ₹${fmt.format(monthlyCTC)}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Attendance
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat('Working', '${payslip['total_working_days']}'),
                _pdfStat('Present', '${payslip['days_present']}'),
                _pdfStat('Paid Leave', '${payslip['days_leave']}'),
                _pdfStat('LWP', '${payslip['days_lwp']}'),
                _pdfStat('Late', '${payslip['late_count']}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Earnings & Deductions
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EARNINGS',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: brandColor)),
                      pw.Divider(),
                      ...earnings.map((e) => _pdfAmount(e['name'] ?? e['code'],
                          (e['amount'] as num).toDouble(), fmt)),
                      pw.Divider(thickness: 1.5),
                      _pdfAmount('Gross Earnings', grossEarnings, fmt,
                          bold: true),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DEDUCTIONS',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red)),
                      pw.Divider(),
                      if (deductions.isEmpty)
                        pw.Text('No deductions',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey)),
                      ...deductions.map((d) => _pdfAmount(
                          d['name'] ?? d['code'],
                          (d['amount'] as num).toDouble(),
                          fmt)),
                      pw.Divider(thickness: 1.5),
                      _pdfAmount('Total Deductions', totalDeductions, fmt,
                          bold: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Net Pay
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: brandColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NET PAY',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('₹${fmt.format(netPay)}',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Employer
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E3F2FD'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EMPLOYER CONTRIBUTIONS (from CTC)',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800)),
                pw.SizedBox(height: 6),
                _pdfAmount('Employer PF', employerPF, fmt),
                _pdfAmount('Employer ESI', employerESI, fmt),
                _pdfAmount('Gratuity Provision', gratuity, fmt),
                pw.Divider(),
                _pdfAmount('Total Employer Cost',
                    grossEarnings + employerPF + employerESI + gratuity, fmt,
                    bold: true),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              children: [
                if (companyAddress.isNotEmpty)
                  pw.Text(companyAddress,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                if (companyPAN.isNotEmpty || companyTAN.isNotEmpty)
                  pw.Text(
                      '${companyPAN.isNotEmpty ? "PAN: $companyPAN" : ""}${companyPAN.isNotEmpty && companyTAN.isNotEmpty ? " | " : ""}${companyTAN.isNotEmpty ? "TAN: $companyTAN" : ""}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(footerText,
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── PDF helper widgets ──
  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Text('$label: ',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  pw.Widget _pdfStat(String label, String value) {
    return pw.Column(children: [
      pw.Text(value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ]);
  }

  pw.Widget _pdfAmount(String label, double amount, NumberFormat fmt,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('₹${fmt.format(amount)}',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // ── Download single payslip ──
  Future<void> _downloadPayslip(
      Map<String, dynamic> ps, Map<String, dynamic> profile) async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Generating PDF...')));

      final bytes = await _generatePayslipPdf(ps, profile);
      final monthDate = DateTime(ps['year'], ps['month']);
      final fileName =
          'Payslip_${profile['full_name']?.replaceAll(' ', '_')}_${DateFormat('MMM_yyyy').format(monthDate)}.pdf';

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved to ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () {
              Share.shareXFiles([XFile(file.path)],
                  text: 'Payslip - $fileName');
            },
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Email single payslip ──
  Future<void> _emailPayslip(
      Map<String, dynamic> ps, Map<String, dynamic> profile) async {
    try {
      final bytes = await _generatePayslipPdf(ps, profile);
      final monthDate = DateTime(ps['year'], ps['month']);
      final fileName =
          'Payslip_${profile['full_name']?.replaceAll(' ', '_')}_${DateFormat('MMM_yyyy').format(monthDate)}.pdf';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final monthStr = DateFormat('MMMM yyyy').format(monthDate);
      final companyName = _companySettings['company_name'] ?? 'Vartmaan Pulse';

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Payslip — $monthStr | $companyName',
        text:
            'Dear ${profile['full_name']},\n\nPlease find attached your payslip for $monthStr.\n\nNet Pay: ₹${NumberFormat('#,##,###').format((ps['net_pay'] as num).toInt())}\n\nRegards,\n$companyName HR',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Bulk PDF — all payslips in one PDF ──
  Future<void> _bulkGeneratePdf() async {
    if (_payslips.isEmpty) return;

    setState(() => _isBulkProcessing = true);
    try {
      final pdf = pw.Document();
      final monthDate = DateTime(widget.run['year'], widget.run['month']);

      for (final ps in _payslips) {
        final profile = ps['profiles'] as Map<String, dynamic>? ?? {};
        final singlePdfBytes = await _generatePayslipPdf(ps, profile);
        final singleDoc = pw.Document();

        // We need to generate each page directly into the bulk doc
        // So let's build pages inline
      }

      // Better approach: generate individual PDFs and merge
      final dir = await getTemporaryDirectory();
      final bulkDir = Directory('${dir.path}/payslips_bulk');
      if (await bulkDir.exists()) await bulkDir.delete(recursive: true);
      await bulkDir.create();

      final files = <XFile>[];
      int count = 0;

      for (final ps in _payslips) {
        final profile = ps['profiles'] as Map<String, dynamic>? ?? {};
        final bytes = await _generatePayslipPdf(ps, profile);
        final fileName =
            'Payslip_${profile['full_name']?.replaceAll(' ', '_') ?? 'Unknown'}_${DateFormat('MMM_yyyy').format(monthDate)}.pdf';
        final file = File('${bulkDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        files.add(XFile(file.path));
        count++;
      }

      // Also save a combined PDF
      final combinedPdf = pw.Document();
      for (final ps in _payslips) {
        final profile = ps['profiles'] as Map<String, dynamic>? ?? {};
        final earnings =
            List<Map<String, dynamic>>.from(ps['earnings_breakdown'] ?? []);
        final deductions =
            List<Map<String, dynamic>>.from(ps['deductions_breakdown'] ?? []);
        final fmt = NumberFormat('#,##,###.##');
        final companyName =
            _companySettings['company_name'] ?? 'Vartmaan Pulse';
        final brandHex = _companySettings['brand_color'] ?? '#006A61';
        final brandColor = PdfColor.fromHex(brandHex);

        combinedPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: brandColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(companyName.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('MMMM yyyy').format(monthDate),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(children: [
                  pw.Text('Name: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(profile['full_name'] ?? '',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 20),
                  pw.Text('ID: ${profile['employee_id'] ?? '-'}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 20),
                  pw.Text('Dept: ${profile['department'] ?? '-'}',
                      style: const pw.TextStyle(fontSize: 10)),
                ]),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfStat('Working', '${ps['total_working_days']}'),
                    _pdfStat('Present', '${ps['days_present']}'),
                    _pdfStat('Leave', '${ps['days_leave']}'),
                    _pdfStat('LWP', '${ps['days_lwp']}'),
                    _pdfStat('Late', '${ps['late_count']}'),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _tableCell('Earnings', bold: true),
                        _tableCell('Amount', bold: true),
                        _tableCell('Deductions', bold: true),
                        _tableCell('Amount', bold: true),
                      ],
                    ),
                    ...List.generate(
                      earnings.length > deductions.length
                          ? earnings.length
                          : deductions.length,
                      (i) => pw.TableRow(children: [
                        _tableCell(i < earnings.length
                            ? earnings[i]['name'] ?? ''
                            : ''),
                        _tableCell(i < earnings.length
                            ? '₹${fmt.format((earnings[i]['amount'] as num).toDouble())}'
                            : ''),
                        _tableCell(i < deductions.length
                            ? deductions[i]['name'] ?? ''
                            : ''),
                        _tableCell(i < deductions.length
                            ? '₹${fmt.format((deductions[i]['amount'] as num).toDouble())}'
                            : ''),
                      ]),
                    ),
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _tableCell('Gross', bold: true),
                        _tableCell(
                            '₹${fmt.format((ps['gross_earnings'] as num).toDouble())}',
                            bold: true),
                        _tableCell('Total Ded.', bold: true),
                        _tableCell(
                            '₹${fmt.format((ps['total_deductions'] as num).toDouble())}',
                            bold: true),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: brandColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET PAY',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '₹${fmt.format((ps['net_pay'] as num).toDouble())}',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final combinedFileName =
          'All_Payslips_${DateFormat('MMM_yyyy').format(monthDate)}.pdf';
      final combinedFile = File('${bulkDir.path}/$combinedFileName');
      await combinedFile.writeAsBytes(await combinedPdf.save());

      if (mounted) {
        setState(() => _isBulkProcessing = false);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Payslips Generated!'),
            content: Text(
                '$count individual PDFs + 1 combined PDF created.\n\nChoose an action:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles(
                    [XFile(combinedFile.path)],
                    subject:
                        'All Payslips — ${DateFormat('MMMM yyyy').format(monthDate)}',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Share Combined'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles(
                    files,
                    subject:
                        'Individual Payslips — ${DateFormat('MMMM yyyy').format(monthDate)}',
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share All'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Bulk PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBulkProcessing = false);
    }
  }

  // ── Email all payslips ──
  Future<void> _emailAllPayslips() async {
    if (_payslips.isEmpty) return;

    setState(() => _isBulkProcessing = true);
    try {
      final monthDate = DateTime(widget.run['year'], widget.run['month']);
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];

      for (final ps in _payslips) {
        final profile = ps['profiles'] as Map<String, dynamic>? ?? {};
        final bytes = await _generatePayslipPdf(ps, profile);
        final fileName =
            'Payslip_${profile['full_name']?.replaceAll(' ', '_') ?? 'Unknown'}_${DateFormat('MMM_yyyy').format(monthDate)}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        files.add(XFile(file.path));
      }

      final companyName = _companySettings['company_name'] ?? 'Vartmaan Pulse';
      final monthStr = DateFormat('MMMM yyyy').format(monthDate);

      await Share.shareXFiles(
        files,
        subject: 'Payslips — $monthStr | $companyName',
        text:
            'Please find attached the payslips for $monthStr.\n\nRegards,\n$companyName HR',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBulkProcessing = false);
    }
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthDate = DateTime(widget.run['year'], widget.run['month']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payslips — ${DateFormat('MMM yyyy').format(monthDate)}'),
        actions: [
          if (_isBulkProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case 'bulk_pdf':
                    _bulkGeneratePdf();
                    break;
                  case 'email_all':
                    _emailAllPayslips();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'bulk_pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text('Bulk PDF (All)'),
                    subtitle: Text('Generate & share all payslips',
                        style: TextStyle(fontSize: 11)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'email_all',
                  child: ListTile(
                    leading: Icon(Icons.email, color: Colors.blue),
                    title: Text('Email All Payslips'),
                    subtitle: Text('Share via email/WhatsApp',
                        style: TextStyle(fontSize: 11)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _payslips.length,
              itemBuilder: (context, index) {
                final ps = _payslips[index];
                final profile = ps['profiles'] as Map<String, dynamic>? ?? {};

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
                          _payslipStat('Gross',
                              '₹${NumberFormat('#,##,###').format((ps['gross_earnings'] as num).toInt())}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _viewPayslipDetail(ps, profile),
                              child: const Text('View'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _downloadPayslip(ps, profile),
                            icon: const Icon(Icons.download,
                                size: 20, color: Colors.blue),
                            tooltip: 'Download PDF',
                          ),
                          IconButton(
                            onPressed: () => _emailPayslip(ps, profile),
                            icon: const Icon(Icons.email,
                                size: 20, color: Colors.orange),
                            tooltip: 'Email / Share',
                          ),
                          const SizedBox(width: 4),
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
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
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
    final monthDate = DateTime(payslip['year'], payslip['month']);
    final earnings =
        List<Map<String, dynamic>>.from(payslip['earnings_breakdown'] ?? []);
    final deductions =
        List<Map<String, dynamic>>.from(payslip['deductions_breakdown'] ?? []);

    final grossEarnings = (payslip['gross_earnings'] as num).toDouble();
    final totalDeductions = (payslip['total_deductions'] as num).toDouble();
    final netPay = (payslip['net_pay'] as num).toDouble();
    final employerPF = (payslip['employer_pf'] as num).toDouble();
    final employerESI = (payslip['employer_esi'] as num).toDouble();
    final gratuity = (payslip['gratuity_provision'] as num).toDouble();
    final totalEmployerCost =
        (payslip['total_employer_cost'] as num).toDouble();
    final monthlyCTC = (payslip['monthly_ctc'] as num).toDouble();
    final annualCTC = (payslip['annual_ctc'] as num).toDouble();

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
                  _infoRow(
                      'Pay Period', DateFormat('MMMM yyyy').format(monthDate)),
                  _infoRow('CTC',
                      '₹${NumberFormat('#,##,###').format(annualCTC.toInt())}/yr'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CTC Breakdown — shows how CTC splits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CTC Breakdown (Monthly)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF006A61))),
                  const SizedBox(height: 4),
                  Text(
                      'Shows how your monthly CTC of ₹${NumberFormat('#,##,###').format(monthlyCTC.toInt())} is allocated',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  _ctcRow('Monthly CTC', monthlyCTC, Colors.black, bold: true),
                  const Divider(height: 16),
                  _ctcRow(
                      '→ Employer PF (inside CTC)', employerPF, Colors.orange),
                  _ctcRow('→ Gratuity (inside CTC)', gratuity, Colors.orange),
                  _ctcRow('→ Employer ESI (inside CTC)', employerESI,
                      Colors.orange),
                  const Divider(height: 16),
                  _ctcRow(
                      'Gross Salary (CTC − above)',
                      monthlyCTC - employerPF - gratuity - employerESI,
                      Colors.green,
                      bold: true),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Employer PF & Gratuity are part of your CTC. They are set aside before calculating your gross salary.',
                            style: TextStyle(
                                fontSize: 10, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
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

            // Earnings (pro-rated)
            _sectionTitle('Earnings (Pro-rated for paid days)'),
            ...earnings.map((e) => _amountRow(e['name'] ?? e['code'],
                (e['amount'] as num).toDouble(), Colors.black87)),
            _divider(),
            _amountRow('Gross Earnings', grossEarnings, Colors.green,
                bold: true),
            const SizedBox(height: 16),

            // Deductions
            _sectionTitle('Employee Deductions'),
            if (deductions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No deductions',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic)),
              )
            else
              ...deductions.map((d) => _amountRow(d['name'] ?? d['code'],
                  (d['amount'] as num).toDouble(), Colors.red)),
            _divider(),
            _amountRow('Total Deductions', totalDeductions, Colors.red,
                bold: true),
            const SizedBox(height: 16),

            // Net Pay
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade400]),
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
                  Text('₹${NumberFormat('#,##,###').format(netPay.round())}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Employer Contributions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employer Contributions (from CTC)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text('These amounts are paid by the company from your CTC',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  _amountRow('Employer PF', employerPF, Colors.blue),
                  _amountRow('Employer ESI', employerESI, Colors.blue),
                  _amountRow('Gratuity Provision', gratuity, Colors.blue),
                  _divider(),
                  _amountRow(
                      'Total Employer Cost', totalEmployerCost, Colors.blue,
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _summaryRow('Monthly CTC',
                      '₹${NumberFormat('#,##,###').format(monthlyCTC.toInt())}'),
                  _summaryRow('Employee Gets (Net Pay)',
                      '₹${NumberFormat('#,##,###').format(netPay.round())}'),
                  _summaryRow('Employer Contributions',
                      '₹${NumberFormat('#,##,###').format((employerPF + employerESI + gratuity).round())}'),
                  _summaryRow('Employee PF + Deductions',
                      '₹${NumberFormat('#,##,###').format(totalDeductions.round())}'),
                  const Divider(height: 16),
                  _summaryRow('Total Cost to Company',
                      '₹${NumberFormat('#,##,###').format(totalEmployerCost.round())}',
                      bold: true),
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
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          Text('₹${NumberFormat('#,##,###').format(amount.round())}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Widget _ctcRow(String label, double amount, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: color)),
          ),
          Text('₹${NumberFormat('#,##,###').format(amount.round())}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
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

  void _printPayslip(BuildContext context) async {
    // Fetch company branding settings
    final settingsResult = await SupabaseService.client
        .from('company_settings')
        .select('setting_key, setting_value')
        .inFilter('setting_key', [
      'company_name',
      'company_address',
      'company_logo_url',
      'company_pan',
      'company_tan',
      'brand_color',
      'payslip_footer_text',
    ]);

    final settings = <String, String>{};
    for (final s in settingsResult as List) {
      settings[s['setting_key']] =
          (s['setting_value'] ?? '').toString().replaceAll('"', '');
    }

    final companyName = settings['company_name'] ?? 'Vartmaan Pulse';
    final companyAddress = settings['company_address'] ?? '';
    final companyPAN = settings['company_pan'] ?? '';
    final companyTAN = settings['company_tan'] ?? '';
    final brandHex = settings['brand_color'] ?? '#006A61';
    final footerText = settings['payslip_footer_text'] ??
        'This is a system-generated payslip and does not require a signature.';
    final logoUrl = settings['company_logo_url'] ?? '';

    final brandColor = PdfColor.fromHex(brandHex);

    // Try to load logo
    pw.MemoryImage? logoImage;
    if (logoUrl.isNotEmpty) {
      try {
        final response = await NetworkAssetBundle(Uri.parse(logoUrl)).load('');
        logoImage = pw.MemoryImage(response.buffer.asUint8List());
      } catch (_) {}
    }

    final pdf = pw.Document();

    final monthDate = DateTime(payslip['year'], payslip['month']);
    final earnings =
        List<Map<String, dynamic>>.from(payslip['earnings_breakdown'] ?? []);
    final deductions =
        List<Map<String, dynamic>>.from(payslip['deductions_breakdown'] ?? []);

    final grossEarnings = (payslip['gross_earnings'] as num).toDouble();
    final totalDeductions = (payslip['total_deductions'] as num).toDouble();
    final netPay = (payslip['net_pay'] as num).toDouble();
    final employerPF = (payslip['employer_pf'] as num).toDouble();
    final employerESI = (payslip['employer_esi'] as num).toDouble();
    final gratuity = (payslip['gratuity_provision'] as num).toDouble();
    final monthlyCTC = (payslip['monthly_ctc'] as num).toDouble();
    final annualCTC = (payslip['annual_ctc'] as num).toDouble();
    final fmt = NumberFormat('#,##,###.##');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          // Header
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: brandColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 36,
                        height: 36,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Image(logoImage, width: 32, height: 32),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(companyName.toUpperCase(),
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('PAYSLIP',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(DateFormat('MMMM yyyy').format(monthDate),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('CONFIDENTIAL',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // Employee Details
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfInfoRow('Employee Name', profile['full_name'] ?? ''),
                      _pdfInfoRow('Employee ID', profile['employee_id'] ?? '-'),
                      _pdfInfoRow('Department', profile['department'] ?? '-'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfInfoRow('Designation', profile['designation'] ?? '-'),
                      _pdfInfoRow('PAN', profile['pan_number'] ?? '-'),
                      _pdfInfoRow('UAN', profile['uan_number'] ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // CTC Info
          // CTC Info
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E0F2F1'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Annual CTC: ₹${fmt.format(annualCTC)}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Monthly CTC: ₹${fmt.format(monthlyCTC)}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Attendance Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfAttStat('Working Days', '${payslip['total_working_days']}'),
                _pdfAttStat('Present', '${payslip['days_present']}'),
                _pdfAttStat('Paid Leave', '${payslip['days_leave']}'),
                _pdfAttStat('LWP', '${payslip['days_lwp']}'),
                _pdfAttStat('Late', '${payslip['late_count']}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Earnings & Deductions side by side
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Earnings
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EARNINGS',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: brandColor)),
                      pw.Divider(),
                      ...earnings.map((e) => _pdfAmountRow(
                          e['name'] ?? e['code'],
                          (e['amount'] as num).toDouble(),
                          fmt)),
                      pw.Divider(thickness: 1.5),
                      _pdfAmountRow('Gross Earnings', grossEarnings, fmt,
                          bold: true),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              // Deductions
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DEDUCTIONS',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red)),
                      pw.Divider(),
                      if (deductions.isEmpty)
                        pw.Text('No deductions',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey)),
                      ...deductions.map((d) => _pdfAmountRow(
                          d['name'] ?? d['code'],
                          (d['amount'] as num).toDouble(),
                          fmt)),
                      pw.Divider(thickness: 1.5),
                      _pdfAmountRow('Total Deductions', totalDeductions, fmt,
                          bold: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Net Pay
          // Net Pay
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: brandColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NET PAY',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('₹${fmt.format(netPay)}',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Employer Contributions
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E3F2FD'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EMPLOYER CONTRIBUTIONS (from CTC)',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800)),
                pw.SizedBox(height: 6),
                _pdfAmountRow('Employer PF', employerPF, fmt),
                _pdfAmountRow('Employer ESI', employerESI, fmt),
                _pdfAmountRow('Gratuity Provision', gratuity, fmt),
                pw.Divider(),
                _pdfAmountRow('Total Employer Cost',
                    grossEarnings + employerPF + employerESI + gratuity, fmt,
                    bold: true),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Footer
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              children: [
                if (companyAddress.isNotEmpty)
                  pw.Text(companyAddress,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                if (companyPAN.isNotEmpty || companyTAN.isNotEmpty)
                  pw.Text(
                      '${companyPAN.isNotEmpty ? "PAN: $companyPAN" : ""}${companyPAN.isNotEmpty && companyTAN.isNotEmpty ? " | " : ""}${companyTAN.isNotEmpty ? "TAN: $companyTAN" : ""}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(footerText,
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Payslip_${profile['full_name']}_${DateFormat('MMM_yyyy').format(monthDate)}',
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfAttStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _pdfAmountRow(String label, double amount, NumberFormat fmt,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('₹${fmt.format(amount)}',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
