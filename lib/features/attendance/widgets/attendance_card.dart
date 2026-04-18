import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/services/push_notification_service.dart';

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({super.key});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  Map<String, dynamic>? _todayAttendance;
  bool _isLoading = true;
  bool _isChecking = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final attendance = await SupabaseService.getTodayAttendance();
      if (mounted) {
        setState(() {
          _todayAttendance = attendance;
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
      // Step 1: Get location
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showSnack('Please enable location services', isError: true);
        setState(() => _isChecking = false);
        return;
      }

      // Step 2: Take mandatory selfie
      final selfie = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 50,
        maxWidth: 480,
      );

      if (selfie == null) {
        _showSnack('Selfie is required for check-in', isError: true);
        setState(() => _isChecking = false);
        return;
      }

      // Step 3: Upload selfie
      String? selfieUrl;
      try {
        final bytes = await selfie.readAsBytes();
        final fileName =
            'attendance/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}_in.jpg';
        await SupabaseService.client.storage
            .from('uploads')
            .uploadBinary(fileName, bytes);
        selfieUrl = SupabaseService.client.storage
            .from('uploads')
            .getPublicUrl(fileName);
      } catch (_) {}

      // Step 4: Mark attendance
      await SupabaseService.checkIn(
        lat: position.latitude,
        lng: position.longitude,
        selfieUrl: selfieUrl,
      );

      await _loadAttendance();
      _showSnack('Checked in successfully!');

      // Auto-start location tracking
      try {
        await TrackingService.startTracking();
      } catch (_) {}

      // Award XP for attendance
      try {
        await SupabaseService.client.rpc('award_xp', params: {
          'p_user_id': SupabaseService.userId,
          'p_action': 'attendance',
        });
        // Check milestones & notify rank changes
        try {
          await SupabaseService.client.rpc('check_milestones',
              params: {'p_user_id': SupabaseService.userId});
          await SupabaseService.client.rpc('notify_rank_change',
              params: {'p_user_id': SupabaseService.userId});
        } catch (_) {}

        // Deliver push notifications for any new alerts
        await _deliverPushNotifications();
      } catch (e) {
        debugPrint('Attendance XP error: $e');
      }
    } catch (e) {
      _showSnack('Check-in failed. Please try again.', isError: true);
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
        _showSnack('Please enable location services', isError: true);
        setState(() => _isChecking = false);
        return;
      }

      // Take checkout selfie
      final selfie = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 50,
        maxWidth: 480,
      );

      String? selfieUrl;
      if (selfie != null) {
        try {
          final bytes = await selfie.readAsBytes();
          final fileName =
              'attendance/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}_out.jpg';
          await SupabaseService.client.storage
              .from('uploads')
              .uploadBinary(fileName, bytes);
          selfieUrl = SupabaseService.client.storage
              .from('uploads')
              .getPublicUrl(fileName);
        } catch (_) {}
      }

      await SupabaseService.checkOut(
        attendanceId: _todayAttendance!['id'],
        lat: position.latitude,
        lng: position.longitude,
        selfieUrl: selfieUrl,
      );

      await _loadAttendance();
      _showSnack('Checked out! Good job today.');

      // Auto-stop location tracking
      try {
        await TrackingService.stopTracking();
      } catch (_) {}
    } catch (e) {
      _showSnack('Check-out failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Read recent unread notifications and fire push for each
  Future<void> _deliverPushNotifications() async {
    try {
      final notifications = await SupabaseService.client
          .from('notifications')
          .select('id, user_id, title, body, type')
          .eq('is_read', false)
          .gte('created_at',
              DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String())
          .limit(10);
      for (final n in notifications as List) {
        await PushNotificationService.sendToUser(
          userId: n['user_id'],
          title: n['title'],
          body: n['body'],
          data: {'type': n['type'] ?? 'general'},
        );
      }
    } catch (e) {
      debugPrint('Push delivery error: $e');
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
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final isCheckedIn =
        _todayAttendance != null && _todayAttendance!['check_in_time'] != null;
    final isCheckedOut =
        _todayAttendance != null && _todayAttendance!['check_out_time'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                        fontSize: 12, color: AppColors.white.withOpacity(0.8)),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? AppColors.white.withOpacity(0.2)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCheckedOut
                          ? Icons.check_circle
                          : isCheckedIn
                              ? Icons.circle
                              : Icons.circle_outlined,
                      size: 8,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCheckedOut
                          ? 'Day Done'
                          : isCheckedIn
                              ? 'On Duty'
                              : 'Not In',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _timeBlock(
                'Check In',
                isCheckedIn
                    ? DateFormat('hh:mm a').format(
                        DateTime.parse(_todayAttendance!['check_in_time']))
                    : '--:--',
                Icons.login_rounded,
              ),
              const SizedBox(width: 12),
              _timeBlock(
                'Check Out',
                isCheckedOut
                    ? DateFormat('hh:mm a').format(
                        DateTime.parse(_todayAttendance!['check_out_time']))
                    : '--:--',
                Icons.logout_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isCheckedIn)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 16, color: AppColors.white.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Takes a selfie + GPS location as proof',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.white.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isChecking || isCheckedOut
                  ? null
                  : (isCheckedIn ? _handleCheckOut : _handleCheckIn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.white.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isChecking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.primary))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCheckedOut
                              ? Icons.check_circle_rounded
                              : isCheckedIn
                                  ? Icons.logout_rounded
                                  : Icons.camera_alt_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCheckedOut
                              ? 'Day Completed'
                              : isCheckedIn
                                  ? 'Check Out (Selfie + GPS)'
                                  : 'Check In (Selfie + GPS)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBlock(String label, String time, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.white.withOpacity(0.7))),
                Text(time,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
