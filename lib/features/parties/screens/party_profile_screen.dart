import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../collections/screens/collect_payment_screen.dart';
import '../../orders/screens/order_booking_screen.dart';

int _loyaltyRefreshKey = 0;

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
    _tabs = TabController(length: 6, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Data load ───────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pid = _party['id'] as String;
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

      final pdcs = collections.where((c) => c['is_pdc'] == true).toList();

      final sales = orders.fold<double>(
          0, (s, o) => s + (o['total_amount'] as num).toDouble());
      final paid = collections
          .where((c) => c['status'] == 'confirmed')
          .fold<double>(
              0, (s, c) => s + (c['amount_collected'] as num).toDouble());
      final outstanding = invoices
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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Edit credit limit ────────────────────────────
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
              border: OutlineInputBorder()),
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

  // ── Edit party details ───────────────────────────
  Future<void> _editPartyDetails() async {
    final nameCtrl = TextEditingController(text: _party['name'] ?? '');
    final phoneCtrl = TextEditingController(text: _party['phone'] ?? '');
    final contactCtrl =
        TextEditingController(text: _party['contact_person'] ?? '');
    final addressCtrl = TextEditingController(text: _party['address'] ?? '');
    final emailCtrl = TextEditingController(text: _party['email'] ?? '');
    final gstCtrl = TextEditingController(text: _party['gst_number'] ?? '');
    final radiusCtrl = TextEditingController(
        text: (_party['geofence_radius'] as num?)?.toStringAsFixed(0) ?? '');

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
              _editField('Geofence Radius (meters)', radiusCtrl,
                  Icons.my_location_rounded,
                  type: TextInputType.number),
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
                      'geofence_radius':
                          double.tryParse(radiusCtrl.text.trim()),
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
          {TextInputType? type, int maxLines = 1}) =>
      Padding(
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

  // ── Open CollectPaymentScreen for a specific invoice ──
  Future<void> _collectForInvoice(Map<String, dynamic> invoice) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CollectPaymentScreen(invoice: invoice)),
    );
    _load();
  }

  // ════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════
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
                          colors: [AppColors.primaryDark, AppColors.primary],
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
                                    value: creditUsedPct as double,
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
                      Tab(text: '🧾 Invoices'),
                      Tab(text: '🏦 PDC Cheques'),
                      Tab(text: '🛒 Orders'),
                      Tab(text: '🎁 Loyalty'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _overviewTab(),
                  _ledgerTab(),
                  _invoicesTab(), // ← FIXED: was _paymentsTab, now shows all invoices with per-invoice Collect
                  _pdcTab(),
                  _ordersTab(),
                  _loyaltyTab(),
                ],
              ),
            ),
      // FAB: only for reps, only when outstanding exists
      floatingActionButton: _totalOutstanding > 0 && !widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                // Show picker if multiple unpaid invoices, else open directly
                final unpaid =
                    _invoices.where((i) => i['status'] != 'paid').toList();
                if (unpaid.length == 1) {
                  _collectForInvoice(unpaid.first);
                } else if (unpaid.length > 1) {
                  _tabs.animateTo(2); // jump to Invoices tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap an invoice below to collect payment'),
                      duration: Duration(seconds: 2),
                    ),
                  );
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

  // ════════════════════════════════════════════════
  // TAB 1 – OVERVIEW
  // ════════════════════════════════════════════════
  Widget _overviewTab() {
    final today = DateTime.now();
    final overdueInvoices = _invoices.where((i) {
      final due = DateTime.tryParse(i['due_date'] ?? '');
      return i['status'] != 'paid' && due != null && due.isBefore(today);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        _sectionCard(
          title: 'Outstanding Aging',
          icon: Icons.access_time,
          child: _invoices.where((i) => i['status'] != 'paid').isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: Text('✅ No outstanding invoices',
                          style: TextStyle(color: Colors.green))))
              : Column(children: [
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
                ]),
        ),
        const SizedBox(height: 12),
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
                _actionBtn(Icons.payments_outlined, 'Collect', () {
                  final unpaid =
                      _invoices.where((i) => i['status'] != 'paid').toList();
                  if (unpaid.length == 1) {
                    _collectForInvoice(unpaid.first);
                  } else {
                    _tabs.animateTo(2);
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
      if (days <= 30) {
        buckets['0-30'] = buckets['0-30']! + bal;
      } else if (days <= 60) {
        buckets['31-60'] = buckets['31-60']! + bal;
      } else if (days <= 90) {
        buckets['61-90'] = buckets['61-90']! + bal;
      } else {
        buckets['90+'] = buckets['90+']! + bal;
      }
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

  // ════════════════════════════════════════════════
  // TAB 2 – LEDGER
  // ════════════════════════════════════════════════
  Widget _ledgerTab() {
    return Column(children: [
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
                      color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                      border: Border(
                        left: BorderSide(
                            color: isOrder
                                ? Colors.red.shade300
                                : Colors.green.shade300,
                            width: 3),
                        bottom: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat('dd/MM').format(
                              DateTime.parse(e['date'] as String).toLocal()),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
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
                }),
      ),
    ]);
  }

  // ════════════════════════════════════════════════
  // TAB 3 – INVOICES  (FIXED: per-invoice Collect button)
  // ════════════════════════════════════════════════
  Widget _invoicesTab() {
    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No invoices yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _invoices.length,
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        final balance = (inv['balance'] as num?)?.toDouble() ?? 0;
        final amount = (inv['amount'] as num).toDouble();
        final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
        final due = DateTime.tryParse(inv['due_date'] ?? '');
        final today = DateTime.now();
        final overdue =
            due != null && due.isBefore(today) && inv['status'] != 'paid';
        final status = (inv['status'] ?? 'unpaid') as String;
        final isPaid = status == 'paid';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: overdue
                  ? Colors.red.shade200
                  : isPaid
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  // Row 1: invoice number + status badge + balance
                  Row(children: [
                    Icon(Icons.receipt_outlined,
                        size: 18,
                        color: overdue ? Colors.red : AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv['invoice_number'] ?? 'INV-—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (due != null)
                            Text(
                              'Due: ${DateFormat('dd MMM yyyy').format(due)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: overdue
                                      ? Colors.red
                                      : Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${_fmt.format(balance)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: isPaid
                                    ? Colors.green
                                    : overdue
                                        ? Colors.red.shade700
                                        : Colors.orange.shade700),
                          ),
                          _statusBadge(status),
                        ]),
                  ]),

                  const SizedBox(height: 10),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(
                          isPaid ? Colors.green : Colors.orange),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invoice: ₹${_fmt.format(amount)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      Text('Paid: ₹${_fmt.format(paid)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ]),
              ),

              // ── Collect button (rep only, unpaid only) ──
              if (!widget.isAdmin && !isPaid) ...[
                const Divider(height: 1),
                InkWell(
                  onTap: () => _collectForInvoice(inv),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          balance > 0
                              ? 'Collect ₹${_fmt.format(balance)}'
                              : 'Record Payment',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        if (overdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('OVERDUE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════
  // TAB 4 – PDC CHEQUES
  // ════════════════════════════════════════════════
  Widget _pdcTab() {
    if (_pdcs.isEmpty) {
      return Center(
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
      );
    }
    return ListView.builder(
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
                color: isPast ? Colors.green.shade200 : Colors.orange.shade200),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPast ? Colors.green.shade50 : Colors.orange.shade50,
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (chequeDate != null)
                    Text(DateFormat('dd MMM yyyy').format(chequeDate),
                        style: TextStyle(
                            fontSize: 12,
                            color: isPast ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                  '₹${_fmt.format((pdc['amount_collected'] as num).toDouble())}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPast ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPast ? 'Cleared' : 'Pending',
                  style: TextStyle(
                      color: isPast ? Colors.green : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // ════════════════════════════════════════════════
  // TAB 5 – ORDERS
  // ════════════════════════════════════════════════
  Widget _ordersTab() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No orders yet', style: TextStyle(color: Colors.grey)),
            if (!widget.isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrderBookingScreen(party: _party)),
                  );
                  _load();
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Place First Order',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        final date = DateTime.tryParse(o['created_at'] ?? '');
        final status = (o['status'] ?? 'pending') as String;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o['order_number'] ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (date != null)
                    Text(DateFormat('dd MMM yyyy').format(date.toLocal()),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '₹${_fmt.format((o['total_amount'] as num).toDouble())}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              _statusBadge(status),
            ]),
          ]),
        );
      },
    );
  }

  // ════════════════════════════════════════════════
  // SHARED HELPERS
  // ════════════════════════════════════════════════
  Widget _kpi(String label, String value, {Color color = Colors.white}) =>
      Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      );

  Widget _kpiDivider() => Container(
      width: 1,
      height: 28,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _sectionCard(
          {required String title,
          required IconData icon,
          required Widget child}) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
              width: 64,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        ),
      );

  Widget _ledgerHeader(String t, {int flex = 1, bool right = false}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600)),
      );

  Widget _statusBadge(String status) {
    final map = {
      'paid': (Colors.green, Colors.green.shade50),
      'partial': (Colors.orange, Colors.orange.shade50),
      'unpaid': (Colors.red, Colors.red.shade50),
      'overdue': (Colors.red, Colors.red.shade50),
      'confirmed': (Colors.green, Colors.green.shade50),
      'pending': (Colors.orange, Colors.orange.shade50),
      'cancelled': (Colors.grey, Colors.grey.shade100),
      'delivered': (Colors.blue, Colors.blue.shade50),
    };
    final colors = map[status] ?? (Colors.grey, Colors.grey.shade100);
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: colors.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: colors.$1,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }

  // ════════════════════════════════════════════════
  Widget _loyaltyTab() {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey(_loyaltyRefreshKey),
      future: _loadLoyaltyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null) {
          return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.card_giftcard, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('No loyalty data yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('Points will be earned on orders',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          );
        }

        final tier = data['out_tier'] ?? 'bronze';
        final totalPoints = data['out_total_points'] as int? ?? 0;
        final available = data['out_available_points'] as int? ?? 0;
        final purchases =
            (data['out_total_purchases'] as num?)?.toDouble() ?? 0;
        final nextTier = data['out_next_tier'] ?? 'silver';
        final pointsToNext = data['out_points_to_next'] as int? ?? 0;
        final recentPoints = (data['out_recent_points'] as List?) ?? [];
        final recentRedemptions =
            (data['out_recent_redemptions'] as List?) ?? [];

        final tierColor = tier == 'platinum'
            ? const Color(0xFF6C63FF)
            : tier == 'gold'
                ? Colors.amber.shade700
                : tier == 'silver'
                    ? Colors.blueGrey
                    : Colors.brown;

        final tierIcon = tier == 'platinum'
            ? Icons.diamond
            : tier == 'gold'
                ? Icons.workspace_premium
                : tier == 'silver'
                    ? Icons.star
                    : Icons.military_tech;

        return RefreshIndicator(
          onRefresh: () async => setState(() => _loyaltyRefreshKey++),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Tier Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tierColor, tierColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: tierColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(children: [
                  Icon(tierIcon, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(tier.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(_party['name'] ?? '',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _loyaltyStat(
                            'Available', '$available pts', Colors.white),
                        Container(width: 1, height: 30, color: Colors.white30),
                        _loyaltyStat(
                            'Total Earned', '$totalPoints pts', Colors.white),
                        Container(width: 1, height: 30, color: Colors.white30),
                        _loyaltyStat('Purchases', '₹${_fmt.format(purchases)}',
                            Colors.white),
                      ]),
                  if (tier != 'platinum') ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pointsToNext > 0
                            ? (totalPoints / (totalPoints + pointsToNext))
                                .clamp(0.0, 1.0)
                            : 1.0,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$pointsToNext points to ${nextTier.toUpperCase()}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11)),
                  ],
                ]),
              ),

              const SizedBox(height: 20),

              // ── Rewards Catalog ──
              Row(children: [
                const Text('Rewards Catalog',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$available pts available',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 10),
              FutureBuilder<List>(
                future: SupabaseService.client
                    .from('loyalty_rewards')
                    .select()
                    .eq('is_active', true)
                    .order('points_required'),
                builder: (context, snap) {
                  if (!snap.hasData)
                    return const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()));
                  final rewards = snap.data!;
                  if (rewards.isEmpty)
                    return const Text('No rewards available',
                        style: TextStyle(color: Colors.grey));
                  return SizedBox(
                    height: 170,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: rewards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final r = rewards[i] as Map<String, dynamic>;
                        final canRedeem =
                            available >= (r['points_required'] as int);
                        final typeIcon = r['reward_type'] == 'discount'
                            ? Icons.local_offer
                            : r['reward_type'] == 'cashback'
                                ? Icons.account_balance_wallet
                                : r['reward_type'] == 'gift'
                                    ? Icons.card_giftcard
                                    : Icons.local_shipping;
                        return Container(
                          width: 150,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: canRedeem
                                ? AppColors.primarySurface
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: canRedeem
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(typeIcon,
                                    color: canRedeem
                                        ? AppColors.primary
                                        : Colors.grey,
                                    size: 24),
                                const SizedBox(height: 8),
                                Text(r['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: canRedeem
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const Spacer(),
                                Row(children: [
                                  Text('${r['points_required']} pts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: canRedeem
                                            ? AppColors.primary
                                            : Colors.grey,
                                      )),
                                  const Spacer(),
                                  if (canRedeem)
                                    GestureDetector(
                                      onTap: () => _redeemReward(r),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text('Redeem',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ]),
                              ]),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Points History ──
              if (recentPoints.isNotEmpty) ...[
                const Text('Points History',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...recentPoints.map((p) {
                  final pts = p['points'] as int? ?? 0;
                  final isEarn = pts > 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isEarn ? Colors.green : Colors.red)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEarn
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: isEarn ? Colors.green : Colors.red,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  p['description']?.toString() ??
                                      p['action']?.toString() ??
                                      '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              if (p['created_at'] != null)
                                Text(
                                    DateFormat('dd MMM, hh:mm a').format(
                                        DateTime.parse(
                                                p['created_at'].toString())
                                            .toLocal()),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                            ]),
                      ),
                      Text('${isEarn ? '+' : ''}$pts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isEarn ? Colors.green : Colors.red,
                          )),
                    ]),
                  );
                }),
              ],

              // ── Redemption History ──
              if (recentRedemptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Redemptions',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...recentRedemptions.map((r) {
                  final status = r['status']?.toString() ?? 'pending';
                  final statusColor = status == 'fulfilled'
                      ? Colors.green
                      : status == 'approved'
                          ? Colors.blue
                          : status == 'rejected'
                              ? Colors.red
                              : Colors.orange;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.card_giftcard,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['reward_name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                              Text('${r['points_spent']} pts · $status',
                                  style: TextStyle(
                                      fontSize: 11, color: statusColor)),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status.toUpperCase(),
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  );
                }),
              ],

              const SizedBox(height: 20),

              // ── How it works ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('How Loyalty Works',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      _howItWorksRow('🛒', 'Earn 1 point per ₹100 spent'),
                      _howItWorksRow('🥉', 'Bronze: 0 – 499 points'),
                      _howItWorksRow('🥈', 'Silver: 500 – 1,999 points'),
                      _howItWorksRow('🥇', 'Gold: 2,000 – 4,999 points'),
                      _howItWorksRow('💎', 'Platinum: 5,000+ points'),
                      _howItWorksRow('🎁',
                          'Redeem points for discounts, cashback & gifts'),
                    ]),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadLoyaltyData() async {
    try {
      final pid = _party['id'] as String;
      final result = await SupabaseService.client
          .rpc('get_party_loyalty_dashboard', params: {'p_party_id': pid});
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result.first);
      }
      return null;
    } catch (e) {
      debugPrint('Loyalty load error: $e');
      return null;
    }
  }

  Future<void> _redeemReward(Map<String, dynamic> reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Redeem Reward'),
        content: Text(
            'Redeem "${reward['name']}" for ${reward['points_required']} points?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Redeem', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result =
          await SupabaseService.client.rpc('redeem_loyalty_reward', params: {
        'p_party_id': _party['id'],
        'p_reward_id': reward['id'],
      });

      if (result == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Redeemed "${reward['name']}" successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _loyaltyRefreshKey++);
          // Refresh loyalty tab
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Redemption failed: $result'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _loyaltyStat(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
    ]);
  }

  Widget _howItWorksRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: Colors.black87))),
      ]),
    );
  }
}
