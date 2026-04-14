import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({super.key});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  Map<String, dynamic>? _todayAttendance;
  bool _isLoading = true;
  bool _isChecking = false;

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
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showSnack('Location permission required', isError: true);
        return;
      }

      await SupabaseService.checkIn(
        lat: position.latitude,
        lng: position.longitude,
      );

      await _loadAttendance();
      _showSnack('Checked in successfully!');
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
        return;
      }

      await SupabaseService.checkOut(
        attendanceId: _todayAttendance!['id'],
        lat: position.latitude,
        lng: position.longitude,
      );

      await _loadAttendance();
      _showSnack('Checked out successfully!');
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
    final isCheckedIn = _todayAttendance != null && _todayAttendance!['check_in_time'] != null;
    final isCheckedOut = _todayAttendance != null && _todayAttendance!['check_out_time'] != null;

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          : 'Not Checked In',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Time display
          Row(
            children: [
              _buildTimeBlock(
                'Check In',
                isCheckedIn
                    ? DateFormat('hh:mm a').format(
                        DateTime.parse(_todayAttendance!['check_in_time']),
                      )
                    : '--:--',
                Icons.login_rounded,
              ),
              const SizedBox(width: 16),
              _buildTimeBlock(
                'Check Out',
                isCheckedOut
                    ? DateFormat('hh:mm a').format(
                        DateTime.parse(_todayAttendance!['check_out_time']),
                      )
                    : '--:--',
                Icons.logout_rounded,
              ),
            ],
          ),

          const SizedBox(height: 20),

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
                                  : Icons.login_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCheckedOut
                              ? 'Day Completed'
                              : isCheckedIn
                                  ? 'Check Out'
                                  : 'Check In',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
