import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';

class AdminLoanScreen extends StatefulWidget {
  const AdminLoanScreen({super.key});

  @override
  State<AdminLoanScreen> createState() => _AdminLoanScreenState();
}

class _AdminLoanScreenState extends State<AdminLoanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _history = [];
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
            .from('employee_loans')
            .select('*, profiles!employee_loans_user_id_fkey(full_name, department, designation)')
            .eq('status', 'pending')
            .order('created_at', ascending: true),
        SupabaseService.client
            .from('employee_loans')
            .select('*, profiles!employee_loans_user_id_fkey(full_name, department, designation)')
            .eq('status', 'active')
            .order('created_at', ascending: false),
        SupabaseService.client
            .from('employee_loans')
            .select('*, profiles!employee_loans_user_id_fkey(full_name, department, designation)')
            .inFilter('status', ['completed', 'rejected'])
            .order('created_at', ascending: false)
            .limit(50),
      ]);

      _pending = List<Map<String, dynamic>>.from(results[0] as List);
      _active = List<Map<String, dynamic>>.from(results[1] as List);
      _history = List<Map<String, dynamic>>.from(results[2] as List);
    } catch (e) {
      debugPrint('Loan load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan & Advance Management'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_pending.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'Active (${_active.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _pendingTab(),
                _activeTab(),
                _historyTab(),
              ],
            ),
    );
  }

  // ── PENDING TAB ──
  Widget _pendingTab() {
    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No pending requests',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pending.length,
      itemBuilder: (context, index) => _loanCard(_pending[index],
          showActions: true),
    );
  }

  // ── ACTIVE TAB ──
  Widget _activeTab() {
    if (_active.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No active loans',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // Summary
    final totalDisbursed = _active.fold<double>(
        0, (sum, l) => sum + ((l['amount'] as num?)?.toDouble() ?? 0));
    final totalBalance = _active.fold<double>(
        0, (sum, l) => sum + ((l['balance'] as num?)?.toDouble() ?? 0));
    final totalEmi = _active.fold<double>(
        0, (sum, l) => sum + ((l['emi_amount'] as num?)?.toDouble() ?? 0));
    final fmt = NumberFormat('#,##,###');

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF006A61), Color(0xFF00897B)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('Total Disbursed', '₹${fmt.format(totalDisbursed)}'),
              _statItem('Outstanding', '₹${fmt.format(totalBalance)}'),
              _statItem('Monthly EMI', '₹${fmt.format(totalEmi)}'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _active.length,
            itemBuilder: (context, index) =>
                _loanCard(_active[index], showProgress: true),
          ),
        ),
      ],
    );
  }

  // ── HISTORY TAB ──
  Widget _historyTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No loan history',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) => _loanCard(_history[index]),
    );
  }

  // ── LOAN CARD ──
  Widget _loanCard(Map<String, dynamic> loan,
      {bool showActions = false, bool showProgress = false}) {
    final profile = loan['profiles'] as Map<String, dynamic>? ?? {};
    final amount = (loan['amount'] as num?)?.toDouble() ?? 0;
    final balance = (loan['balance'] as num?)?.toDouble() ?? 0;
    final emi = (loan['emi_amount'] as num?)?.toDouble() ?? 0;
    final paid = (loan['installments_paid'] as num?)?.toInt() ?? 0;
    final total = (loan['total_installments'] as num?)?.toInt() ?? 0;
    final status = loan['status'] ?? 'pending';
    final type = (loan['type'] ?? 'loan').toString();
    final fmt = NumberFormat('#,##,###');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: type == 'advance'
                      ? Colors.orange.shade100
                      : Colors.blue.shade100,
                  child: Icon(
                    type == 'advance' ? Icons.flash_on : Icons.account_balance,
                    size: 18,
                    color: type == 'advance'
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile['full_name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                          '${profile['designation'] ?? ''} • ${profile['department'] ?? ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${fmt.format(amount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    _statusChip(status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _detailChip('Type', type.toUpperCase()),
                const SizedBox(width: 8),
                if (type != 'advance')
                  _detailChip('EMI', '₹${fmt.format(emi)}'),
                const SizedBox(width: 8),
                if (total > 0) _detailChip('Installments', '$paid/$total'),
              ],
            ),
            if (loan['reason'] != null &&
                loan['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Reason: ${loan['reason']}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic)),
            ],
            Text(
                'Applied: ${DateFormat('dd MMM yyyy').format(DateTime.parse(loan['created_at']))}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),

            if (showProgress && status == 'active') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Repaid: ₹${fmt.format(amount - balance)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green)),
                  Text('Balance: ₹${fmt.format(balance)}',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: total > 0 ? paid / total : 0,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF006A61)),
              ),
            ],

            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewLoan(loan, 'rejected'),
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text('Reject',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _reviewLoan(loan, 'active'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve & Disburse'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reviewLoan(
      Map<String, dynamic> loan, String newStatus) async {
    final action = newStatus == 'active' ? 'Approve' : 'Reject';
    final remarksC = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Loan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${loan['profiles']?['full_name'] ?? 'Employee'} requested ₹${NumberFormat('#,##,###').format((loan['amount'] as num).toInt())} ${loan['type']}.',
                style: const TextStyle(fontSize: 13)),
            if (newStatus == 'active') ...[
              const SizedBox(height: 8),
              Text(
                  'EMI: ₹${NumberFormat('#,##,###').format((loan['emi_amount'] as num?)?.toInt() ?? 0)} × ${loan['total_installments'] ?? 0} months',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                  'EMI will be auto-deducted from monthly salary during payroll processing.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: remarksC,
              decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor:
                    newStatus == 'active' ? Colors.green : Colors.red),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'approved_by': SupabaseService.userId,
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (newStatus == 'active') {
        updateData['disbursed_at'] =
            DateTime.now().toUtc().toIso8601String();
      }

      await SupabaseService.client
          .from('employee_loans')
          .update(updateData)
          .eq('id', loan['id']);

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'active'
              ? 'Loan approved & disbursed!'
              : 'Loan rejected'),
          backgroundColor:
              newStatus == 'active' ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _statItem(String label, String value) {
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
