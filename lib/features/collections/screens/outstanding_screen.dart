import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/collection_service.dart';
import 'collect_payment_screen.dart';

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key});
  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String _filter = 'all'; // all, overdue, partial

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await CollectionService.getOutstandingInvoices();
    if (mounted) setState(() { _invoices = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    final today = DateTime.now();
    return _invoices.where((inv) {
      if (_filter == 'overdue') {
        final due = DateTime.tryParse(inv['due_date'] ?? '');
        return due != null && due.isBefore(today);
      }
      if (_filter == 'partial') return inv['status'] == 'partial';
      return true;
    }).toList();
  }

  double get _totalOutstanding =>
      _invoices.fold(0, (s, i) => s + ((i['balance'] as num?)?.toDouble() ?? 0));

  Color _statusColor(String status) {
    switch (status) {
      case 'partial': return Colors.orange;
      case 'unpaid':  return Colors.red;
      default:        return Colors.grey;
    }
  }

  bool _isOverdue(Map<String, dynamic> inv) {
    final due = DateTime.tryParse(inv['due_date'] ?? '');
    return due != null && due.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Outstanding',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.red.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Outstanding',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('₹${fmt.format(_totalOutstanding)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${_invoices.length} invoices pending',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _chip('all', 'All'),
                      const SizedBox(width: 8),
                      _chip('overdue', 'Overdue'),
                      const SizedBox(width: 8),
                      _chip('partial', 'Partial'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 64, color: Colors.green.shade300),
                              const SizedBox(height: 12),
                              const Text('All clear! No outstanding.',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _invoiceCard(_filtered[i], fmt),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chip(String value, String label) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 13)),
      ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv, NumberFormat fmt) {
    final overdue = _isOverdue(inv);
    final balance = (inv['balance'] as num?)?.toDouble() ?? 0;
    final amount = (inv['amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
    final pct = amount > 0 ? (paid / amount) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv['party_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(inv['invoice_number'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${fmt.format(balance)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: overdue
                                    ? Colors.red
                                    : Colors.black87)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(inv['status'] ?? '')
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (inv['status'] ?? '').toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(inv['status'] ?? '')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0, 1),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(
                        pct >= 1 ? Colors.green : Colors.orange),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Paid: ₹${fmt.format(paid)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    if (overdue)
                      Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: Colors.red),
                        const SizedBox(width: 3),
                        Text(
                          'Due: ${inv['due_date'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600),
                        ),
                      ])
                    else
                      Text('Due: ${inv['due_date'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CollectPaymentScreen(invoice: inv)));
                    _load();
                  },
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Collect Payment'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

