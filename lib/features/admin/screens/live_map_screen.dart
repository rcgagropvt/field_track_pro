import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'employee_detail_screen.dart';
import 'admin_shell.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapCtrl = MapController();
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _employees = [];
  Map<String, List<LatLng>> _trails = {};
  bool _loading = true;
  bool _showTrails = true;
  String? _selectedEmployeeId;
  String _selectedEmployeeName = 'All Employees';

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadLocations();
  }

  Future<void> _loadEmployees() async {
    final data = await SupabaseService.getAllEmployees();
    setState(() => _employees = data);
  }

  Future<void> _loadLocations() async {
    setState(() => _loading = true);
    try {
      final List locs = await SupabaseService.getAllEmployeeLocations();
      var locations = List<Map<String, dynamic>>.from(locs);
      if (_selectedEmployeeId != null) {
        locations = locations
            .where((l) => l['user_id'] == _selectedEmployeeId)
            .toList();
      }
      // Load today's trail for each visible employee
      final trails = <String, List<LatLng>>{};
      for (final loc in locations) {
        final uid = loc['user_id']?.toString();
        if (uid == null) continue;
        try {
          final history = await SupabaseService.client
              .from('location_tracks')
              .select('latitude, longitude, recorded_at')
              .eq('user_id', uid)
              .gte('recorded_at',
                  DateTime.now().toIso8601String().substring(0, 10))
              .order('recorded_at')
              .limit(100);
          trails[uid] = (history as List)
              .map((h) => LatLng((h['latitude'] as num).toDouble(),
                  (h['longitude'] as num).toDouble()))
              .toList();
        } catch (_) {}
      }
      setState(() {
        _locations = locations;
        _trails = trails;
        _loading = false;
      });
      if (locations.isNotEmpty) {
        final first = locations.first;
        _mapCtrl.move(
            LatLng((first['latitude'] as num).toDouble(),
                (first['longitude'] as num).toDouble()),
            12);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _locations.where((l) => l['is_online'] == true).length;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Live Field Map',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text('$online online · ${_locations.length} total',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
              icon: Icon(_showTrails ? Icons.timeline : Icons.timeline_outlined,
                  color: Colors.blue),
              tooltip: 'Toggle Trails',
              onPressed: () => setState(() => _showTrails = !_showTrails)),
          IconButton(
              icon: const Icon(Icons.map_outlined, color: Colors.green),
              tooltip: 'Open all in Google Maps',
              onPressed: () {
                if (_locations.isEmpty) return;
                final waypoints = _locations.map((l) {
                  final lat = (l['latitude'] as num).toDouble();
                  final lng = (l['longitude'] as num).toDouble();
                  return '$lat,$lng';
                }).toList();
                final first = waypoints.removeAt(0);
                final url = waypoints.isEmpty
                    ? 'https://www.google.com/maps/search/?api=1&query=$first'
                    : 'https://www.google.com/maps/dir/$first/${waypoints.join('/')}';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadLocations),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: const MapOptions(
              initialCenter: LatLng(20.5937, 78.9629), initialZoom: 5),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fieldtrackpro.field_track_pro'),
            // Movement trails (polylines)
            if (_showTrails)
              PolylineLayer(
                  polylines: _trails.entries
                      .where((entry) => entry.value.length >= 2)
                      .map((entry) {
                final isOnline = _locations.any(
                    (l) => l['user_id'] == entry.key && l['is_online'] == true);
                return Polyline(
                  points: entry.value,
                  strokeWidth: 2.5,
                  color: isOnline
                      ? Colors.green.withOpacity(0.7)
                      : Colors.grey.withOpacity(0.5),
                  pattern: isOnline
                      ? const StrokePattern.solid()
                      : const StrokePattern.dotted(),
                );
              }).toList()),
            // Employee markers
            MarkerLayer(
                markers: _locations.map((loc) {
              final isOnline = loc['is_online'] ?? false;
              final lat = (loc['latitude'] as num).toDouble();
              final lng = (loc['longitude'] as num).toDouble();
              final name = (loc['full_name'] ?? 'Employee').toString();
              return Marker(
                point: LatLng(lat, lng),
                width: 170,
                height: 80,
                child: GestureDetector(
                  onTap: () => _showEmployeePopup(loc),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                isOnline ? Colors.green : Colors.grey.shade400,
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                isOnline ? Colors.green : Colors.grey,
                            child: Text(name[0].toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(width: 5),
                        Flexible(
                            child: Text(name.split(' ').first,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle)),
                      ]),
                    ),
                    ClipPath(
                        clipper: _TriangleClipper(),
                        child: Container(
                            width: 12,
                            height: 7,
                            color: isOnline
                                ? Colors.green
                                : Colors.grey.shade400)),
                  ]),
                ),
              );
            }).toList()),
          ],
        ),

        // Loading
        if (_loading)
          Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator())),

        // Top filter bar
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
                ]),
            child: InkWell(
              onTap: _showEmployeePicker,
              child: Row(children: [
                const Icon(Icons.filter_list, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_selectedEmployeeName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500))),
                if (_selectedEmployeeId != null)
                  IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _selectedEmployeeId = null;
                          _selectedEmployeeName = 'All Employees';
                        });
                        _loadLocations();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ]),
            ),
          ),
        ),

        // Bottom legend + employee cards
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Employee horizontal scroll
            if (_locations.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _locations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _employeeMiniCard(_locations[i]),
                ),
              ),
            // Legend
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                _legendItem(Colors.green, 'Online (last 10min)'),
                const SizedBox(width: 16),
                _legendItem(Colors.grey, 'Offline'),
                const Spacer(),
                if (_showTrails) _legendItem(Colors.blue, 'Today\'s Trail'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _employeeMiniCard(Map<String, dynamic> loc) {
    final isOnline = loc['is_online'] ?? false;
    final name = (loc['full_name'] ?? 'Employee').toString();
    final employee = _employees.firstWhere((e) => e['id'] == loc['user_id'],
        orElse: () => {});

    return GestureDetector(
      onTap: () {
        final lat = (loc['latitude'] as num).toDouble();
        final lng = (loc['longitude'] as num).toDouble();
        _mapCtrl.move(LatLng(lat, lng), 15);
        _showEmployeePopup(loc);
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOnline ? Colors.green.shade200 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)
            ]),
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.shade50,
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue))),
            const SizedBox(width: 6),
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 6),
          Text(name.split(' ').first,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis),
          Text(isOnline ? 'Online now' : 'Offline',
              style: TextStyle(
                  fontSize: 10, color: isOnline ? Colors.green : Colors.grey)),
          if (employee['department'] != null)
            Text(employee['department'].toString(),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);

  void _showEmployeePopup(Map<String, dynamic> loc) {
    final isOnline = loc['is_online'] ?? false;
    final name = loc['full_name'] ?? 'Employee';
    final employee = _employees.firstWhere((e) => e['id'] == loc['user_id'],
        orElse: () => {});

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade100,
                child: Text(name.toString()[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue))),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name.toString(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(employee['email'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle)),
                    Text(isOnline ? 'Active in field now' : 'Last seen today',
                        style: TextStyle(
                            fontSize: 12,
                            color: isOnline ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500)),
                  ]),
                ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (employee.isNotEmpty) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              EmployeeDetailScreen(employee: employee)));
                }
              },
              icon: const Icon(Icons.person, size: 16),
              label: const Text('Profile'),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final lat = (loc['latitude'] as num).toDouble();
                final lng = (loc['longitude'] as num).toDouble();
                final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.map, size: 16, color: Colors.green),
              label: const Text('Google Maps',
                  style: TextStyle(color: Colors.green)),
            )),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final lat = (loc['latitude'] as num).toDouble();
                final lng = (loc['longitude'] as num).toDouble();
                _mapCtrl.move(LatLng(lat, lng), 16);
              },
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('Center Map'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ),
          // ── Open Trail in Google Maps ──
          if (_trails[loc['user_id']]?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final trail = _trails[loc['user_id']]!;
                    final step = (trail.length / 23).ceil().clamp(1, 100);
                    final points = <String>[];
                    for (var i = 0; i < trail.length; i += step) {
                      points.add('${trail[i].latitude},${trail[i].longitude}');
                    }
                    final last = trail.last;
                    final lastStr = '${last.latitude},${last.longitude}';
                    if (points.last != lastStr) points.add(lastStr);
                    final origin = points.removeAt(0);
                    final dest = points.removeLast();
                    final wp = points.isNotEmpty
                        ? '&waypoints=${points.join('|')}'
                        : '';
                    final url =
                        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest$wp&travelmode=driving';
                    launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.route, size: 16, color: Colors.orange),
                  label: Text(
                      "Open Today's Trail (${_trails[loc['user_id']]!.length} points)",
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showEmployeePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Filter Map',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text('Show All Employees'),
            onTap: () {
              setState(() {
                _selectedEmployeeId = null;
                _selectedEmployeeName = 'All Employees';
              });
              Navigator.pop(context);
              _loadLocations();
            }),
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
              selectedTileColor: Colors.blue.shade50,
              onTap: () {
                setState(() {
                  _selectedEmployeeId = e['id'];
                  _selectedEmployeeName = e['full_name'] ?? '';
                });
                Navigator.pop(context);
                _loadLocations();
              },
            )),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _TriangleClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}
