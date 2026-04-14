import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:field_track_pro/core/services/supabase_service.dart';
import 'admin_shell.dart';

class ExpenseApprovalScreen extends StatefulWidget {
  const ExpenseApprovalScreen({super.key});
  @override
  State<ExpenseApprovalScreen> createState() => _ExpenseApprovalScreenState();
}

class _ExpenseApprovalScreenState extends State<ExpenseApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String _categoryFilter = 'All';
  String _sortBy = 'newest';
  Set<String> _selected = {};
  bool _bulkMode = false;
  double _pendingTotal = 0;

  final _categories = [
    'All',
    'Travel',
    'Food',
    'Accommodation',
    'Fuel',
    'Client Entertainment',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await SupabaseService.client
          .from('expenses')
          .select(
              '*, profiles!expenses_user_id_fkey(full_name, avatar_url, email)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final history = await SupabaseService.client
          .from('expenses')
          .select('*, profiles!expenses_user_id_fkey(full_name, avatar_url)')
          .neq('status', 'pending')
          .order('updated_at', ascending: false)
          .limit(50);
      setState(() {
        _pending = List<Map<String, dynamic>>.from(pending);
        _history = List<Map<String, dynamic>>.from(history);
        _pendingTotal = _pending.fold(
            0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast('Error loading expenses: $e', Colors.red);
    }
  }

  Future<void> _update(String id, String status) async {
    await SupabaseService.updateExpenseStatus(id, status);
    _toast(status == 'approved' ? '✅ Approved' : '❌ Rejected',
        status == 'approved' ? Colors.green : Colors.red);
    _load();
  }

  Future<void> _bulkAction(String status) async {
    if (_selected.isEmpty) return;
    for (final id in _selected) {
      await SupabaseService.updateExpenseStatus(id, status);
    }
    setState(() {
      _selected.clear();
      _bulkMode = false;
    });
    _toast(
        status == 'approved'
            ? '✅ ${_selected.length} expenses approved'
            : '❌ ${_selected.length} expenses rejected',
        Colors.green);
    _load();
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2)));
  }

  List<Map<String, dynamic>> get _filteredPending {
    var list = [..._pending];
    if (_categoryFilter != 'All')
      list = list.where((e) => e['category'] == _categoryFilter).toList();
    switch (_sortBy) {
      case 'highest':
        list.sort((a, b) =>
            ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0));
        break;
      case 'lowest':
        list.sort((a, b) =>
            ((a['amount'] as num?) ?? 0).compareTo((b['amount'] as num?) ?? 0));
        break;
      default:
        break; // newest already sorted by query
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Expense Approvals',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(
              '${_pending.length} pending · ₹${_pendingTotal.toStringAsFixed(0)} total',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Pending (${_pending.length})'),
              const Tab(text: 'History')
            ]),
        actions: [
          if (_bulkMode) ...[
            TextButton(
                onPressed: () => _bulkAction('approved'),
                child: const Text('Approve All',
                    style: TextStyle(color: Colors.green))),
            TextButton(
                onPressed: () => _bulkAction('rejected'),
                child: const Text('Reject All',
                    style: TextStyle(color: Colors.red))),
          ],
          IconButton(
            icon: Icon(_bulkMode ? Icons.close : Icons.checklist),
            tooltip: 'Bulk Select',
            onPressed: () => setState(() {
              _bulkMode = !_bulkMode;
              _selected.clear();
            }),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _pendingTab(),
              _historyTab(),
            ]),
    );
  }

  Widget _pendingTab() {
    final list = _filteredPending;
    return Column(children: [
      // Filter bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(
              child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _categories
                    .map((cat) => GestureDetector(
                          onTap: () => setState(() => _categoryFilter = cat),
                          child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: _categoryFilter == cat
                                      ? Colors.blue
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(cat,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _categoryFilter == cat
                                          ? Colors.white
                                          : Colors.grey.shade700))),
                        ))
                    .toList()),
          )),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            initialValue: _sortBy,
            icon: const Icon(Icons.sort, size: 20),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest First')),
              const PopupMenuItem(
                  value: 'highest', child: Text('Highest Amount')),
              const PopupMenuItem(
                  value: 'lowest', child: Text('Lowest Amount')),
            ],
          ),
        ]),
      ),
      // Summary strip
      if (_bulkMode && _selected.isNotEmpty)
        Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text('${_selected.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                  '₹${list.where((e) => _selected.contains(e['id'])).fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
            ])),
      // List
      Expanded(
        child: list.isEmpty
            ? const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.green),
                    SizedBox(height: 12),
                    Text('All caught up!',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ]))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _expenseCard(list[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _expenseCard(Map<String, dynamic> e) {
    final profile = e['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? 'Unknown';
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final isSelected = _selected.contains(e['id'] as String?);

    final catColors = {
      'Travel': Colors.blue,
      'Food': Colors.orange,
      'Accommodation': Colors.purple,
      'Fuel': Colors.teal,
      'Client Entertainment': Colors.pink,
      'Other': Colors.grey,
    };
    final catColor = catColors[e['category']] ?? Colors.grey;
    final date = e['created_at'] != null
        ? DateTime.tryParse(e['created_at'].toString())
        : null;

    return GestureDetector(
      onLongPress: () => setState(() {
        _bulkMode = true;
        _selected.add(e['id']);
      }),
      onTap: _bulkMode
          ? () => setState(() {
                if (isSelected)
                  _selected.remove(e['id']);
                else
                  _selected.add(e['id']);
              })
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              if (_bulkMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Checkbox(
                      value: isSelected,
                      onChanged: (v) => setState(() {
                            if (v!)
                              _selected.add(e['id']);
                            else
                              _selected.remove(e['id']);
                          })),
                ),
              CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(e['category'] ?? 'Other',
                              style: TextStyle(
                                  color: catColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      if (date != null) ...[
                        const SizedBox(width: 6),
                        Text('${date.day}/${date.month}/${date.year}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ]),
                  ])),
              Text('₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange)),
            ]),
          ),
          if (e['description'] != null &&
              e['description'].toString().isNotEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(e['description'].toString(),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87)))),
          // Receipt
          if (e['receipt_url'] != null)
            _receiptWidget(e['receipt_url'].toString()),
          // Action buttons
          if (!_bulkMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () => _update(e['id'].toString(), 'rejected'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                )),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _update(e['id'].toString(), 'approved'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                    )),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _receiptWidget(String url) {
    final isImage = url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.png') ||
        url.toLowerCase().contains('.webp');
    final isPdf = url.toLowerCase().contains('.pdf');

    if (isImage) {
      return GestureDetector(
        onTap: () => _showFullImage(url),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Stack(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(url,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        color: Colors.grey.shade100,
                        child: const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey))))),
            Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.zoom_in,
                        color: Colors.white, size: 16))),
          ]),
        ),
      );
    } else if (isPdf) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri))
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200)),
            child: const Row(children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Receipt PDF',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('Tap to open document',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
              Icon(Icons.open_in_new, color: Colors.red, size: 18),
            ]),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri))
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.attach_file, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(
                  child: Text('View Attachment',
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.w600))),
              Icon(Icons.open_in_new, color: Colors.blue, size: 16),
            ]),
          ),
        ),
      );
    }
  }

  void _showFullImage(String url) {
    showDialog(
        context: context,
        builder: (_) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(children: [
                SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: PhotoView(
                        imageProvider: NetworkImage(url),
                        minScale: PhotoViewComputedScale.contained,
                        backgroundDecoration:
                            const BoxDecoration(color: Colors.black))),
                Positioned(
                    top: 40,
                    right: 16,
                    child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context))),
              ]),
            ));
  }

  Widget _historyTab() {
    if (_history.isEmpty) return const Center(child: Text('No history yet'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = _history[i];
        final profile = e['profiles'] as Map<String, dynamic>?;
        final isApproved = e['status'] == 'approved';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
              ]),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color:
                        isApproved ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(isApproved ? Icons.check_circle : Icons.cancel,
                    color: isApproved ? Colors.green : Colors.red, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(profile?['full_name'] ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                      '${e['category'] ?? 'Other'} · ${e['updated_at']?.toString().substring(0, 10) ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${(e['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(isApproved ? 'Approved' : 'Rejected',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isApproved ? Colors.green : Colors.red))),
            ]),
          ]),
        );
      },
    );
  }
}
