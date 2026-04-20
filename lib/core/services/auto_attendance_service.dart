import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';
import 'tracking_service.dart';
import 'location_service.dart';

class AutoAttendanceService {
  /// Called when employee starts their first visit of the day.
  /// Checks if attendance exists — if not, creates it and starts tracking.
  static Future<void> ensureAttendanceAndTracking({
    required double lat,
    required double lng,
    String? address,
  }) async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      // Check if attendance already exists today
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final existing = await SupabaseService.client
          .from('attendance')
          .select('id, check_in_time')
          .eq('user_id', userId)
          .eq('date', todayStr)
          .maybeSingle();

      if (existing != null) {
        // Attendance exists — just make sure tracking is running
        try {
          await TrackingService.startTracking();
        } catch (_) {}
        return;
      }

      // No attendance today — check if auto-start is enabled
      final setting = await SupabaseService.client
          .from('company_settings')
          .select('setting_value')
          .eq('setting_key', 'auto_start_tracking_on_visit')
          .maybeSingle();

      final autoStart =
          setting?['setting_value']?.toString().replaceAll('"', '') == 'true';

      if (!autoStart) return;

      // Create attendance record
      await SupabaseService.client.from('attendance').insert({
        'user_id': userId,
        'date': todayStr,
        'check_in_time': DateTime.now().toIso8601String(),
        'check_in_lat': lat,
        'check_in_lng': lng,
        'check_in_address': address ?? 'Auto — First Visit',
        'status': 'present',
        'attendance_type': 'full_day',
      });

      // Start GPS tracking
      try {
        await TrackingService.startTracking();
      } catch (_) {}

      debugPrint('Auto-attendance created & tracking started from first visit');
    } catch (e) {
      debugPrint('Auto-attendance error: $e');
    }
  }

  /// Called to check and update attendance type based on visits count
  static Future<void> updateAttendanceFromVisits() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get today's attendance
      final attendance = await SupabaseService.client
          .from('attendance')
          .select('id, check_in_time')
          .eq('user_id', userId)
          .eq('date', todayStr)
          .maybeSingle();

      if (attendance == null) return;

      // Count completed visits today
      final todayStart = '${todayStr}T00:00:00';
      final todayEnd = '${todayStr}T23:59:59';

      final visits = await SupabaseService.client
          .from('visits')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .gte('check_in_time', todayStart)
          .lte('check_in_time', todayEnd);

      final visitCount = (visits as List).length;

      // Get thresholds
      final settings = await SupabaseService.client
          .from('company_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key',
              ['min_visits_full_day', 'min_visits_half_day']);

      int minFull = 5;
      int minHalf = 2;
      for (final s in settings as List) {
        final val = int.tryParse(
                s['setting_value']?.toString().replaceAll('"', '') ?? '') ??
            0;
        if (s['setting_key'] == 'min_visits_full_day') minFull = val;
        if (s['setting_key'] == 'min_visits_half_day') minHalf = val;
      }

      // Update visit count on attendance
      await SupabaseService.client.from('attendance').update({
        'visits_count': visitCount,
      }).eq('id', attendance['id']);

      debugPrint(
          'Attendance updated: $visitCount visits (full=$minFull, half=$minHalf)');
    } catch (e) {
      debugPrint('Update attendance visits error: $e');
    }
  }

  /// Check if employee should be reminded to start their day
  static Future<bool> shouldRemindStartDay() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return false;

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check if already checked in
      final existing = await SupabaseService.client
          .from('attendance')
          .select('id')
          .eq('user_id', userId)
          .eq('date', todayStr)
          .maybeSingle();

      if (existing != null) return false;

      // Get shift start and reminder setting
      final settings = await SupabaseService.client
          .from('company_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key',
              ['shift_start_time', 'remind_start_day_after_minutes']);

      String shiftStart = '09:00';
      int remindAfter = 30;
      for (final s in settings as List) {
        final val = s['setting_value']?.toString().replaceAll('"', '') ?? '';
        if (s['setting_key'] == 'shift_start_time') shiftStart = val;
        if (s['setting_key'] == 'remind_start_day_after_minutes') {
          remindAfter = int.tryParse(val) ?? 30;
        }
      }

      final parts = shiftStart.split(':');
      final shiftHour = int.tryParse(parts[0]) ?? 9;
      final shiftMin = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

      final shiftDateTime = DateTime(
          today.year, today.month, today.day, shiftHour, shiftMin);
      final reminderTime =
          shiftDateTime.add(Duration(minutes: remindAfter));

      return DateTime.now().isAfter(reminderTime);
    } catch (e) {
      return false;
    }
  }
}
