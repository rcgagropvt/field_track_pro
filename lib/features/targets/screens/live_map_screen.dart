import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapCtrl = MapController();
  List<Map<String, dynamic>> _employees = [];
  Map<String, Map<String, dynamic>> _locations = {};
  Map<String, dynamic>? _selectedEmployee;
  bool _loading = true;
  RealtimeChannel? _channel;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final emps = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('role', 'employee')
          .eq('is_active', true);

      // Get latest location for each employee
      for (final emp in emps as List) {
        final uid = emp['id'] as String;
        final locs = await SupabaseService.client
            .from('location_logs')
            .select('latitude, longitude, created_at, battery_level, accuracy')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(1);

        if ((locs as List).isNotEmpty) {
          _locations[uid] = locs.first;
        }
      }

      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(emps);
          _loading = false;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('LiveMap load error: \$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.client
        .channel('location_logs_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'location_logs',
          callback: (payload) {
            final data = payload.newRecord;
            final uid = data['user_id'] as String?;
            if (uid != null && mounted) {
              setState(() {
                _locations[uid] = data;
                _lastRefresh = DateTime.now();
              });
              // If this employee is selected, pan map to them
              if (_selectedEmployee?['id'] == uid) {
                final lat = (data['latitude'] as num?)?.toDouble();
                final lng = (data['longitude'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  _mapCtrl.move(LatLng(lat, lng), _mapCtrl.camera.zoom);
                }
              }
            }
          },
        )
        .subscribe();
  }

  String _timeAgo(String? isoString) {
    if (isoString == null) return 'Never';
    final t = DateTime.tryParse(isoString);
    if (t == null) return 'Unknown';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '\${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '\${diff.inHours}h ago';
    return '\${diff.inDays}d ago';
  }

  bool _isOnline(String? isoString) {
    if (isoString == null) return false;
    final t = DateTime.tryParse(isoString);
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < 15;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D2E),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Live Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Updated \${_timeAgo(_lastRefresh.toIso8601String())} • \${_employees.where((e) => _isOnline(_locations[e['id']]?['created_at'])).length} online',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        backgroundColor: const Color(0xFF1A1D2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInitial,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(children: [
              Expanded(flex: 3, child: _mapSection()),
              _employeeList(),
            ]),
    );
  }

  Widget _mapSection() {
    final markers = <Marker>[];
    for (final emp in _employees) {
      final uid = emp['id'] as String;
      final loc = _locations[uid];
      if (loc == null) continue;
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final online = _isOnline(loc['created_at'] as String?);
      final isSelected = _selectedEmployee?['id'] == uid;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: isSelected ? 60 : 48,
        height: isSelected ? 60 : 48,
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedEmployee = emp;
            _mapCtrl.move(LatLng(lat, lng), 15);
          }),
          child: Stack(children: [
            Container(
              decoration: BoxDecoration(
                color: online ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: (online ? Colors.green : Colors.grey).withOpacity(0.4),
                      blurRadius: 8, spreadRadius: 2),
                ],
              ),
              child: Center(
                child: Text((emp['full_name'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            if (online)
              Positioned(
                right: 2, top: 2,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
      ));
    }

    final initialCenter = () {
      for (final emp in _employees) {
        final loc = _locations[emp['id']];
        if (loc != null) {
          final lat = (loc['latitude'] as num?)?.toDouble();
          final lng = (loc['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
      return const LatLng(20.5937, 78.9629);
    }();

    return Stack(children: [
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(initialCenter: initialCenter, initialZoom: 10),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.terrascope.terrascope_new',
          ),
          MarkerLayer(markers: markers),
        ],
      ),

      // Selected employee bubble
      if (_selectedEmployee != null) _selectedBubble(),

      // Online count badge
      Positioned(
        top: 12, right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
            const SizedBox(width: 6),
            Text(
              '\${_employees.where((e) => _isOnline(_locations[e['id']]?['created_at'])).length} / \${_employees.length} online',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _selectedBubble() {
    final emp = _selectedEmployee!;
    final loc = _locations[emp['id']];
    if (loc == null) return const SizedBox();
    final online = _isOnline(loc['created_at'] as String?);
    final battery = loc['battery_level'] as int?;

    return Positioned(
      bottom: 12, left: 12, right: 12,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: online ? Colors.green : Colors.grey,
            child: Text((emp['full_name'] as String)[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emp['full_name'] as String,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              online ? '🟢 Online • \${_timeAgo(loc['created_at'] as String?)}' 
                     : '⚪ Last seen \${_timeAgo(loc['created_at'] as String?)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ])),
          if (battery != null)
            Row(children: [
              Icon(
                battery > 50 ? Icons.battery_full : battery > 20 ? Icons.battery_4_bar : Icons.battery_alert,
                color: battery > 50 ? Colors.green : battery > 20 ? Colors.orange : Colors.red,
                size: 16,
              ),
              Text('\$battery%', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
            onPressed: () => setState(() => _selectedEmployee = null),
          ),
        ]),
      ),
    );
  }

  Widget _employeeList() => Container(
        height: 120,
        color: const Color(0xFF252840),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: _employees.length,
          itemBuilder: (_, i) {
            final emp = _employees[i];
            final loc = _locations[emp['id']];
            final online = _isOnline(loc?['created_at'] as String?);
            final isSelected = _selectedEmployee?['id'] == emp['id'];

            return GestureDetector(
              onTap: () {
                setState(() => _selectedEmployee = emp);
                if (loc != null) {
                  final lat = (loc['latitude'] as num?)?.toDouble();
                  final lng = (loc['longitude'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    _mapCtrl.move(LatLng(lat, lng), 15);
                  }
                }
              },
              child: Container(
                width: 90,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: online ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                      child: Text((emp['full_name'] as String)[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: online ? Colors.greenAccent : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF252840), width: 2),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    (emp['full_name'] as String).split(' ').first,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    loc == null ? 'No data' : _timeAgo(loc['created_at'] as String?),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ]),
              ),
            );
          },
        ),
      );
}
