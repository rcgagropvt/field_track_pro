import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/location_service.dart';
import '../../visits/screens/start_visit_screen.dart';

class BeatPlanScreen extends StatefulWidget {
  const BeatPlanScreen({super.key});
  @override
  State<BeatPlanScreen> createState() => _BeatPlanScreenState();
}

class _BeatPlanScreenState extends State<BeatPlanScreen> {
  final MapController _mapCtrl = MapController();
  List<Map<String, dynamic>> _stops = [];
  Map<String, dynamic>? _beat;
  bool _loading = true;
  LatLng? _myPos;
  Set<String> _visitedPartyIds = {};
  int _currentStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;

      final today = DateTime.now().weekday; // 1=Mon, 7=Sun

      // Get today's beat assigned to this user
      final beats = await SupabaseService.client
          .from('beats')
          .select()
          .eq('assigned_user', uid)
          .eq('is_active', true)
          .or('day_of_week.eq.$today,day_of_week.is.null')
          .limit(1);

      if ((beats as List).isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      _beat = beats.first;

      // Get stops in sequence with party details
      final stops = await SupabaseService.client
          .from('beat_stops')
          .select('*, parties(id, name, address, city, phone, latitude, longitude, type)')
          .eq('beat_id', _beat!['id'])
          .order('sequence');

      // Get today's completed visits
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final visits = await SupabaseService.client
          .from('visits')
          .select('party_id')
          .eq('user_id', uid)
          .gte('check_in_time', '${todayStr}T00:00:00.000');

      final visitedIds = (visits as List).map((v) => v['party_id'].toString()).toSet();

      // Get current position
      final pos = await LocationService.getCurrentPosition();

      if (mounted) {
        setState(() {
          _stops = List<Map<String, dynamic>>.from(stops as List);
          _visitedPartyIds = visitedIds;
          _myPos = pos != null ? LatLng(pos.latitude, pos.longitude) : null;
          // Find next unvisited stop
          _currentStopIndex = _stops.indexWhere(
            (s) => !visitedIds.contains(s['parties']['id'].toString()),
          );
          if (_currentStopIndex < 0) _currentStopIndex = _stops.length - 1;
          _loading = false;
        });

        // Center map on next stop
        if (_stops.isNotEmpty && _currentStopIndex >= 0) {
          final p = _stops[_currentStopIndex]['parties'];
          if (p['latitude'] != null && p['longitude'] != null) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _mapCtrl.move(LatLng(p['latitude'], p['longitude']), 14);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('BeatPlan load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _adherencePercent() {
    if (_stops.isEmpty) return 0;
    return (_visitedPartyIds.length / _stops.length * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beat Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_beat?['name'] ?? 'No beat assigned today',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
          : _beat == null
              ? _noBeatView()
              : Column(children: [
                  _adherenceBar(),
                  Expanded(child: _mapSection()),
                  _stopsList(),
                ]),
    );
  }

  Widget _noBeatView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.route, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No beat assigned for today',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Ask your admin to assign a beat plan',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
      );

  Widget _adherenceBar() {
    final pct = _adherencePercent();
    final visited = _visitedPartyIds.length;
    final total = _stops.length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Beat Adherence: ${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('$visited / $total stops visited',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red,
                ),
                minHeight: 8,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _mapSection() {
    final markers = <Marker>[];

    if (_myPos != null) {
      markers.add(Marker(
        point: _myPos!,
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
      ));
    }

    for (int i = 0; i < _stops.length; i++) {
      final party = _stops[i]['parties'] as Map<String, dynamic>;
      final lat = party['latitude'] as double?;
      final lng = party['longitude'] as double?;
      if (lat == null || lng == null) continue;

      final isVisited = _visitedPartyIds.contains(party['id'].toString());
      final isCurrent = i == _currentStopIndex;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showStopDetail(_stops[i]),
          child: Container(
            decoration: BoxDecoration(
              color: isVisited
                  ? Colors.green
                  : isCurrent
                      ? AppColors.primary
                      : Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
              ],
            ),
            child: Center(
              child: isVisited
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text('${_stops[i]['sequence']}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ),
      ));
    }

    // Route polyline
    final points = _stops
        .where((s) =>
            s['parties']['latitude'] != null && s['parties']['longitude'] != null)
        .map((s) => LatLng(
            s['parties']['latitude'] as double, s['parties']['longitude'] as double))
        .toList();

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _myPos ?? const LatLng(20.5937, 78.9629),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.terrascope.terrascope_new',
        ),
        if (points.length >= 2)
          PolylineLayer<Object>(polylines: [
            Polyline(
              points: points,
              color: AppColors.primary.withOpacity(0.6),
              strokeWidth: 3,
            ),
          ]),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _stopsList() {
    return Container(
      height: 200,
      color: Colors.white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Today\'s Stops', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${_stops.length} total', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _stops.length,
            itemBuilder: (_, i) => _stopCard(i),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _stopCard(int i) {
    final stop = _stops[i];
    final party = stop['parties'] as Map<String, dynamic>;
    final isVisited = _visitedPartyIds.contains(party['id'].toString());
    final isCurrent = i == _currentStopIndex;

    return GestureDetector(
      onTap: () {
        final lat = party['latitude'] as double?;
        final lng = party['longitude'] as double?;
        if (lat != null && lng != null) {
          _mapCtrl.move(LatLng(lat, lng), 15);
        }
        _showStopDetail(stop);
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primary.withOpacity(0.08)
              : isVisited
                  ? Colors.green.withOpacity(0.06)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? AppColors.primary
                : isVisited
                    ? Colors.green
                    : Colors.grey.shade200,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isVisited ? Colors.green : isCurrent ? AppColors.primary : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isVisited
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text('${stop['sequence']}',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const Spacer(),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('NEXT', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 6),
          Text(party['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(party['city'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const Spacer(),
          if (isVisited)
            const Text('✓ Visited', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600))
          else
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StartVisitScreen(party: party)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text('Start Visit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showStopDetail(Map<String, dynamic> stop) {
    final party = stop['parties'] as Map<String, dynamic>;
    final isVisited = _visitedPartyIds.contains(party['id'].toString());
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Stop #${stop['sequence']}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (isVisited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: const Text('Visited ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(party['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(party['address'] ?? '', style: const TextStyle(color: Colors.grey)),
          Text(party['city'] ?? '', style: const TextStyle(color: Colors.grey)),
          if (party['phone'] != null) ...[
            const SizedBox(height: 4),
            Text('📞 ${party['phone']}', style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 16),
          if (!isVisited)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Visit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StartVisitScreen(party: party)));
                },
              ),
            ),
        ]),
      ),
    );
  }
}


