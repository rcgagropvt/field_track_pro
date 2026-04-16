import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A nearest-neighbor route optimizer.
/// Given the user's current location and a list of parties with lat/lng,
/// returns the parties reordered for the shortest total travel distance.
class RouteOptimizerService {
  /// Optimize visit order using nearest-neighbor heuristic.
  /// [currentLat], [currentLng] = rep's current GPS position.
  /// [parties] = list of party maps, each must have 'latitude' and 'longitude'.
  /// Returns a new list with optimized ordering + distance metadata.
  static List<Map<String, dynamic>> optimizeRoute({
    required double currentLat,
    required double currentLng,
    required List<Map<String, dynamic>> parties,
  }) {
    // Filter out parties without coordinates
    final withCoords = parties.where((p) {
      return _toDouble(p['latitude']) != null && _toDouble(p['longitude']) != null;
    }).toList();

    final withoutCoords = parties.where((p) {
      return _toDouble(p['latitude']) == null || _toDouble(p['longitude']) == null;
    }).toList();

    if (withCoords.isEmpty) return parties; // nothing to optimize

    final visited = <int>{};
    final result = <Map<String, dynamic>>[];
    double curLat = currentLat;
    double curLng = currentLng;
    double totalDistance = 0;

    while (visited.length < withCoords.length) {
      double bestDist = double.infinity;
      int bestIdx = -1;

      for (int i = 0; i < withCoords.length; i++) {
        if (visited.contains(i)) continue;
        final pLat = _toDouble(withCoords[i]['latitude'])!;
        final pLng = _toDouble(withCoords[i]['longitude'])!;
        final dist = Geolocator.distanceBetween(curLat, curLng, pLat, pLng);
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = i;
        }
      }

      if (bestIdx == -1) break;

      visited.add(bestIdx);
      final party = Map<String, dynamic>.from(withCoords[bestIdx]);
      party['_optimized_distance_m'] = bestDist;
      party['_optimized_sequence'] = result.length + 1;
      result.add(party);

      totalDistance += bestDist;
      curLat = _toDouble(withCoords[bestIdx]['latitude'])!;
      curLng = _toDouble(withCoords[bestIdx]['longitude'])!;
    }

    debugPrint('Route optimized: ${result.length} stops, ${(totalDistance / 1000).toStringAsFixed(1)} km total');

    // Append parties without coords at the end
    for (final p in withoutCoords) {
      final party = Map<String, dynamic>.from(p);
      party['_optimized_sequence'] = result.length + 1;
      party['_optimized_distance_m'] = null;
      result.add(party);
    }

    return result;
  }

  /// Calculate total estimated route distance in meters
  static double totalRouteDistance({
    required double startLat,
    required double startLng,
    required List<Map<String, dynamic>> orderedParties,
  }) {
    double total = 0;
    double curLat = startLat;
    double curLng = startLng;

    for (final p in orderedParties) {
      final pLat = _toDouble(p['latitude']);
      final pLng = _toDouble(p['longitude']);
      if (pLat != null && pLng != null) {
        total += Geolocator.distanceBetween(curLat, curLng, pLat, pLng);
        curLat = pLat;
        curLng = pLng;
      }
    }
    return total;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
