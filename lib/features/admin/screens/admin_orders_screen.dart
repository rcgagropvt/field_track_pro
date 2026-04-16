import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'package:vartmaan_pulse/core/constants/app_colors.dart';
import '../../orders/screens/order_detail_screen.dart';
import 'admin_shell.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String _statusFilter = 'all';
  String? _selectedEmployeeId;
  String _selectedEmployeeName = 'All Reps';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final data = await SupabaseService.getAllEmployees();
    if (mounted) setState(() => _employees = data);
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      // Admin reads all orders via RLS policy
      var query = SupabaseService.client
          .from('orders')
          .select('*, profiles!orders_user_id_fkey(full_name)');

      if (_selectedEmployeeId != null) {
        query = query.eq('user_id', _selectedEmployeeId!);
      }
      if (_statusFilter != 'all') {
        query = query.eq('status', _statusFilter);
      }

      final data = await query.order('created_at', ascending: false).limit(100);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _applySearch();
          _loading = false;
        });
      }
    } catch (e) {
      // Fallback: if join fails, load without profile join
      try {
        final data = await SupabaseService.client
            .from('orders')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        if (mounted) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(data);
            _applySearch();
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _orders.where((o) {
      if (q.isEmpty) return true;
      return (o['order_number'] ?? '').toString().toLowerCase().contains(q) ||
          (o['party_name'] ?? '').toString().toLowerCase().contains(q) ||
          (o['profiles']?['full_name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  // Summary calculations
  double get _totalRevenue =>
      _filtered.fold(0.0, (s, o) => s + ((o['total_amount'] as num?) ?? 0).toDouble());

  int get _placedCount => _filtered.where((o) => o['status'] == 'placed').length;
  int get _confirmedCount => _filtered.where((o) => o['status'] == 'confirmed').length;
  int get _deliveredCount => _filtered.where((o) => o['status'] == 'delivered').length;

  Color _statusColor(String status) {
    switch (status) {
      case 'placed': return AppColors.info;
      case 'confirmed': return AppColors.leadQualified;
      case 'dispatched': return AppColors.warning;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textTertiary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'placed': return Icons.receipt_rounded;
      case 'confirmed': return Icons.check_circle_outline;
      case 'dispatched': return Icons.local_shipping_rounded;
      case 'delivered': return Icons.done_all_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.receipt_rounded;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus == 'confirmed') updateData['confirmed_at'] = DateTime.now().toIso8601String();
      if (newStatus == 'dispatched') updateData['dispatched_at'] = DateTime.now().toIso8601String();
      if (newStatus == 'delivered') {
        updateData['delivered_at'] = DateTime.now().toIso8601String();
        updateData['payment_status'] = 'paid';
      }
      if (newStatus == 'cancelled') updateData['cancelled_at'] = DateTime.now().toIso8601String();

      await SupabaseService.client.from('orders').update(updateData).eq('id', orderId);
      _showSnack('Order updated to ${newStatus.toUpperCase()}');
      _loadOrders();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('All Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() => _applySearch()),
                  decoration: InputDecoration(
                    hintText: 'Search order #, party, rep...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _applySearch());
                            })
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Employee filter
                    Expanded(
                      child: InkWell(
                        onTap: _showEmployeePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(child: Text(_selectedEmployeeName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                              const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Status filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        items: ['all', 'placed', 'confirmed', 'dispatched', 'delivered', 'cancelled']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _statusFilter = v ?? 'all');
                          _loadOrders();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // KPIs
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _kpi('Total', '${_filtered.length}', Colors.blue),
                _divider(),
                _kpi('Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', AppColors.primary),
                _divider(),
                _kpi('Placed', '$_placedCount', AppColors.info),
                _divider(),
                _kpi('Delivered', '$_deliveredCount', AppColors.success),
              ],
            ),
          ),

          // Order list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No orders found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildOrderCard(_filtered[i], i),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final status = order['status'] ?? 'placed';
    final repName = order['profiles']?['full_name'] ?? 'Unknown Rep';
    final createdAt = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])));
          _loadOrders();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: order # + status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon(status), color: _statusColor(status), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order['order_number'] ?? 'N/A',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(order['party_name'] ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status),
                        )),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rep name + date
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(repName,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(
                    createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toLocal()) : '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Amount + payment + actions
              Row(
                children: [
                  Text('₹${(order['total_amount'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (order['payment_mode'] ?? 'credit').toString().toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.warning),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (order['payment_status'] == 'paid' ? AppColors.successLight : AppColors.errorLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (order['payment_status'] ?? 'unpaid').toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: order['payment_status'] == 'paid' ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Quick status update
                  if (status != 'delivered' && status != 'cancelled')
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (newStatus) => _updateOrderStatus(order['id'], newStatus),
                      itemBuilder: (_) {
                        final options = <PopupMenuEntry<String>>[];
                        if (status == 'placed') {
                          options.add(const PopupMenuItem(value: 'confirmed', child: Text('✅ Confirm')));
                        }
                        if (status == 'placed' || status == 'confirmed') {
                          options.add(const PopupMenuItem(value: 'dispatched', child: Text('🚚 Dispatch')));
                        }
                        if (status != 'delivered') {
                          options.add(const PopupMenuItem(value: 'delivered', child: Text('📦 Delivered')));
                        }
                        options.add(const PopupMenuItem(value: 'cancelled', child: Text('❌ Cancel')));
                        return options;
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn(duration: 250.ms).slideX(begin: 0.03);
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _divider() => Container(height: 30, width: 1, color: Colors.grey.shade200);

  void _showEmployeePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Filter by Sales Rep',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const Divider(height: 1),
        ListTile(
          leading: const CircleAvatar(
              backgroundColor: Colors.blue, radius: 16,
              child: Icon(Icons.people, color: Colors.white, size: 16)),
          title: const Text('All Reps'),
          onTap: () {
            setState(() {
              _selectedEmployeeId = null;
              _selectedEmployeeName = 'All Reps';
            });
            Navigator.pop(context);
            _loadOrders();
          },
        ),
        ..._employees.map((e) => ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50, radius: 16,
                  child: Text((e['full_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
              title: Text(e['full_name'] ?? ''),
              selected: _selectedEmployeeId == e['id'],
              onTap: () {
                setState(() {
                  _selectedEmployeeId = e['id'];
                  _selectedEmployeeName = e['full_name'] ?? '';
                });
                Navigator.pop(context);
                _loadOrders();
              },
            )),
        const SizedBox(height: 16),
      ]),
    );
  }
}


