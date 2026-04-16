import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'collect_payment_screen.dart';

class PartyLedgerScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  const PartyLedgerScreen({super.key, required this.party});
  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  double _totalDr = 0, _totalCr = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch orders (debit)
      final orders = await SupabaseService.client
          .from('orders')
          .select('id, order_number, total_amount, created_at, status')
          .eq('party_id', widget.party['id'] as String)
          .order('created_at');

      // Fetch confirmed collections (credit)
      final collections = await SupabaseService.client
          .from('collections')
          .select('id, amount_collected, collected_at, payment_mode, reference_no, invoices(invoice_number)')
          .eq('party_id', widget.party['id'] as String)
          .eq('status', 'confirmed')
          .order('collected_at');

      final List<Map<String, dynamic>> entries = [];

      for (final o in orders as List) {
        entries.add({
          'date': o['created_at'],
          'description': 'Order ${o['order_number'] ?? o['id'].toString().substring(0, 8)}',
          'debit': (o['total_amount'] as num).toDouble(),
          'credit': 0.0,
          'type': 'order',
        });
      }

      for (final c in collections as List) {
        final inv = c['invoices'] as Map<String, dynamic>? ?? {};
        entries.add({
          'date': c['collected_at'],
          'description':
              'Payment${inv['invoice_number'] != null ? ' - ${inv['invoice_number']}' : ''} (${c['payment_mode']})',
          'debit': 0.0,
          'credit': (c['amount_collected'] as num).toDouble(),
          'type': 'payment',
        });
      }

      // Sort by date
      entries.sort((a, b) =>
          (a['date'] as String).compareTo(b['date'] as String));

      // Compute running balance
      double balance = 0;
      double dr = 0, cr = 0;
      for (final e in entries) {
        balance += (e['debit'] as double) - (e['credit'] as double);
        dr += e['debit'] as double;
        cr += e['credit'] as double;
        e['balance'] = balance;
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _totalDr = dr;
          _totalCr = cr;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###');
    final balance = _totalDr - _totalCr;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Party Ledger',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.party['name'] ?? '',
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
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
                // Summary header
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _summaryCell('Total Sales', _totalDr, fmt,
                          color: Colors.red.shade700),
                      _vDivider(),
                      _summaryCell('Total Received', _totalCr, fmt,
                          color: Colors.green.shade700),
                      _vDivider(),
                      _summaryCell('Balance Due', balance, fmt,
                          color: balance > 0
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                          bold: true),
                    ],
                  ),
                ),

                // Ledger table header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: const Row(children: [
                    Expanded(
                        flex: 2,
                        child: Text('Date',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    Expanded(
                        flex: 4,
                        child: Text('Description',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    Expanded(
                        flex: 2,
                        child: Text('Debit',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    Expanded(
                        flex: 2,
                        child: Text('Credit',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    Expanded(
                        flex: 2,
                        child: Text('Balance',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                  ]),
                ),

                // Ledger rows
                Expanded(
                  child: _entries.isEmpty
                      ? Container(
                          color: Colors.white,
                          child: const Center(
                            child: Text('No transactions yet',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 16),
                          itemBuilder: (_, i) {
                            final e = _entries[i];
                            final isOrder = e['type'] == 'order';
                            final bal = e['balance'] as double;
                            return Container(
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? Colors.white
                                    : const Color(0xFFF9FAFB),
                                border: Border(
                                  left: BorderSide(
                                    color: isOrder
                                        ? Colors.red.shade200
                                        : Colors.green.shade200,
                                    width: 3,
                                  ),
                                  bottom: BorderSide(
                                      color: Colors.grey.shade100),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    DateFormat('dd MMM').format(
                                        DateTime.parse(e['date'] as String)
                                            .toLocal()),
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(e['description'] as String,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (e['debit'] as double) > 0
                                        ? '₹${fmt.format(e['debit'])}'
                                        : '—',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (e['credit'] as double) > 0
                                        ? '₹${fmt.format(e['credit'])}'
                                        : '—',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₹${fmt.format(bal.abs())}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: bal > 0
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                ),

                // Collect payment button
                if (balance > 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Find latest unpaid invoice for this party
                          final invoices = await SupabaseService.client
                              .from('invoices')
                              .select()
                              .eq('party_id', widget.party['id'] as String)
                              .neq('status', 'paid')
                              .order('created_at', ascending: false)
                              .limit(1);
                          if ((invoices as List).isNotEmpty && mounted) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CollectPaymentScreen(
                                    invoice: invoices.first),
                              ),
                            );
                            _load();
                          }
                        },
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                            'Collect Payment  •  ₹${fmt.format(balance)}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _summaryCell(String label, double value, NumberFormat fmt,
      {Color? color, bool bold = false}) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('₹${fmt.format(value)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? Colors.black87)),
      ]),
    );
  }

  Widget _vDivider() => Container(
      width: 1,
      height: 36,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}


