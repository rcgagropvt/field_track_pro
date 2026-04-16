import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../collections/screens/collect_payment_screen.dart';
import '../../orders/screens/order_booking_screen.dart';
import '../../orders/screens/order_detail_screen.dart';

class PartyProfileScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  final bool isAdmin;
  const PartyProfileScreen({
    super.key,
    required this.party,
    this.isAdmin = false,
  });
  @override
  State<PartyProfileScreen> createState() => _PartyProfileScreenState();
}

class _PartyProfileScreenState extends State<PartyProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Map<String, dynamic> _party;
  bool _loading = true;

  // Data
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _collections = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _ledger = [];
  List<Map<String, dynamic>> _pdcs = [];

  double _totalSales = 0, _totalPaid = 0, _totalOutstanding = 0;

  final _fmt = NumberFormat('#,##,###');

  @override
  void initState() {
    super.initState();
    _party = Map<String, dynamic>.from(widget.party);
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pid = _party['id'] as String;

      // Fetch all data in parallel
      final results = await Future.wait([
        SupabaseService.client
            .from('invoices')
            .select()
            .eq('party_id', pid)
            .order('created_at', ascending: false),
        SupabaseService.client
            .from('collections')
            .select()
            .eq('party_id', pid)
            .order('collected_at', ascending: false),
        SupabaseService.client
            .from('orders')
            .select()
            .eq('party_id', pid)
            .order('created_at', ascending: false),
        // Refresh party data (credit_limit etc)
        SupabaseService.client.from('parties').select().eq('id', pid).single(),
      ]);

      final invoices = List<Map<String, dynamic>>.from(results[0] as List);
      final collections = List<Map<String, dynamic>>.from(results[1] as List);
      final orders = List<Map<String, dynamic>>.from(results[2] as List);
      final partyData = results[3] as Map<String, dynamic>;

      // Build ledger
      final List<Map<String, dynamic>> ledger = [];
      for (final o in orders) {
        ledger.add({
          'date': o['created_at'],
          'description': 'Order ${o['order_number'] ?? ''}',
          'debit': (o['total_amount'] as num).toDouble(),
          'credit': 0.0,
          'type': 'order',
          'status': o['status'],
        });
      }
      for (final c in collections) {
        if (c['status'] == 'confirmed') {
          ledger.add({
            'date': c['collected_at'],
            'description': 'Payment (${c['payment_mode']})'
                '${c['reference_no'] != null ? ' #${c['reference_no']}' : ''}',
            'debit': 0.0,
            'credit': (c['amount_collected'] as num).toDouble(),
            'type': 'payment',
          });
        }
      }
      ledger
          .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      double bal = 0;
      for (final e in ledger) {
        bal += (e['debit'] as double) - (e['credit'] as double);
        e['balance'] = bal;
      }

      // PDC cheques
      final pdcs = collections.where((c) => c['is_pdc'] == true).toList();

      // Totals
      double sales = orders.fold<double>(
          0, (s, o) => s + ((o['total_amount'] as num).toDouble()));
      double paid = collections
          .where((c) => c['status'] == 'confirmed')
          .fold<double>(
              0, (s, c) => s + ((c['amount_collected'] as num).toDouble()));
      double outstanding = invoices
          .where((i) => i['status'] != 'paid')
          .fold<double>(
              0, (s, i) => s + ((i['balance'] as num?)?.toDouble() ?? 0));

      if (mounted) {
        setState(() {
          _party = partyData;
          _invoices = invoices;
          _collections = collections;
          _orders = orders;
          _ledger = ledger;
          _pdcs = pdcs;
          _totalSales = sales;
          _totalPaid = paid;
          _totalOutstanding = outstanding;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Edit credit limit dialog ──────────────────────
  Future<void> _editCreditLimit() async {
    final ctrl = TextEditingController(
        text: (_party['credit_limit'] as num?)?.toStringAsFixed(0) ?? '0');
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Credit Limit'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: '0 = No limit',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(ctrl.text) ?? 0),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) {
      await SupabaseService.client
          .from('parties')
          .update({'credit_limit': result}).eq('id', _party['id'] as String);
      _load();
    }
  }

  // ── Edit party details ────────────────────────────
  Future<void> _editPartyDetails() async {
    final nameCtrl = TextEditingController(text: _party['name'] ?? '');
    final phoneCtrl = TextEditingController(text: _party['phone'] ?? '');
    final contactCtrl =
        TextEditingController(text: _party['contact_person'] ?? '');
    final addressCtrl = TextEditingController(text: _party['address'] ?? '');
    final emailCtrl = TextEditingController(text: _party['email'] ?? '');
    final gstCtrl = TextEditingController(text: _party['gst_number'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Text('Edit Party Details',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 16),
              _editField('Business Name', nameCtrl, Icons.store_rounded),
              _editField('Contact Person', contactCtrl, Icons.person_outline),
              _editField('Phone', phoneCtrl, Icons.phone_outlined,
                  type: TextInputType.phone),
              _editField('Email', emailCtrl, Icons.email_outlined,
                  type: TextInputType.emailAddress),
              _editField('Address', addressCtrl, Icons.location_on_outlined,
                  maxLines: 2),
              _editField('GST Number', gstCtrl, Icons.receipt_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await SupabaseService.client.from('parties').update({
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'contact_person': contactCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'gst_number': gstCtrl.text.trim(),
                    }).eq('id', _party['id'] as String);
                    if (mounted) {
                      Navigator.pop(context);
                      _load();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Update Party',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? type, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creditLimit = (_party['credit_limit'] as num?)?.toDouble() ?? 0;
    final creditUsedPct = creditLimit > 0
        ? (_totalOutstanding / creditLimit).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _editPartyDetails),
                    IconButton(
                        icon: const Icon(Icons.refresh), onPressed: _load),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white24,
                                  child: Text(
                                    (_party['name'] ?? 'P')[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_party['name'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          (_party['type'] ?? 'party')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),
                              // KPI row
                              Row(children: [
                                _kpi('Total Sales',
                                    '₹${_fmt.format(_totalSales)}'),
                                _kpiDivider(),
                                _kpi('Paid', '₹${_fmt.format(_totalPaid)}'),
                                _kpiDivider(),
                                _kpi('Outstanding',
                                    '₹${_fmt.format(_totalOutstanding)}',
                                    color: _totalOutstanding > 0
                                        ? Colors.orange.shade200
                                        : Colors.green.shade200),
                              ]),
                              const SizedBox(height: 12),
                              // Credit limit bar
                              if (creditLimit > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Credit Limit',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                    GestureDetector(
                                      onTap: widget.isAdmin
                                          ? _editCreditLimit
                                          : null,
                                      child: Row(children: [
                                        Text('₹${_fmt.format(creditLimit)}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                        if (widget.isAdmin)
                                          const Icon(Icons.edit,
                                              size: 12, color: Colors.white54),
                                      ]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: creditUsedPct,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation(
                                        creditUsedPct > 0.8
                                            ? Colors.red.shade300
                                            : Colors.green.shade300),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(creditUsedPct * 100).toStringAsFixed(0)}% used',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 10),
                                ),
                              ] else if (widget.isAdmin)
                                GestureDetector(
                                  onTap: _editCreditLimit,
                                  child: const Row(children: [
                                    Icon(Icons.add_circle_outline,
                                        color: Colors.white54, size: 14),
                                    SizedBox(width: 4),
                                    Text('Set Credit Limit',
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottom: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(text: '📋 Overview'),
                      Tab(text: '📒 Ledger'),
                      Tab(text: 'Invoices'),
                      Tab(text: '🏦 PDC Cheques'),
                      Tab(text: '🛒 Orders'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _overviewTab(),
                  _ledgerTab(),
                  _paymentsTab(),
                  _pdcTab(),
                  _ordersTab(),
                ],
              ),
            ),
      floatingActionButton: _totalOutstanding > 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final unpaid =
                    _invoices.where((i) => i['status'] != 'paid').toList();
                if (unpaid.isNotEmpty && mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            CollectPaymentScreen(invoice: unpaid.first)),
                  );
                  _load();
                }
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.payments_outlined, color: Colors.white),
              label: Text('Collect ₹${_fmt.format(_totalOutstanding)}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  // ── TAB 1: Overview ──────────────────────────────
  Widget _overviewTab() {
    final today = DateTime.now();
    final overdueInvoices = _invoices.where((i) {
      final due = DateTime.tryParse(i['due_date'] ?? '');
      return i['status'] != 'paid' && due != null && due.isBefore(today);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact info card
        _sectionCard(
          title: 'Contact Information',
          icon: Icons.person_outline,
          child: Column(children: [
            _infoRow(Icons.phone_outlined, 'Phone', _party['phone'] ?? '—'),
            _infoRow(Icons.email_outlined, 'Email', _party['email'] ?? '—'),
            _infoRow(Icons.person_rounded, 'Contact',
                _party['contact_person'] ?? '—'),
            _infoRow(Icons.location_on_outlined, 'Address',
                _party['address'] ?? '—'),
            _infoRow(
                Icons.receipt_outlined, 'GST', _party['gst_number'] ?? '—'),
            _infoRow(Icons.location_city, 'City', _party['city'] ?? '—'),
          ]),
        ),

        const SizedBox(height: 12),

        // Aging buckets summary
        _sectionCard(
          title: 'Outstanding Aging',
          icon: Icons.access_time,
          child: _invoices.where((i) => i['status'] != 'paid').isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('✅ No outstanding invoices',
                        style: TextStyle(color: Colors.green)),
                  ),
                )
              : Column(
                  children: [
                    ..._buildAgingRows(),
                    if (overdueInvoices.isNotEmpty) ...[
                      const Divider(height: 20),
                      Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text('${overdueInvoices.length} overdue invoice(s)',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ]),
                    ],
                  ],
                ),
        ),

        const SizedBox(height: 12),

        // Quick actions
        if (!widget.isAdmin)
          _sectionCard(
            title: 'Quick Actions',
            icon: Icons.bolt_rounded,
            child: Row(children: [
              _actionBtn(Icons.shopping_cart_outlined, 'New Order', () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderBookingScreen(party: _party)),
                );
                _load();
              }),
              const SizedBox(width: 12),
              if (_totalOutstanding > 0)
                _actionBtn(Icons.payments_outlined, 'Collect', () async {
                  final unpaid =
                      _invoices.where((i) => i['status'] != 'paid').toList();
                  if (unpaid.isNotEmpty) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CollectPaymentScreen(invoice: unpaid.first)),
                    );
                    _load();
                  }
                }),
            ]),
          ),

        if (widget.isAdmin) ...[
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Admin Controls',
            icon: Icons.admin_panel_settings_outlined,
            child: Column(children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.credit_card_outlined,
                    color: AppColors.primary),
                title: const Text('Credit Limit'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    (_party['credit_limit'] as num?)?.toDouble() == 0 ||
                            _party['credit_limit'] == null
                        ? 'Not set'
                        : '₹${_fmt.format((_party['credit_limit'] as num).toDouble())}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ]),
                onTap: _editCreditLimit,
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.block_outlined, color: Colors.red),
                title: const Text('Deactivate Party'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Deactivate Party?'),
                      content: const Text(
                          'This party will be hidden from all reps.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Deactivate',
                                style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await SupabaseService.client.from('parties').update(
                        {'is_active': false}).eq('id', _party['id'] as String);
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
            ]),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildAgingRows() {
    final today = DateTime.now();
    final buckets = {'0-30': 0.0, '31-60': 0.0, '61-90': 0.0, '90+': 0.0};
    final colors = {
      '0-30': Colors.green,
      '31-60': Colors.orange,
      '61-90': Colors.deepOrange,
      '90+': Colors.red,
    };

    for (final inv in _invoices.where((i) => i['status'] != 'paid')) {
      final due = DateTime.tryParse(inv['due_date'] ?? '');
      final bal = (inv['balance'] as num?)?.toDouble() ?? 0;
      if (due == null) {
        buckets['0-30'] = buckets['0-30']! + bal;
        continue;
      }
      final days = today.difference(due).inDays;
      if (days <= 30)
        buckets['0-30'] = buckets['0-30']! + bal;
      else if (days <= 60)
        buckets['31-60'] = buckets['31-60']! + bal;
      else if (days <= 90)
        buckets['61-90'] = buckets['61-90']! + bal;
      else
        buckets['90+'] = buckets['90+']! + bal;
    }

    return buckets.entries
        .where((e) => e.value > 0)
        .map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: colors[e.key], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('${e.key} days', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Text('₹${_fmt.format(e.value)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors[e.key],
                        fontSize: 13)),
              ]),
            ))
        .toList();
  }

  // ── TAB 2: Ledger ────────────────────────────────
  Widget _ledgerTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(children: [
            _ledgerHeader('Date', flex: 2),
            _ledgerHeader('Description', flex: 4),
            _ledgerHeader('Debit', flex: 2, right: true),
            _ledgerHeader('Credit', flex: 2, right: true),
            _ledgerHeader('Balance', flex: 2, right: true),
          ]),
        ),
        Expanded(
          child: _ledger.isEmpty
              ? const Center(child: Text('No transactions yet'))
              : ListView.builder(
                  itemCount: _ledger.length,
                  itemBuilder: (_, i) {
                    final e = _ledger[i];
                    final isOrder = e['type'] == 'order';
                    final bal = e['balance'] as double;
                    return Container(
                      decoration: BoxDecoration(
                        color:
                            i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                        border: Border(
                          left: BorderSide(
                            color: isOrder
                                ? Colors.red.shade300
                                : Colors.green.shade300,
                            width: 3,
                          ),
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            DateFormat('dd/MM').format(
                                DateTime.parse(e['date'] as String).toLocal()),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(e['description'] as String,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            (e['debit'] as double) > 0
                                ? '₹${_fmt.format(e['debit'])}'
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
                                ? '₹${_fmt.format(e['credit'])}'
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
                            '₹${_fmt.format(bal.abs())}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
      ],
    );
  }

  // ── TAB 3: Payments ──────────────────────────────
  Widget _paymentsTab() {
    return _invoices.isEmpty
        ? const Center(child: Text('No invoices yet'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _invoices.length,
            itemBuilder: (_, i) {
              final inv = _invoices[i];
              final balance = (inv['balance'] as num?)?.toDouble() ?? 0;
              final amount = (inv['amount'] as num).toDouble();
              final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
              final due = DateTime.tryParse(inv['due_date'] ?? '');
              final overdue = due != null &&
                  due.isBefore(DateTime.now()) &&
                  inv['status'] != 'paid';

              return GestureDetector(
                onTap: () => _showInvoiceDetail(inv),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: overdue
                            ? Colors.red.shade200
                            : Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv['invoice_number'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            if (due != null)
                              Text(
                                  'Due: ${DateFormat('dd MMM yyyy').format(due)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          overdue ? Colors.red : Colors.grey)),
                          ],
                        ),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${_fmt.format(balance)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: balance > 0
                                        ? Colors.red.shade700
                                        : Colors.green)),
                            _statusBadge(inv['status'] ?? 'unpaid'),
                          ]),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: amount > 0 ? (paid / amount).clamp(0, 1) : 0,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(
                            paid >= amount ? Colors.green : Colors.orange),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoice: ₹${_fmt.format(amount)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text('Paid: ₹${_fmt.format(paid)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    // Tap hint
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.touch_app,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('Tap for details',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    ),
                  ]),
                ),
              );
            },
          );
  }

  void _showInvoiceDetail(Map<String, dynamic> inv) {
    final balance = (inv['balance'] as num?)?.toDouble() ?? 0;
    final amount = (inv['amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
    final due = DateTime.tryParse(inv['due_date'] ?? '');
    final created = DateTime.tryParse(inv['created_at'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),

              // Title + status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invoice Detail',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(inv['invoice_number'] ?? '',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  _statusBadge(inv['status'] ?? 'unpaid'),
                ],
              ),
              const Divider(height: 24),

              // Party
              _invoiceDetailRow(
                  Icons.store, 'Party', inv['party_name'] ?? 'N/A'),

              // Dates
              if (created != null)
                _invoiceDetailRow(
                    Icons.calendar_today,
                    'Created',
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(created.toLocal())),
              if (due != null)
                _invoiceDetailRow(Icons.event, 'Due Date',
                    DateFormat('dd MMM yyyy').format(due)),

              const Divider(height: 24),

              // Financial Summary
              const Text('Financial Summary',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _amountRow('Invoice Amount', amount, Colors.black87),
              const SizedBox(height: 6),
              _amountRow('Amount Paid', paid, Colors.green.shade700),
              const Divider(height: 16),
              _amountRow('Balance Due', balance,
                  balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                  bold: true),

              // Payment progress
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: amount > 0 ? (paid / amount).clamp(0, 1) : 0,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(
                      paid >= amount ? Colors.green : Colors.orange),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(amount > 0 ? (paid / amount * 100) : 0).toStringAsFixed(1)}% paid',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),

              // Notes
              if (inv['notes'] != null &&
                  inv['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(inv['notes'].toString(),
                      style: const TextStyle(fontSize: 13)),
                ),
              ],

              // Collect Payment button (for sales rep)
              if (!widget.isAdmin && balance > 0) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CollectPaymentScreen(invoice: inv)),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: Text('Collect ₹${_fmt.format(balance)}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, Color color,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text('₹${_fmt.format(amount)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color)),
      ],
    );
  }

  // ── TAB 4: PDC Cheques ───────────────────────────
  Widget _pdcTab() {
    return _pdcs.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_box_outline_blank,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No PDC cheques recorded',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pdcs.length,
            itemBuilder: (_, i) {
              final pdc = _pdcs[i];
              final chequeDate = DateTime.tryParse(pdc['cheque_date'] ?? '');
              final isPast =
                  chequeDate != null && chequeDate.isBefore(DateTime.now());

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isPast
                          ? Colors.green.shade200
                          : Colors.orange.shade200),
                ),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          isPast ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_rounded,
                        color: isPast ? Colors.green : Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cheque #${pdc['cheque_number'] ?? '—'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(pdc['cheque_bank'] ?? '—',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        if (chequeDate != null)
                          Text(
                            DateFormat('dd MMM yyyy').format(chequeDate),
                            style: TextStyle(
                                fontSize: 12,
                                color: isPast ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      '₹${_fmt.format((pdc['amount_collected'] as num).toDouble())}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPast
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPast ? 'Due passed' : 'Post-dated',
                        style: TextStyle(
                            fontSize: 10,
                            color: isPast ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ]),
              );
            },
          );
  }

  // ── TAB 5: Orders ────────────────────────────────
  //  TAB 5: Orders
  //  TAB 5: Orders
  Widget _ordersTab() {
    return _orders.isEmpty
        ? const Center(child: Text('No orders yet'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _orders.length,
            itemBuilder: (_, i) {
              final o = _orders[i];
              final status = o['status'] ?? 'placed';
              final paymentMode = (o['payment_mode'] ?? 'credit').toString();
              final paymentStatus =
                  (o['payment_status'] ?? 'unpaid').toString();

              return GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(orderId: o['id']),
                    ),
                  );
                  _load(); // Refresh after returning
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        // Order icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _orderStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt_rounded,
                              color: _orderStatusColor(status), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o['order_number'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(
                                    DateTime.parse(o['created_at']).toLocal()),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${_fmt.format((o['total_amount'] as num).toDouble())}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              _statusBadge(status),
                            ]),
                      ]),
                      const SizedBox(height: 8),
                      // Payment info row
                      Row(
                        children: [
                          Icon(Icons.payment_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(paymentMode.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: paymentStatus == 'paid'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              paymentStatus.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: paymentStatus == 'paid'
                                      ? Colors.green
                                      : Colors.orange),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey.shade400),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'placed':
        return Colors.blue;
      case 'confirmed':
        return Colors.indigo;
      case 'dispatched':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ── Helpers ──────────────────────────────────────
  Widget _kpi(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ]),
    );
  }

  Widget _kpiDivider() =>
      Container(width: 1, height: 28, color: Colors.white24);

  Widget _sectionCard(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _ledgerHeader(String text, {int flex = 1, bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black54)),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'paid': Colors.green,
      'partial': Colors.orange,
      'unpaid': Colors.red,
      'placed': Colors.blue,
      'confirmed': Colors.green,
      'pending': Colors.orange,
      'cancelled': Colors.red,
    };
    final c = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
