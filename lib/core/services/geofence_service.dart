import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class GeofenceService {
  static const double defaultRadiusMeters = 200.0;

  /// Validate if user is within geofence of the party location
  static Future<GeofenceResult> validateCheckIn({
    required double userLat,
    required double userLng,
    required Map<String, dynamic> party,
  }) async {
    // Check enforcement mode
    final enforcement = await _getSetting('geofence_enforcement') ?? 'warn';
    if (enforcement == 'off') {
      return GeofenceResult(
        allowed: true,
        distance: 0,
        radius: 0,
        reason: 'Geofence disabled',
        hasCoordinates: true,
        enforcement: 'off',
      );
    }

    final partyLat = _toDouble(party['latitude']);
    final partyLng = _toDouble(party['longitude']);

    if (partyLat == null || partyLng == null) {
      return GeofenceResult(
        allowed: true,
        distance: 0,
        radius: defaultRadiusMeters,
        reason: 'Party location not set — geofence skipped',
        hasCoordinates: false,
        enforcement: enforcement,
      );
    }

    final distance = Geolocator.distanceBetween(
      userLat,
      userLng,
      partyLat,
      partyLng,
    );

    // Priority: party-level radius > company default > hardcoded 200m
    final companyRadius = await getDefaultRadius();
    final radius = _toDouble(party['geofence_radius']) ?? companyRadius;

    final withinFence = distance <= radius;

    // In 'warn' mode, always allow but flag it
    // In 'strict' mode, block if outside
    final allowed = enforcement == 'strict' ? withinFence : true;

    return GeofenceResult(
      allowed: allowed,
      distance: distance,
      radius: radius,
      reason: withinFence
          ? 'Within geofence (${distance.toStringAsFixed(0)}m / ${radius.toStringAsFixed(0)}m)'
          : 'Outside geofence (${distance.toStringAsFixed(0)}m away, limit ${radius.toStringAsFixed(0)}m)',
      hasCoordinates: true,
      enforcement: enforcement,
      isWithinFence: withinFence,
    );
  }

  /// Update geofence radius for a specific party
  static Future<void> updatePartyRadius(
      String partyId, double radiusMeters) async {
    await SupabaseService.client.from('parties').update({
      'geofence_radius': radiusMeters,
    }).eq('id', partyId);
  }

  /// Update the company-wide default geofence radius
  static Future<void> updateDefaultRadius(double radiusMeters) async {
    await SupabaseService.client.from('company_settings').upsert({
      'setting_key': 'default_geofence_radius',
      'setting_value': radiusMeters.toString(),
      'category': 'geofence',
    }, onConflict: 'setting_key');
  }

  /// Update enforcement mode: 'strict', 'warn', or 'off'
  static Future<void> updateEnforcement(String mode) async {
    await SupabaseService.client.from('company_settings').upsert({
      'setting_key': 'geofence_enforcement',
      'setting_value': mode,
      'category': 'geofence',
    }, onConflict: 'setting_key');
  }

  /// Fetch the company default radius
  static Future<double> getDefaultRadius() async {
    try {
      final val = await _getSetting('default_geofence_radius');
      if (val != null) return double.tryParse(val) ?? defaultRadiusMeters;
    } catch (e) {
      debugPrint('getDefaultRadius error: $e');
    }
    return defaultRadiusMeters;
  }

  /// Fetch enforcement mode
  static Future<String> getEnforcement() async {
    return await _getSetting('geofence_enforcement') ?? 'warn';
  }

  static Future<String?> _getSetting(String key) async {
    try {
      final row = await SupabaseService.client
          .from('company_settings')
          .select('setting_value')
          .eq('setting_key', key)
          .maybeSingle();
      return row?['setting_value']?.toString();
    } catch (e) {
      debugPrint('GeofenceService._getSetting($key) error: $e');
      return null;
    }
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
  final String enforcement;
  final bool isWithinFence;

  GeofenceResult({
    required this.allowed,
    required this.distance,
    required this.radius,
    required this.reason,
    required this.hasCoordinates,
    this.enforcement = 'warn',
    this.isWithinFence = true,
  });
}
