import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:field_track_pro/core/services/supabase_service.dart';
import 'package:field_track_pro/core/constants/app_colors.dart';
import '../../orders/screens/order_detail_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  const EmployeeDetailScreen({super.key, required this.employee});
  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  // Filters
  String _visitStatusFilter = 'all';
  String _attendanceFilter = 'all';
  String _orderStatusFilter = 'all';
  String _leadStatusFilter = 'all';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = widget.employee['id'];
    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('attendance')
            .select()
            .eq('user_id', id)
            .order('date', ascending: false)
            .limit(60),
        SupabaseService.client
            .from('visits')
            .select()
            .eq('user_id', id)
            .order('created_at', ascending: false)
            .limit(60),
        SupabaseService.client
            .from('leads')
            .select()
            .eq('user_id', id)
            .order('created_at', ascending: false)
            .limit(30),
        SupabaseService.client
            .from('orders')
            .select()
            .eq('user_id', id)
            .order('created_at', ascending: false)
            .limit(30),
      ]);
      if (mounted) {
        setState(() {
          _attendance = List<Map<String, dynamic>>.from(results[0]);
          _visits = List<Map<String, dynamic>>.from(results[1]);
          _leads = List<Map<String, dynamic>>.from(results[2]);
          _orders = List<Map<String, dynamic>>.from(results[3]);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── FILTERED LISTS ──
  List<Map<String, dynamic>> get _filteredVisits {
    return _visits.where((v) {
      if (_visitStatusFilter != 'all' && v['status'] != _visitStatusFilter)
        return false;
      if (_dateRange != null && v['check_in_time'] != null) {
        final d = DateTime.tryParse(v['check_in_time']);
        if (d != null &&
            (d.isBefore(_dateRange!.start) ||
                d.isAfter(_dateRange!.end.add(const Duration(days: 1)))))
          return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAttendance {
    return _attendance.where((a) {
      if (_attendanceFilter == 'present' && a['status'] != 'present')
        return false;
      if (_attendanceFilter == 'absent' && a['status'] != 'absent')
        return false;
      if (_dateRange != null && a['date'] != null) {
        final d = DateTime.tryParse(a['date']);
        if (d != null &&
            (d.isBefore(_dateRange!.start) ||
                d.isAfter(_dateRange!.end.add(const Duration(days: 1)))))
          return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      if (_orderStatusFilter != 'all' && o['status'] != _orderStatusFilter)
        return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredLeads {
    return _leads.where((l) {
      if (_leadStatusFilter != 'all' && l['status'] != _leadStatusFilter)
        return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    return Scaffold(
      appBar: AppBar(
        title: Text(e['full_name'] ?? 'Employee Detail'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Date Filter',
            onPressed: _pickDateRange,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Attendance (${_filteredAttendance.length})'),
            Tab(text: 'Visits (${_filteredVisits.length})'),
            Tab(text: 'Orders (${_filteredOrders.length})'),
            Tab(text: 'Leads (${_filteredLeads.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildProfileHeader(e),
                _buildStatsSummary(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAttendanceTab(),
                      _buildVisitsTab(),
                      _buildOrdersTab(),
                      _buildLeadsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── PROFILE HEADER ──
  Widget _buildProfileHeader(Map<String, dynamic> e) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primarySurface,
            backgroundImage:
                e['avatar_url'] != null ? NetworkImage(e['avatar_url']) : null,
            child: e['avatar_url'] == null
                ? Text((e['full_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['full_name'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(e['email'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                if (e['phone'] != null)
                  Text(e['phone'],
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  _chip(e['role'] ?? 'employee', AppColors.primary),
                  const SizedBox(width: 6),
                  _chip(
                      (e['is_active'] ?? true) ? 'Active' : 'Inactive',
                      (e['is_active'] ?? true)
                          ? AppColors.success
                          : AppColors.error),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STATS SUMMARY ──
  Widget _buildStatsSummary() {
    final totalOrderValue = _orders.fold<double>(
        0, (s, o) => s + ((o['total_amount'] as num?) ?? 0).toDouble());
    final completedVisits =
        _visits.where((v) => v['status'] == 'completed').length;
    final totalCollection = _visits.fold<double>(
        0, (s, v) => s + ((v['payment_collected'] as num?) ?? 0).toDouble());
    final presentDays =
        _attendance.where((a) => a['status'] == 'present').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          _miniStat('Present', '$presentDays', AppColors.success),
          _miniStat('Visits', '$completedVisits', AppColors.info),
          _miniStat('Orders', '₹${totalOrderValue.toStringAsFixed(0)}',
              AppColors.primary),
          _miniStat('Collected', '₹${totalCollection.toStringAsFixed(0)}',
              AppColors.warning),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 8, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ATTENDANCE TAB
  // ════════════════════════════════════════════════════════
  Widget _buildAttendanceTab() {
    final list = _filteredAttendance;
    return Column(
      children: [
        _buildFilterBar(
          filters: ['all', 'present', 'absent'],
          selected: _attendanceFilter,
          onChanged: (v) => setState(() => _attendanceFilter = v),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyTab('No attendance records', Icons.event_available)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final checkIn = a['check_in_time'];
                      final checkOut = a['check_out_time'];
                      final isPresent = a['status'] == 'present';
                      return GestureDetector(
                        onTap: () => _showAttendanceDetail(a),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isPresent
                                    ? AppColors.successLight
                                    : AppColors.errorLight,
                                child: Icon(
                                    isPresent ? Icons.check : Icons.close,
                                    color: isPresent
                                        ? AppColors.success
                                        : AppColors.error,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['date'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    Row(
                                      children: [
                                        Icon(Icons.login,
                                            size: 11,
                                            color: Colors.green.shade400),
                                        const SizedBox(width: 3),
                                        Text(_formatTime(checkIn),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                        const SizedBox(width: 10),
                                        Icon(Icons.logout,
                                            size: 11,
                                            color: Colors.red.shade400),
                                        const SizedBox(width: 3),
                                        Text(_formatTime(checkOut),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    if (a['check_in_address'] != null)
                                      Text(a['check_in_address'],
                                          style: const TextStyle(
                                              fontSize: 10, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  _chip(
                                      a['status'] ?? 'N/A',
                                      isPresent
                                          ? AppColors.success
                                          : AppColors.error),
                                  if (a['check_in_selfie'] != null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(Icons.camera_alt,
                                          size: 14, color: AppColors.info),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showAttendanceDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 16),
              const Text('Attendance Detail',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(a['date'] ?? '', style: const TextStyle(color: Colors.grey)),
              const Divider(height: 24),
              _detailRow(
                  Icons.login, 'Check-In', _formatTime(a['check_in_time'])),
              _detailRow(
                  Icons.logout, 'Check-Out', _formatTime(a['check_out_time'])),
              _detailRow(Icons.badge, 'Status',
                  (a['status'] ?? 'N/A').toString().toUpperCase()),
              if (a['check_in_address'] != null)
                _detailRow(Icons.location_on, 'Check-In Location',
                    a['check_in_address']),
              if (a['check_out_address'] != null)
                _detailRow(Icons.location_off, 'Check-Out Location',
                    a['check_out_address']),
              if (a['check_in_lat'] != null)
                _gpsRow('Check-In GPS', a['check_in_lat'], a['check_in_lng']),
              if (a['check_out_lat'] != null)
                _gpsRow(
                    'Check-Out GPS', a['check_out_lat'], a['check_out_lng']),
              if (a['check_in_selfie'] != null ||
                  a['check_out_selfie'] != null) ...[
                const SizedBox(height: 16),
                const Text('Selfies',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (a['check_in_selfie'] != null)
                      _photoThumbnail('Check-In', a['check_in_selfie']),
                    if (a['check_in_selfie'] != null &&
                        a['check_out_selfie'] != null)
                      const SizedBox(width: 12),
                    if (a['check_out_selfie'] != null)
                      _photoThumbnail('Check-Out', a['check_out_selfie']),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // VISITS TAB
  // ════════════════════════════════════════════════════════
  Widget _buildVisitsTab() {
    final list = _filteredVisits;
    return Column(
      children: [
        _buildFilterBar(
          filters: ['all', 'completed', 'in_progress', 'active'],
          selected: _visitStatusFilter,
          onChanged: (v) => setState(() => _visitStatusFilter = v),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyTab('No visits found', Icons.place_rounded)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final v = list[i];
                      final status = v['status'] ?? '';
                      final orderVal =
                          (v['order_value'] as num?)?.toDouble() ?? 0;
                      final duration = v['duration_minutes'];
                      final partyName = v['party_name'] ?? 'Unknown';

                      return GestureDetector(
                        onTap: () => _showVisitDetail(v),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: status == 'completed'
                                          ? AppColors.successLight
                                          : AppColors.warningLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      status == 'completed'
                                          ? Icons.check_circle
                                          : Icons.hourglass_top,
                                      color: status == 'completed'
                                          ? AppColors.success
                                          : AppColors.warning,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(partyName,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        if (v['party_address'] != null)
                                          Text(v['party_address'],
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_formatDate(v['check_in_time']),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      if (duration != null)
                                        _chip('${duration}m', AppColors.info),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right,
                                      size: 16, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (v['purpose'] != null)
                                    _chip(
                                        v['purpose']
                                            .toString()
                                            .replaceAll('_', ' '),
                                        AppColors.primary),
                                  if (v['outcome'] != null)
                                    _chip(
                                        v['outcome']
                                            .toString()
                                            .replaceAll('_', ' '),
                                        AppColors.success),
                                  _chip(
                                      status,
                                      status == 'completed'
                                          ? AppColors.success
                                          : AppColors.warning),
                                  if (orderVal > 0)
                                    _chip('₹${orderVal.toStringAsFixed(0)}',
                                        AppColors.primary),
                                  if (v['photos'] != null &&
                                      (v['photos'] as List).isNotEmpty)
                                    _chip(
                                        '${(v['photos'] as List).length} photos',
                                        AppColors.info),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showVisitDetail(Map<String, dynamic> v) {
    final photos =
        v['photos'] != null ? List<String>.from(v['photos']) : <String>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 16),

              // Header
              Text(v['party_name'] ?? 'Visit Detail',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (v['party_address'] != null)
                Text(v['party_address'],
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 24),

              // Status + Purpose + Outcome
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (v['status'] != null)
                  _tagChip('Status', v['status'], AppColors.primary),
                if (v['purpose'] != null)
                  _tagChip('Purpose', v['purpose'], AppColors.info),
                if (v['outcome'] != null)
                  _tagChip('Outcome', v['outcome'], AppColors.success),
                if (v['payment_mode'] != null && v['payment_mode'] != 'none')
                  _tagChip('Payment', v['payment_mode'], AppColors.warning),
              ]),

              const SizedBox(height: 16),

              // Timing
              const Text('Timing',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _detailRow(
                  Icons.login, 'Check-In', _formatDateTime(v['check_in_time'])),
              _detailRow(Icons.logout, 'Check-Out',
                  _formatDateTime(v['check_out_time'])),
              _detailRow(
                  Icons.timer,
                  'Duration',
                  v['duration_minutes'] != null
                      ? '${v['duration_minutes']} minutes'
                      : 'N/A'),

              // GPS
              const SizedBox(height: 12),
              const Text('Location',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (v['check_in_lat'] != null)
                _gpsRow('Check-In GPS', v['check_in_lat'], v['check_in_lng']),
              if (v['check_out_lat'] != null)
                _gpsRow(
                    'Check-Out GPS', v['check_out_lat'], v['check_out_lng']),

              // Order + Payment
              if ((v['order_value'] as num?) != null &&
                  (v['order_value'] as num) > 0) ...[
                const SizedBox(height: 12),
                const Text('Order & Payment',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _detailRow(Icons.shopping_cart, 'Order Value',
                    '₹${(v['order_value'] as num).toStringAsFixed(2)}'),
                _detailRow(Icons.payments, 'Payment Collected',
                    '₹${((v['payment_collected'] as num?) ?? 0).toStringAsFixed(2)}'),
              ],

              // Rating
              if (v['visit_rating'] != null &&
                  (v['visit_rating'] as int) > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Rating: ',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    ...List.generate(
                        5,
                        (s) => Icon(
                              s < (v['visit_rating'] as int)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.warning,
                              size: 20,
                            )),
                  ],
                ),
              ],

              // Notes + Feedback
              if (v['discussion_notes'] != null &&
                  v['discussion_notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Discussion Notes',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(v['discussion_notes'],
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
              if (v['feedback'] != null &&
                  v['feedback'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Dealer Feedback',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8)),
                  child:
                      Text(v['feedback'], style: const TextStyle(fontSize: 13)),
                ),
              ],

              // Selfies
              if (v['check_in_selfie'] != null ||
                  v['check_out_selfie'] != null) ...[
                const SizedBox(height: 16),
                const Text('Selfies',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  if (v['check_in_selfie'] != null)
                    _photoThumbnail('Check-In', v['check_in_selfie']),
                  if (v['check_in_selfie'] != null &&
                      v['check_out_selfie'] != null)
                    const SizedBox(width: 12),
                  if (v['check_out_selfie'] != null)
                    _photoThumbnail('Check-Out', v['check_out_selfie']),
                ]),
              ],

              // Proof Photos
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Proof Photos (${photos.length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photos
                      .map((url) => GestureDetector(
                            onTap: () => _openPhoto(url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                    width: 80,
                                    height: 80,
                                    color: AppColors.background,
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                                errorWidget: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: AppColors.errorLight,
                                    child: const Icon(Icons.broken_image,
                                        color: AppColors.error)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ORDERS TAB
  // ════════════════════════════════════════════════════════
  Widget _buildOrdersTab() {
    final list = _filteredOrders;
    return Column(
      children: [
        _buildFilterBar(
          filters: [
            'all',
            'placed',
            'confirmed',
            'dispatched',
            'delivered',
            'cancelled'
          ],
          selected: _orderStatusFilter,
          onChanged: (v) => setState(() => _orderStatusFilter = v),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyTab('No orders placed', Icons.receipt_long_rounded)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final o = list[i];
                      final status = o['status'] ?? 'placed';
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailScreen(orderId: o['id'])));
                          _load();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.receipt_rounded,
                                    color: AppColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Text(o['order_number'] ?? 'N/A',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const Spacer(),
                                _chip(status, _statusColor(status)),
                              ]),
                              const SizedBox(height: 6),
                              Text(o['party_name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Text(
                                    '₹${(o['total_amount'] ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                                const SizedBox(width: 8),
                                _chip(
                                    (o['payment_mode'] ?? 'credit')
                                        .toString()
                                        .toUpperCase(),
                                    AppColors.warning),
                                const Spacer(),
                                Text(_formatDate(o['created_at']),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    size: 16, color: Colors.grey),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // LEADS TAB
  // ════════════════════════════════════════════════════════
  Widget _buildLeadsTab() {
    final list = _filteredLeads;
    return Column(
      children: [
        _buildFilterBar(
          filters: [
            'all',
            'new',
            'contacted',
            'qualified',
            'proposal',
            'won',
            'lost'
          ],
          selected: _leadStatusFilter,
          onChanged: (v) => setState(() => _leadStatusFilter = v),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyTab('No leads found', Icons.person_add_rounded)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final l = list[i];
                      final status = l['status'] ?? 'new';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.leadNew.withValues(alpha: 0.1),
                            child: const Icon(Icons.person_add,
                                color: AppColors.leadNew, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l['name'] ?? l['company_name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(l['company'] ?? l['contact_person'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                if (l['estimated_value'] != null)
                                  Text('₹${l['estimated_value']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          _chip(status, _leadColor(status)),
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ════════════════════════════════════════════════════════

  Widget _buildFilterBar(
      {required List<String> filters,
      required String selected,
      required ValueChanged<String> onChanged}) {
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: filters.map((f) {
          final isSelected = selected == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(f.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.white : AppColors.primary)),
              selected: isSelected,
              onSelected: (_) => onChanged(f),
              backgroundColor: AppColors.primarySurface,
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.white,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  Widget _sheetHandle() => Center(
        child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
      );

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _gpsRow(String label, dynamic lat, dynamic lng) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        const Icon(Icons.gps_fixed, size: 14, color: AppColors.info),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text('$lat, $lng',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final url = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
            if (await canLaunchUrl(url))
              await launchUrl(url, mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(4)),
            child: const Text('Open Map',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info)),
          ),
        ),
      ]),
    );
  }

  Widget _photoThumbnail(String label, String url) {
    return GestureDetector(
      onTap: () => _openPhoto(url),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(width: 80, height: 80, color: AppColors.background),
              errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.errorLight,
                  child:
                      const Icon(Icons.broken_image, color: AppColors.error)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _tagChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(
              text: '$label: ', style: TextStyle(fontSize: 10, color: color)),
          TextSpan(
              text: value.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  void _openPhoto(String url) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: const Text('Photo')),
            body: PhotoView(imageProvider: CachedNetworkImageProvider(url)),
          ),
        ));
  }

  Widget _emptyTab(String msg, IconData icon) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ]),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );

  String _formatTime(dynamic time) {
    if (time == null) return '--';
    try {
      return DateFormat('hh:mm a')
          .format(DateTime.parse(time.toString()).toLocal());
    } catch (_) {
      return time.toString();
    }
  }

  String _formatDateTime(dynamic time) {
    if (time == null) return '--';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a')
          .format(DateTime.parse(time.toString()).toLocal());
    } catch (_) {
      return time.toString();
    }
  }

  String _formatDate(dynamic time) {
    if (time == null) return '';
    try {
      return DateFormat('dd MMM')
          .format(DateTime.parse(time.toString()).toLocal());
    } catch (_) {
      return '';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'placed':
        return AppColors.info;
      case 'confirmed':
        return AppColors.leadQualified;
      case 'dispatched':
        return AppColors.warning;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  Color _leadColor(String s) {
    switch (s) {
      case 'new':
        return AppColors.leadNew;
      case 'contacted':
        return AppColors.leadContacted;
      case 'qualified':
        return AppColors.leadQualified;
      case 'proposal':
        return AppColors.leadProposal;
      case 'negotiation':
        return AppColors.leadNegotiation;
      case 'won':
      case 'converted':
        return AppColors.leadWon;
      case 'lost':
        return AppColors.leadLost;
      default:
        return AppColors.textTertiary;
    }
  }
}
