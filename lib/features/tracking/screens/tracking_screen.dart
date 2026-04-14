import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/tracking_service.dart'; // ← FIXES THE RED ERROR

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _plannedStops = [];
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  double _totalDistance = 0;
  int _trackingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadTodayStops();
  }

  Future<void> _getCurrentLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  // Load today's parties as route stops
  Future<void> _loadTodayStops() async {
    try {
      final parties = await SupabaseService.client
          .from('parties')
          .select('id, name, latitude, longitude, is_active')
          .eq('user_id', SupabaseService.userId!)
          .eq('is_active', true)
          .not('latitude', 'is', null);

      final today = DateTime.now().toIso8601String().split('T')[0];
      final todayVisits = await SupabaseService.client
          .from('visits')
          .select('party_id')
          .eq('user_id', SupabaseService.userId!)
          .gte('check_in_time', '${today}T00:00:00.000');

      final visitedIds =
          (todayVisits as List).map((v) => v['party_id'].toString()).toSet();

      final stopsWithStatus = (parties as List).map((p) {
        return {
          ...Map<String, dynamic>.from(p),
          'visited': visitedIds.contains(p['id'].toString()),
        };
      }).toList();

      // Sort unvisited stops by distance from current position
      if (_currentPosition != null) {
        stopsWithStatus.sort((a, b) {
          if (a['visited'] == true) return 1;
          if (b['visited'] == true) return -1;
          final distA = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a['latitude'],
            a['longitude'],
          );
          final distB = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b['latitude'],
            b['longitude'],
          );
          return distA.compareTo(distB);
        });
      }

      if (mounted) setState(() => _plannedStops = stopsWithStatus);
    } catch (_) {}
  }

  void _startTracking() async {
    await TrackingService.startTracking();
    setState(() => _isTracking = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _trackingSeconds++);
    });

    // UI-only stream for live map drawing
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only update map if moved 10m
      ),
    ).listen((position) {
      final newPoint = LatLng(position.latitude, position.longitude);

      // Accumulate distance
      if (_routePoints.isNotEmpty) {
        _totalDistance += LocationService.calculateDistance(
          _routePoints.last.latitude,
          _routePoints.last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
      }

      setState(() {
        _currentPosition = newPoint;
        _routePoints.add(newPoint);
      });

      _mapController.move(newPoint, _mapController.camera.zoom);
    });
  }

  void _stopTracking() async {
    await TrackingService.stopTracking();
    _positionStream?.cancel();
    _timer?.cancel();
    setState(() => _isTracking = false);

    // Save route summary to Supabase
    if (_routePoints.isNotEmpty) {
      try {
        final today = DateTime.now().toIso8601String().split('T')[0];
        await SupabaseService.client.from('daily_routes').upsert({
          'user_id': SupabaseService.userId,
          'date': today,
          'total_distance_km':
              double.parse((_totalDistance / 1000).toStringAsFixed(2)),
          'duration_seconds': _trackingSeconds,
          'total_points': _routePoints.length,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,date');
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final unvisited = _plannedStops.where((s) => s['visited'] != true).length;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(28.6139, 77.2090),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fieldtrackpro.app',
              ),

              // Drawn route polyline
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4,
                      color: AppColors.primary,
                    ),
                  ],
                ),

              // Today's party stops as numbered pins
              if (_plannedStops.isNotEmpty)
                MarkerLayer(
                  markers: _plannedStops.asMap().entries.map((entry) {
                    final i = entry.key;
                    final stop = entry.value;
                    if (stop['latitude'] == null) {
                      return const Marker(
                          point: LatLng(0, 0), child: SizedBox.shrink());
                    }
                    return Marker(
                      point: LatLng(stop['latitude'], stop['longitude']),
                      width: 36,
                      height: 36,
                      child: Tooltip(
                        message: stop['name'] ?? '',
                        child: Container(
                          decoration: BoxDecoration(
                            color: stop['visited'] == true
                                ? AppColors.success
                                : AppColors.warning,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: stop['visited'] == true
                                ? const Icon(Icons.check,
                                    color: AppColors.white, size: 16)
                                : Text('${i + 1}',
                                    style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Current location marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person,
                            color: AppColors.white, size: 20),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Top Status Bar ───────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Tracking status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTracking ? Icons.circle : Icons.circle_outlined,
                          size: 10,
                          color: _isTracking
                              ? AppColors.error
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isTracking ? 'TRACKING' : 'IDLE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isTracking
                                ? AppColors.error
                                : AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Stops counter pill
                  if (_plannedStops.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '$unvisited left',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom Panel ─────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    Row(
                      children: [
                        _buildStat(
                          'Duration',
                          _formatDuration(_trackingSeconds),
                          Icons.timer_outlined,
                        ),
                        _buildStat(
                          'Distance',
                          '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                          Icons.straighten_rounded,
                        ),
                        _buildStat(
                          'Visited',
                          '${_plannedStops.where((s) => s['visited'] == true).length}/${_plannedStops.length}',
                          Icons.store_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Start / Stop
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isTracking ? _stopTracking : _startTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isTracking ? AppColors.error : AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isTracking
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isTracking ? 'Stop Tracking' : 'Start Tracking',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Re-center FAB ─────────────────────────────────
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton.small(
              heroTag: 'recenter_fab',
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 16);
                }
              },
              backgroundColor: AppColors.white,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // ── Refresh stops FAB ─────────────────────────────
          Positioned(
            right: 16,
            bottom: 272,
            child: FloatingActionButton.small(
              heroTag: 'refresh_fab', // ← ADD
              onPressed: _loadTodayStops,
              backgroundColor: AppColors.white,
              child:
                  const Icon(Icons.refresh_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
