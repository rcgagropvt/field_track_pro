import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/services/auto_attendance_service.dart';

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({super.key});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  Map<String, dynamic>? _todayAttendance;
  bool _isLoading = true;
  bool _isChecking = false;
  bool _shouldRemind = false;
  int _todayVisits = 0;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final attendance = await SupabaseService.getTodayAttendance();

      // Check if should remind to start day
      final remind = await AutoAttendanceService.shouldRemindStartDay();

      // Get today's visit count
      int visitCount = 0;
      try {
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final visits = await SupabaseService.client
            .from('visits')
            .select('id')
            .eq('user_id', SupabaseService.userId ?? '')
            .eq('status', 'completed')
            .gte('check_in_time', '${todayStr}T00:00:00')
            .lte('check_in_time', '${todayStr}T23:59:59');
        visitCount = (visits as List).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _todayAttendance = attendance;
          _shouldRemind = remind;
          _todayVisits = visitCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isChecking = true);

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showSnack('Location permission required', isError: true);
        setState(() => _isChecking = false);
        return;
      }

      await SupabaseService.checkIn(
        lat: position.latitude,
        lng: position.longitude,
      );

      // Auto-start location tracking
      try {
        await TrackingService.startTracking();
      } catch (_) {}

      await _loadAttendance();
      _showSnack('Day started — live tracking active!');

      // Check if late
      try {
        final settings = await SupabaseService.client
            .from('company_settings')
            .select('setting_key, setting_value')
            .inFilter(
                'setting_key', ['shift_start_time', 'grace_period_minutes']);

        String shiftStart = '09:00';
        int graceMins = 15;
        for (final s in settings as List) {
          final val = s['setting_value']?.toString().replaceAll('"', '') ?? '';
          if (s['setting_key'] == 'shift_start_time') shiftStart = val;
          if (s['setting_key'] == 'grace_period_minutes') {
            graceMins = int.tryParse(val) ?? 15;
          }
        }

        final now = DateTime.now();
        final parts = shiftStart.split(':');
        final shiftHour = int.tryParse(parts[0]) ?? 9;
        final shiftMin = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final shiftDateTime =
            DateTime(now.year, now.month, now.day, shiftHour, shiftMin);
        final graceEnd = shiftDateTime.add(Duration(minutes: graceMins));

        if (now.isAfter(graceEnd)) {
          final lateMins = now.difference(shiftDateTime).inMinutes;
          // Update attendance with late info
          if (_todayAttendance != null) {
            await SupabaseService.client.from('attendance').update({
              'is_late': true,
              'late_minutes': lateMins,
            }).eq('id', _todayAttendance!['id']);
          }
          _showSnack('You are $lateMins minutes late', isError: true);
        }
      } catch (_) {}
    } catch (e) {
      _showSnack('Check-in failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleCheckOut() async {
    if (_todayAttendance == null) return;
    setState(() => _isChecking = true);

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showSnack('Location permission required', isError: true);
        setState(() => _isChecking = false);
        return;
      }

      await SupabaseService.checkOut(
        attendanceId: _todayAttendance!['id'],
        lat: position.latitude,
        lng: position.longitude,
      );

      // Calculate attendance type based on hours and visits
      try {
        final settings = await SupabaseService.client
            .from('company_settings')
            .select('setting_key, setting_value')
            .inFilter('setting_key', [
          'full_day_threshold_hours',
          'half_day_threshold_hours',
          'min_visits_full_day',
          'min_visits_half_day',
          'overtime_start_after_hours',
        ]);

        double fullDayHours = 7;
        double halfDayHours = 4;
        int minVisitsFull = 5;
        int minVisitsHalf = 2;
        double overtimeAfter = 9;

        for (final s in settings as List) {
          final val = s['setting_value']?.toString().replaceAll('"', '') ?? '';
          switch (s['setting_key']) {
            case 'full_day_threshold_hours':
              fullDayHours = double.tryParse(val) ?? 7;
              break;
            case 'half_day_threshold_hours':
              halfDayHours = double.tryParse(val) ?? 4;
              break;
            case 'min_visits_full_day':
              minVisitsFull = int.tryParse(val) ?? 5;
              break;
            case 'min_visits_half_day':
              minVisitsHalf = int.tryParse(val) ?? 2;
              break;
            case 'overtime_start_after_hours':
              overtimeAfter = double.tryParse(val) ?? 9;
              break;
          }
        }

        // Reload to get updated check_out_time
        final updated = await SupabaseService.client
            .from('attendance')
            .select()
            .eq('id', _todayAttendance!['id'])
            .single();

        final checkIn = DateTime.parse(updated['check_in_time']);
        final checkOut = DateTime.parse(updated['check_out_time']);
        final workHours = checkOut.difference(checkIn).inMinutes / 60.0;

        // Determine attendance type using BOTH hours and visits
        String attendanceType;
        if (workHours >= fullDayHours && _todayVisits >= minVisitsFull) {
          attendanceType = 'full_day';
        } else if (workHours >= halfDayHours || _todayVisits >= minVisitsHalf) {
          attendanceType = 'half_day';
        } else {
          attendanceType = 'absent';
        }

        final overtimeHours =
            workHours > overtimeAfter ? workHours - overtimeAfter : 0.0;

        await SupabaseService.client.from('attendance').update({
          'work_hours': double.parse(workHours.toStringAsFixed(2)),
          'attendance_type': attendanceType,
          'overtime_hours': double.parse(overtimeHours.toStringAsFixed(2)),
          'visits_count': _todayVisits,
        }).eq('id', _todayAttendance!['id']);

        final hoursStr = workHours.toStringAsFixed(1);
        _showSnack('$attendanceType — $hoursStr hrs, $_todayVisits visits');
      } catch (e) {
        debugPrint('Checkout calc error: $e');
      }

      // Auto-stop location tracking
      try {
        await TrackingService.stopTracking();
      } catch (_) {}

      await _loadAttendance();
    } catch (e) {
      _showSnack('Check-out failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final isCheckedIn =
        _todayAttendance != null && _todayAttendance!['check_in_time'] != null;
    final isCheckedOut =
        _todayAttendance != null && _todayAttendance!['check_out_time'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? AppColors.white.withOpacity(0.2)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCheckedOut
                      ? 'Day Complete'
                      : isCheckedIn
                          ? 'On Duty'
                          : 'Not Started',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reminder banner
          if (_shouldRemind && !isCheckedIn)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your shift has started! Tap "Start Day" or your first visit will auto-start tracking.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Time display
          Row(
            children: [
              _buildTimeBlock(
                'Start',
                isCheckedIn
                    ? DateFormat('hh:mm a').format(
                        DateTime.parse(_todayAttendance!['check_in_time']))
                    : '--:--',
                Icons.login_rounded,
              ),
              const SizedBox(width: 12),
              _buildTimeBlock(
                'End',
                isCheckedOut
                    ? DateFormat('hh:mm a').format(
                        DateTime.parse(_todayAttendance!['check_out_time']))
                    : '--:--',
                Icons.logout_rounded,
              ),
              const SizedBox(width: 12),
              _buildTimeBlock(
                'Visits',
                '$_todayVisits',
                Icons.place_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Check In/Out Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isChecking || isCheckedOut
                  ? null
                  : (isCheckedIn ? _handleCheckOut : _handleCheckIn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.white.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isChecking
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCheckedOut
                              ? Icons.check_circle_rounded
                              : isCheckedIn
                                  ? Icons.logout_rounded
                                  : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCheckedOut
                              ? 'Day Completed'
                              : isCheckedIn
                                  ? 'End Day'
                                  : 'Start Day',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Auto-start hint
          if (!isCheckedIn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Or skip — your first visit will auto-start your day',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(String label, String time, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.white, size: 16),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
