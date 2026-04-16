import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class GeofenceService {
  /// Default radius in meters if party has no custom radius
  static const double defaultRadiusMeters = 200.0;

  /// Check if the user's current position is within the allowed
  /// radius of the party's registered location.
  /// Returns a [GeofenceResult] with pass/fail and distance info.
  static Future<GeofenceResult> validateCheckIn({
    required double userLat,
    required double userLng,
    required Map<String, dynamic> party,
  }) async {
    final partyLat = _toDouble(party['latitude']);
    final partyLng = _toDouble(party['longitude']);

    // If party has no coordinates stored, allow check-in with warning
    if (partyLat == null || partyLng == null) {
      return GeofenceResult(
        allowed: true,
        distance: 0,
        radius: defaultRadiusMeters,
        reason: 'Party location not set — geofence skipped',
        hasCoordinates: false,
      );
    }

    final distance = Geolocator.distanceBetween(
      userLat, userLng, partyLat, partyLng,
    );

    // Party-level custom radius, else company default
    final radius = _toDouble(party['geofence_radius']) ?? defaultRadiusMeters;

    final allowed = distance <= radius;

    return GeofenceResult(
      allowed: allowed,
      distance: distance,
      radius: radius,
      reason: allowed
          ? 'Within geofence (${distance.toStringAsFixed(0)}m / ${radius.toStringAsFixed(0)}m)'
          : 'Too far from party location (${distance.toStringAsFixed(0)}m away, limit ${radius.toStringAsFixed(0)}m)',
      hasCoordinates: true,
    );
  }

  /// Admin: update the geofence radius for a specific party
  static Future<void> updatePartyRadius(String partyId, double radiusMeters) async {
    await SupabaseService.client.from('parties').update({
      'geofence_radius': radiusMeters,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', partyId);
  }

  /// Admin: update the default company-wide geofence radius (stored in settings)
  static Future<void> updateDefaultRadius(double radiusMeters) async {
    await SupabaseService.client.from('app_settings').upsert({
      'key': 'default_geofence_radius',
      'value': radiusMeters.toString(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch the company default radius from settings table
  static Future<double> getDefaultRadius() async {
    try {
      final row = await SupabaseService.client
          .from('app_settings')
          .select('value')
          .eq('key', 'default_geofence_radius')
          .maybeSingle();
      if (row != null) {
        return double.tryParse(row['value'].toString()) ?? defaultRadiusMeters;
      }
    } catch (e) {
      debugPrint('getDefaultRadius error: $e');
    }
    return defaultRadiusMeters;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class GeofenceResult {
  final bool allowed;
  final double distance;
  final double radius;
  final String reason;
  final bool hasCoordinates;

  GeofenceResult({
    required this.allowed,
    required this.distance,
    required this.radius,
    required this.reason,
    required this.hasCoordinates,
  });
}
