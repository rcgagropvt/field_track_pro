import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/route_optimizer_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../visits/screens/start_visit_screen.dart';

class OptimizedRouteScreen extends StatefulWidget {
  const OptimizedRouteScreen({super.key});
  @override
  State<OptimizedRouteScreen> createState() => _OptimizedRouteScreenState();
}

class _OptimizedRouteScreenState extends State<OptimizedRouteScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _optimizedStops = [];
  double? _userLat, _userLng;
  double _totalDistanceKm = 0;
  String? _beatName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Get current GPS
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location required for route optimization')),
          );
          setState(() => _loading = false);
        }
        return;
      }
      _userLat = pos.latitude;
      _userLng = pos.longitude;

      // 2. Get today's beat plan
      final weekday = DateTime.now().weekday; // 1=Mon, 7=Sun
      final userId = SupabaseService.userId;

      final beats = await SupabaseService.client
          .from('beats')
          .select('id, name, day_of_week')
          .eq('assigned_user', userId!)
          .eq('is_active', true);
      final beatList = List<Map<String, dynamic>>.from(beats as List);

      // Find today's beat (matching day_of_week) or any "every day" beat
      Map<String, dynamic>? todayBeat;
      for (final b in beatList) {
        final day = b['day_of_week'] as int?;
        if (day == null || day == weekday) {
          todayBeat = b;
          break;
        }
      }

      List<Map<String, dynamic>> parties = [];

      if (todayBeat != null) {
        _beatName = todayBeat['name'] as String?;
        // Get beat stops with party details
        final stops = await SupabaseService.client
            .from('beat_stops')
            .select('sequence, parties(id, name, address, city, phone, type, latitude, longitude)')
            .eq('beat_id', todayBeat['id'])
            .order('sequence');
        final stopList = List<Map<String, dynamic>>.from(stops as List);
        parties = stopList
            .where((s) => s['parties'] != null)
            .map((s) => Map<String, dynamic>.from(s['parties'] as Map))
            .toList();
      } else {
        // No beat for today — fall back to all user's parties
        _beatName = 'All Parties';
        final pts = await SupabaseService.client
            .from('parties')
            .select()
            .eq('user_id', userId)
            .eq('is_active', true);
        parties = List<Map<String, dynamic>>.from(pts as List);
      }

      // 3. Optimize route
      final optimized = RouteOptimizerService.optimizeRoute(
        currentLat: pos.latitude,
        currentLng: pos.longitude,
        parties: parties,
      );

      final totalDist = RouteOptimizerService.totalRouteDistance(
        startLat: pos.latitude,
        startLng: pos.longitude,
        orderedParties: optimized,
      );

      if (mounted) {
        setState(() {
          _optimizedStops = optimized;
          _totalDistanceKm = totalDist / 1000;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('OptimizedRoute error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_beatName ?? 'Optimized Route',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _optimizedStops.isEmpty
              ? const Center(child: Text('No stops to optimize'))
              : Column(children: [
                  // Summary bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppColors.primarySurface,
                    child: Row(children: [
                      const Icon(Icons.route, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_optimizedStops.length} stops · ${_totalDistanceKm.toStringAsFixed(1)} km estimated',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('AI Optimized',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ),
                    ]),
                  ),

                  // Map preview
                  if (_userLat != null)
                    SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_userLat!, _userLng!),
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.fieldtrackpro.app',
                          ),
                          // Route polyline
                          PolylineLayer(polylines: [
                            Polyline(
                              points: [
                                LatLng(_userLat!, _userLng!),
                                ..._optimizedStops
                                    .where((p) => p['latitude'] != null && p['longitude'] != null)
                                    .map((p) => LatLng(
                                          double.parse(p['latitude'].toString()),
                                          double.parse(p['longitude'].toString()),
                                        )),
                              ],
                              color: AppColors.primary,
                              strokeWidth: 3,
                            ),
                          ]),
                          // Markers
                          MarkerLayer(markers: [
                            // User location
                            Marker(
                              point: LatLng(_userLat!, _userLng!),
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.my_location, color: Colors.white, size: 16),
                              ),
                            ),
                            // Stop markers
                            ..._optimizedStops
                                .where((p) => p['latitude'] != null && p['longitude'] != null)
                                .map((p) {
                              final seq = p['_optimized_sequence'] ?? 0;
                              return Marker(
                                point: LatLng(
                                  double.parse(p['latitude'].toString()),
                                  double.parse(p['longitude'].toString()),
                                ),
                                width: 28,
                                height: 28,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text('$seq',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            }),
                          ]),
                        ],
                      ),
                    ),

                  // Stop list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _optimizedStops.length,
                      itemBuilder: (_, i) {
                        final stop = _optimizedStops[i];
                        final distM = stop['_optimized_distance_m'];
                        final distLabel = distM != null
                            ? distM > 1000
                                ? '${(distM / 1000).toStringAsFixed(1)} km'
                                : '${distM.toStringAsFixed(0)} m'
                            : 'No GPS';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                              ),
                            ),
                            title: Text(stop['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              '${stop['address'] ?? stop['city'] ?? ''} · $distLabel',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StartVisitScreen(party: stop),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(60, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Visit', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
