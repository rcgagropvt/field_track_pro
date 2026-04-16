import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/collection_service.dart';

class AdminCollectionsScreen extends StatefulWidget {
  const AdminCollectionsScreen({super.key});
  @override
  State<AdminCollectionsScreen> createState() =>
      _AdminCollectionsScreenState();
}

class _AdminCollectionsScreenState
    extends State<AdminCollectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _confirmed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await SupabaseService.client
          .from('collections')
          .select('*, invoices(invoice_number, amount, due_date)')
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(all as List);
      if (mounted) {
        setState(() {
          _pending =
              list.where((c) => c['status'] == 'pending').toList();
          _confirmed =
              list.where((c) => c['status'] != 'pending').toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> collection,
      {required bool sendWA}) async {
    // Fetch party phone
    String? phone;
    try {
      final party = await SupabaseService.client
          .from('parties')
          .select('phone')
          .eq('id', collection['party_id'] as String)
          .single();
      phone = party['phone'] as String?;
    } catch (_) {}

    final invoice =
        collection['invoices'] as Map<String, dynamic>? ?? {};

    await CollectionService.confirmCollection(
      collectionId: collection['id'] as String,
      invoiceId: collection['invoice_id'] as String,
      amountCollected:
          (collection['amount_collected'] as num).toDouble(),
      sendWhatsApp: sendWA && phone != null,
      whatsappData: (sendWA && phone != null)
          ? {
              'phone': phone.replaceAll(RegExp(r'[^0-9]'), ''),
              'party_name': collection['party_name'],
              'invoice_number': invoice['invoice_number'] ?? '',
              'amount': collection['amount_collected']
                  .toStringAsFixed(0),
              'payment_mode': collection['payment_mode'],
              'reference_no': collection['reference_no'] ?? '',
            }
          : null,
    );

    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sendWA && phone != null
            ? '✅ Confirmed & WhatsApp sent'
            : '✅ Payment confirmed'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _reject(String collectionId) async {
    await SupabaseService.client
        .from('collections')
        .update({'status': 'rejected'}).eq('id', collectionId);
    _load();
  }

  Future<void> _sendReminder(Map<String, dynamic> collection) async {
    String? phone;
    try {
      final party = await SupabaseService.client
          .from('parties')
          .select('phone')
          .eq('id', collection['party_id'] as String)
          .single();
      phone = party['phone'] as String?;
    } catch (_) {}

    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No phone number for this party'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final invoice =
        collection['invoices'] as Map<String, dynamic>? ?? {};
    await CollectionService.sendPaymentReminder(
      phone: phone.replaceAll(RegExp(r'[^0-9]'), ''),
      partyName: collection['party_name'] ?? '',
      invoiceNumber: invoice['invoice_number'] ?? '',
      balance: (collection['amount_collected'] as num).toDouble(),
      dueDate: invoice['due_date'] ?? '',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📲 Reminder sent via WhatsApp'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Collections',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'History (${_confirmed.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildList(_pending, isPending: true),
                _buildList(_confirmed, isPending: false),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items,
      {required bool isPending}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending
                  ? Icons.check_circle_outline
                  : Icons.history,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending collections' : 'No history yet',
              style:
                  const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final fmt = NumberFormat('#,##,###');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) =>
            _collectionCard(items[i], fmt, isPending: isPending),
      ),
    );
  }

  Widget _collectionCard(Map<String, dynamic> c, NumberFormat fmt,
      {required bool isPending}) {
    final invoice = c['invoices'] as Map<String, dynamic>? ?? {};
    final modeIcons = {
      'cash': Icons.money,
      'upi': Icons.phone_android,
      'cheque': Icons.receipt_long,
      'bank_transfer': Icons.account_balance,
      'other': Icons.more_horiz,
    };
    final autoWA = c['whatsapp_auto'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? Colors.orange.shade200
              : c['status'] == 'confirmed'
                  ? Colors.green.shade200
                  : Colors.red.shade200,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['party_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            invoice['invoice_number'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${fmt.format((c['amount_collected'] as num).toDouble())}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.black87),
                        ),
                        Row(children: [
                          Icon(
                              modeIcons[c['payment_mode']] ??
                                  Icons.payment,
                              size: 13,
                              color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(c['payment_mode'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ]),
                      ],
                    ),
                  ],
                ),

                if (c['reference_no'] != null &&
                    (c['reference_no'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.tag, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Ref: ${c['reference_no']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ]),
                ],

                if (c['notes'] != null &&
                    (c['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.notes, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(c['notes'],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ]),
                ],

                const SizedBox(height: 8),

                // WhatsApp auto badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: autoWA
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: autoWA
                              ? Colors.green.shade200
                              : Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat,
                          size: 11,
                          color: autoWA
                              ? Colors.green.shade700
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        autoWA ? 'Auto WhatsApp ON' : 'Auto WhatsApp OFF',
                        style: TextStyle(
                            fontSize: 10,
                            color: autoWA
                                ? Colors.green.shade700
                                : Colors.grey,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  if (c['whatsapp_sent'] == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.done_all,
                                size: 11, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('Sent',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ],
                ]),
              ],
            ),
          ),

          if (isPending) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(children: [
                // Confirm without WA
                TextButton.icon(
                  onPressed: () => _confirm(c, sendWA: false),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirm'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.green),
                ),
                // Confirm with WA
                TextButton.icon(
                  onPressed: () => _confirm(c, sendWA: true),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('Confirm + WhatsApp'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700),
                ),
                const Spacer(),
                // Reject
                TextButton.icon(
                  onPressed: () => _reject(c['id'] as String),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red),
                ),
              ]),
            ),
          ] else ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c['status'] == 'confirmed'
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (c['status'] as String).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c['status'] == 'confirmed'
                            ? Colors.green.shade700
                            : Colors.red),
                  ),
                ),
                const Spacer(),
                // Manual reminder
                TextButton.icon(
                  onPressed: () => _sendReminder(c),
                  icon: const Icon(Icons.send, size: 14),
                  label: const Text('Send Reminder'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle:
                          const TextStyle(fontSize: 12)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

