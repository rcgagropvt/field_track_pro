import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await SupabaseService.client
          .from('attendance')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('date', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _records.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'No Records',
                  subtitle: 'Your attendance history will appear here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final checkIn = record['check_in_time'] != null
                        ? DateFormat('hh:mm a').format(DateTime.parse(record['check_in_time']))
                        : '--:--';
                    final checkOut = record['check_out_time'] != null
                        ? DateFormat('hh:mm a').format(DateTime.parse(record['check_out_time']))
                        : '--:--';
                    final hours = (record['work_hours'] as num?)?.toStringAsFixed(1) ?? '0.0';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEE, dd MMM yyyy').format(
                                  DateTime.parse(record['date']),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              StatusBadge(status: record['status'] ?? 'present'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _timeChip('In: $checkIn', AppColors.success),
                              const SizedBox(width: 8),
                              _timeChip('Out: $checkOut', AppColors.error),
                              const Spacer(),
                              Text(
                                '${hours}h',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _timeChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
