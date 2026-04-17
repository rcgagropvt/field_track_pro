import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_shell.dart';

class VisitAnalyticsScreen extends StatefulWidget {
  const VisitAnalyticsScreen({super.key});
  @override
  State<VisitAnalyticsScreen> createState() => _VisitAnalyticsScreenState();
}

class _VisitAnalyticsScreenState extends State<VisitAnalyticsScreen> {
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _selectedEmployeeId;
  String _selectedEmployeeName = 'All Employees';
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadVisits();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final data = await SupabaseService.getAllEmployees();
    setState(() => _employees = data);
  }

  Future<void> _loadVisits() async {
    setState(() => _loading = true);
    try {
      final data =
          await SupabaseService.client.rpc('get_filtered_visits', params: {
        'p_user_id': _selectedEmployeeId,
        'p_start_date': DateFormat('yyyy-MM-dd').format(_range.start),
        'p_end_date': DateFormat('yyyy-MM-dd').format(_range.end),
      });
      setState(() {
        _visits = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVisits {
    if (_searchQuery.isEmpty) return _visits;
    final q = _searchQuery.toLowerCase();
    return _visits
        .where((v) =>
            (v['customer_name'] ?? '').toString().toLowerCase().contains(q) ||
            (v['employee_name'] ?? '').toString().toLowerCase().contains(q) ||
            (v['purpose'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue)),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() => _range = range);
      _loadVisits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = _filteredVisits;
    final totalDuration = visits.fold<int>(
        0, (s, v) => s + ((v['duration_minutes'] as int?) ?? 0));
    final avgDuration = visits.isNotEmpty ? totalDuration ~/ visits.length : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Visit Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Date Range',
              onPressed: _pickDateRange),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVisits),
        ],
      ),
      body: Column(children: [
        // Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(children: [
            // Search
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by customer, employee, purpose...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
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
            Row(children: [
              // Employee filter
              Expanded(
                  child: InkWell(
                onTap: _showEmployeePicker,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(_selectedEmployeeName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              // Date range chip
              InkWell(
                onTap: _pickDateRange,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.date_range, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                        '${DateFormat('dd MMM').format(_range.start)} - ${DateFormat('dd MMM').format(_range.end)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        // Summary KPIs
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _kpi('Total Visits', '${visits.length}', Colors.blue),
            _kvDivider(),
            _kpi('Avg Duration', '${avgDuration}m', Colors.orange),
            _kvDivider(),
            _kpi('Total Time', '${totalDuration ~/ 60}h ${totalDuration % 60}m',
                Colors.green),
            _kvDivider(),
            _kpi(
                'Customers',
                '${visits.map((v) => v['customer_name']).toSet().length}',
                Colors.purple),
            _kvDivider(),
            _kpi(
                'Geofence\nViolations',
                '${visits.where((v) => v['geofence_status'] == 'outside').length}',
                Colors.red),
          ]),
        ),
        // Visit list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : visits.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          const Icon(Icons.store_mall_directory_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No visits found',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                          TextButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedEmployeeId = null;
                                  _selectedEmployeeName = 'All Employees';
                                });
                                _loadVisits();
                              },
                              child: const Text('Clear filters')),
                        ]))
                  : RefreshIndicator(
                      onRefresh: _loadVisits,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _visitCard(visits[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _visitCard(Map<String, dynamic> v) {
    final checkIn = v['check_in_time'] != null
        ? DateTime.tryParse(v['check_in_time'].toString())
        : null;
    final checkOut = v['check_out_time'] != null
        ? DateTime.tryParse(v['check_out_time'].toString())
        : null;
    final duration = v['duration_minutes'] as int?;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showVisitDetail(v),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Geofence badge
            if (v['geofence_status'] == 'outside')
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    'Outside Geofence — ${v['geofence_distance'] != null ? '${(v['geofence_distance'] as num).toStringAsFixed(0)}m away' : 'distance unknown'}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red),
                  ),
                ]),
              ),

            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.store, color: Colors.blue, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(v['customer_name'] ?? 'Customer',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(v['employee_name'] ?? '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (checkIn != null)
                  Text(DateFormat('dd MMM').format(checkIn),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                if (duration != null)
                  Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${duration}m',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600))),
              ]),
            ]),
            if (v['purpose'] != null && v['purpose'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.notes, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(v['purpose'].toString(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87))),
                  ])),
            ],
            const SizedBox(height: 10),
            Row(children: [
              _timeChip(
                  Icons.login,
                  'In',
                  checkIn != null
                      ? DateFormat('hh:mm a').format(checkIn)
                      : '--',
                  Colors.green),
              const SizedBox(width: 8),
              _timeChip(
                  Icons.logout,
                  'Out',
                  checkOut != null
                      ? DateFormat('hh:mm a').format(checkOut)
                      : 'Ongoing',
                  checkOut != null ? Colors.red : Colors.orange),
              const Spacer(),
              if (v['latitude'] != null)
                TextButton.icon(
                  onPressed: () => _openMaps(v['latitude'], v['longitude']),
                  icon: const Icon(Icons.map, size: 14),
                  label: const Text('View Map', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, String time, Color color) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text('$label: $time',
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]));

  Widget _kpi(String label, String value, Color color) => Expanded(
          child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center),
      ]));

  Widget _kvDivider() =>
      Container(height: 30, width: 1, color: Colors.grey.shade200);

  void _showEmployeePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Filter by Employee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const Divider(height: 1),
        ListTile(
          leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 16,
              child: Icon(Icons.people, color: Colors.white, size: 16)),
          title: const Text('All Employees'),
          onTap: () {
            setState(() {
              _selectedEmployeeId = null;
              _selectedEmployeeName = 'All Employees';
            });
            Navigator.pop(context);
            _loadVisits();
          },
        ),
        ..._employees.map((e) => ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  radius: 16,
                  child: Text(
                      (e['full_name'] ?? 'U').toString()[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue))),
              title: Text(e['full_name'] ?? ''),
              subtitle: Text(e['department'] ?? '',
                  style: const TextStyle(fontSize: 11)),
              selected: _selectedEmployeeId == e['id'],
              onTap: () {
                setState(() {
                  _selectedEmployeeId = e['id'];
                  _selectedEmployeeName = e['full_name'] ?? '';
                });
                Navigator.pop(context);
                _loadVisits();
              },
            )),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _showVisitDetail(Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(v['customer_name'] ?? 'Visit Detail',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('By ${v['employee_name'] ?? ''}',
                style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            _detailRow(
                Icons.assignment, 'Purpose', v['purpose'] ?? 'Not specified'),
            _detailRow(
                Icons.login,
                'Check In',
                v['check_in_time'] != null
                    ? DateFormat('dd MMM yyyy, hh:mm a')
                        .format(DateTime.parse(v['check_in_time'].toString()))
                    : '--'),
            _detailRow(
                Icons.logout,
                'Check Out',
                v['check_out_time'] != null
                    ? DateFormat('dd MMM yyyy, hh:mm a')
                        .format(DateTime.parse(v['check_out_time'].toString()))
                    : 'Still ongoing'),
            _detailRow(
                Icons.timer,
                'Duration',
                v['duration_minutes'] != null
                    ? '${v['duration_minutes']} minutes'
                    : 'N/A'),
            if (v['geofence_status'] != null)
              _detailRow(
                v['geofence_status'] == 'outside'
                    ? Icons.location_off
                    : Icons.location_on,
                'Geofence',
                v['geofence_status'] == 'outside'
                    ? 'OUTSIDE — ${v['geofence_distance'] != null ? '${(v['geofence_distance'] as num).toStringAsFixed(0)}m from party' : 'distance unknown'}'
                    : v['geofence_status'] == 'inside'
                        ? 'Inside — ${v['geofence_distance'] != null ? '${(v['geofence_distance'] as num).toStringAsFixed(0)}m' : ''}'
                        : 'Not checked',
              ),
            if (v['notes'] != null && v['notes'].toString().isNotEmpty)
              _detailRow(Icons.notes, 'Notes', v['notes'].toString()),
            if (v['latitude'] != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openMaps(v['latitude'], v['longitude']);
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Open Location in Maps'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ])),
        ]),
      );

  void _openMaps(dynamic lat, dynamic lng) async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await canLaunchUrl(url)) return; // ✅ cleaner pattern
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
