import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, Map<String, dynamic>> _attendanceMap = {};
  List<Map<String, dynamic>> _holidays = [];
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _monthlySummary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.userId!;
      final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final results = await Future.wait([
        // Attendance records for the month
        SupabaseService.client
            .from('attendance')
            .select()
            .eq('user_id', userId)
            .gte('date', monthStart.toIso8601String().split('T')[0])
            .lte('date', monthEnd.toIso8601String().split('T')[0])
            .order('date', ascending: true),
        // Holidays for the month
        SupabaseService.client
            .from('holidays')
            .select()
            .gte('date', monthStart.toIso8601String().split('T')[0])
            .lte('date', monthEnd.toIso8601String().split('T')[0]),
        // Company settings
        SupabaseService.client
            .from('company_settings')
            .select('setting_key, setting_value')
            .inFilter('setting_key', [
          'shift_start_time',
          'shift_end_time',
          'grace_period_minutes',
          'half_day_threshold_hours',
          'full_day_threshold_hours',
          'week_offs',
        ]),
      ]);

      final records = List<Map<String, dynamic>>.from(results[0] as List);
      _holidays = List<Map<String, dynamic>>.from(results[1] as List);
      final settingsList = List<Map<String, dynamic>>.from(results[2] as List);

      _settings = {};
      for (final s in settingsList) {
        _settings[s['setting_key']] = s['setting_value'];
      }

      // Build attendance map
      _attendanceMap = {};
      for (final r in records) {
        final date = DateTime.parse(r['date']);
        final key = DateTime(date.year, date.month, date.day);
        _attendanceMap[key] = r;
      }

      // Calculate monthly summary
      _calculateMonthlySummary(monthStart, monthEnd);
    } catch (e) {
      debugPrint('Load attendance error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _calculateMonthlySummary(DateTime start, DateTime end) {
    final weekOffs = (_settings['week_offs'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        ['sunday'];

    final holidayDates = _holidays
        .map((h) => DateTime.parse(h['date']))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    int totalDays = 0;
    int workingDays = 0;
    int weekoffDays = 0;
    int holidayCount = 0;
    double present = 0;
    double halfDays = 0;
    double absent = 0;
    double leaves = 0;
    int lateCount = 0;
    double totalOT = 0;
    double totalHours = 0;

    final today = DateTime.now();
    final lastDay = end.isAfter(today) ? today : end;

    for (var d = start;
        !d.isAfter(lastDay);
        d = d.add(const Duration(days: 1))) {
      totalDays++;
      final key = DateTime(d.year, d.month, d.day);
      final dayName = DateFormat('EEEE').format(d).toLowerCase();

      if (weekOffs.contains(dayName)) {
        weekoffDays++;
        continue;
      }
      if (holidayDates.contains(key)) {
        holidayCount++;
        continue;
      }

      workingDays++;

      final record = _attendanceMap[key];
      if (record == null) {
        absent++;
        continue;
      }

      final type = record['attendance_type'] ?? 'full_day';
      final hours = (record['work_hours'] as num?)?.toDouble() ?? 0;
      totalHours += hours;

      if (type == 'half_day') {
        halfDays++;
        present += 0.5;
      } else if (type == 'leave') {
        leaves++;
      } else if (type == 'absent') {
        absent++;
      } else {
        present++;
      }

      if (record['is_late'] == true) lateCount++;
      totalOT += (record['overtime_hours'] as num?)?.toDouble() ?? 0;
    }

    _monthlySummary = {
      'total_days': totalDays,
      'working_days': workingDays,
      'weekoffs': weekoffDays,
      'holidays': holidayCount,
      'present': present,
      'half_days': halfDays,
      'absent': absent,
      'leaves': leaves,
      'late_count': lateCount,
      'overtime_hours': totalOT,
      'avg_hours': present > 0 ? (totalHours / (present + halfDays * 0.5)) : 0,
      'total_hours': totalHours,
      'attendance_pct': workingDays > 0 ? (present / workingDays * 100) : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Summary'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined),
            tooltip: 'Request Regularization',
            onPressed: _showRegularizationDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _calendarTab(),
                _summaryTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // CALENDAR TAB
  // ═══════════════════════════════════════════
  Widget _calendarTab() {
    final weekOffs = (_settings['week_offs'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        ['sunday'];
    final holidayDates = _holidays.map((h) {
      final d = DateTime.parse(h['date']);
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2025, 1, 1),
          lastDay: DateTime(2027, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onPageChanged: (focused) {
            _focusedDay = focused;
            _loadData();
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focused) {
              final key = DateTime(day.year, day.month, day.day);
              final dayName = DateFormat('EEEE').format(day).toLowerCase();
              final isWeekOff = weekOffs.contains(dayName);
              final isHoliday = holidayDates.contains(key);
              final record = _attendanceMap[key];

              Color? bgColor;
              Color textColor = Colors.black87;

              if (isWeekOff) {
                bgColor = Colors.grey.shade200;
                textColor = Colors.grey;
              } else if (isHoliday) {
                bgColor = Colors.blue.shade50;
                textColor = Colors.blue;
              } else if (record != null) {
                final type = record['attendance_type'] ?? 'full_day';
                if (type == 'full_day' || record['status'] == 'present') {
                  bgColor = Colors.green.shade100;
                  textColor = Colors.green.shade800;
                } else if (type == 'half_day') {
                  bgColor = Colors.orange.shade100;
                  textColor = Colors.orange.shade800;
                } else if (type == 'leave') {
                  bgColor = Colors.purple.shade100;
                  textColor = Colors.purple.shade800;
                } else {
                  bgColor = Colors.red.shade100;
                  textColor = Colors.red.shade800;
                }
              } else if (day.isBefore(DateTime.now()) &&
                  !isWeekOff &&
                  !isHoliday) {
                bgColor = Colors.red.shade50;
                textColor = Colors.red.shade400;
              }

              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      if (record != null && record['is_late'] == true)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendDot(Colors.green.shade100, 'Present'),
              _legendDot(Colors.orange.shade100, 'Half Day'),
              _legendDot(Colors.red.shade50, 'Absent'),
              _legendDot(Colors.purple.shade100, 'Leave'),
              _legendDot(Colors.blue.shade50, 'Holiday'),
              _legendDot(Colors.grey.shade200, 'Week Off'),
            ],
          ),
        ),

        const Divider(),

        // Selected day details
        Expanded(child: _selectedDayDetail()),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _selectedDayDetail() {
    if (_selectedDay == null) {
      return const Center(
        child: Text('Tap a date to see details',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final key =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final record = _attendanceMap[key];
    final dayName = DateFormat('EEEE, d MMM yyyy').format(_selectedDay!);

    final weekOffs = (_settings['week_offs'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        ['sunday'];
    final dayOfWeek = DateFormat('EEEE').format(_selectedDay!).toLowerCase();
    final isWeekOff = weekOffs.contains(dayOfWeek);

    final holiday = _holidays.where((h) {
      final d = DateTime.parse(h['date']);
      return d.year == key.year && d.month == key.month && d.day == key.day;
    }).toList();

    if (isWeekOff) {
      return _detailCard(dayName, 'Week Off', Icons.weekend, Colors.grey,
          subtitle: 'No attendance required');
    }

    if (holiday.isNotEmpty) {
      return _detailCard(dayName, 'Holiday', Icons.celebration, Colors.blue,
          subtitle: holiday.first['name'] ?? 'Public Holiday');
    }

    if (record == null) {
      if (_selectedDay!.isBefore(DateTime.now())) {
        return _detailCard(dayName, 'Absent', Icons.cancel_outlined, Colors.red,
            subtitle: 'No check-in recorded');
      }
      return _detailCard(dayName, 'Upcoming', Icons.calendar_today, Colors.grey,
          subtitle: 'Not yet');
    }

    final checkIn = record['check_in_time'] != null
        ? DateFormat('hh:mm a')
            .format(DateTime.parse(record['check_in_time']).toLocal())
        : '--';
    final checkOut = record['check_out_time'] != null
        ? DateFormat('hh:mm a')
            .format(DateTime.parse(record['check_out_time']).toLocal())
        : '--';
    final hours = (record['work_hours'] as num?)?.toDouble() ?? 0;
    final type = record['attendance_type'] ?? 'full_day';
    final isLate = record['is_late'] == true;
    final lateMins = record['late_minutes'] ?? 0;
    final ot = (record['overtime_hours'] as num?)?.toDouble() ?? 0;

    final statusText = type == 'half_day'
        ? 'Half Day'
        : isLate
            ? 'Present (Late)'
            : 'Present';
    final statusColor = type == 'half_day'
        ? Colors.orange
        : isLate
            ? Colors.amber.shade700
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dayName,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: statusColor),
                    const SizedBox(width: 8),
                    Text(statusText,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                    const Spacer(),
                    Text('${hours.toStringAsFixed(1)}h',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _timeBlock(
                            'Check In', checkIn, Icons.login, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _timeBlock(
                            'Check Out', checkOut, Icons.logout, Colors.red)),
                  ],
                ),
                if (isLate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Late by $lateMins minutes',
                            style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
                if (ot > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.more_time,
                            color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Overtime: ${ot.toStringAsFixed(1)}h',
                            style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Selfie thumbnails
          if (record['check_in_selfie'] != null ||
              record['check_out_selfie'] != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (record['check_in_selfie'] != null)
                  _selfieThumbnail('In', record['check_in_selfie']),
                if (record['check_in_selfie'] != null &&
                    record['check_out_selfie'] != null)
                  const SizedBox(width: 12),
                if (record['check_out_selfie'] != null)
                  _selfieThumbnail('Out', record['check_out_selfie']),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeBlock(String label, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(time,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _selfieThumbnail(String label, String url) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 24),
                  )),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _detailCard(String date, String status, IconData icon, Color color,
      {String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(status,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 4),
            Text(date,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SUMMARY TAB
  // ═══════════════════════════════════════════
  Widget _summaryTab() {
    final m = _monthlySummary;
    if (m.isEmpty) {
      return const Center(child: Text('No data'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month - 1);
                  _loadData();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _focusedDay.month < DateTime.now().month ||
                        _focusedDay.year < DateTime.now().year
                    ? () {
                        _focusedDay =
                            DateTime(_focusedDay.year, _focusedDay.month + 1);
                        _loadData();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attendance percentage card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '${(m['attendance_pct'] as num).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const Text('Attendance Rate',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryMini('Avg Hours',
                        '${(m['avg_hours'] as num).toStringAsFixed(1)}h'),
                    _summaryMini('Total Hours',
                        '${(m['total_hours'] as num).toStringAsFixed(0)}h'),
                    _summaryMini('OT Hours',
                        '${(m['overtime_hours'] as num).toStringAsFixed(1)}h'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
            children: [
              _statCard('Working\nDays', '${m['working_days']}',
                  Colors.grey.shade700),
              _statCard('Present', '${m['present']}', Colors.green.shade700),
              _statCard(
                  'Half Day', '${m['half_days']}', Colors.orange.shade700),
              _statCard('Absent', '${m['absent']}', Colors.red.shade700),
              _statCard('Leaves', '${m['leaves']}', Colors.purple.shade700),
              _statCard('Late', '${m['late_count']}', Colors.amber.shade700),
              _statCard('Week\nOffs', '${m['weekoffs']}', Colors.blueGrey),
              _statCard('Holidays', '${m['holidays']}', Colors.blue.shade700),
              _statCard('Total\nDays', '${m['total_days']}', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMini(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // REGULARIZATION DIALOG
  // ═══════════════════════════════════════════
  void _showRegularizationDialog() {
    DateTime? regDate;
    TimeOfDay? regCheckIn;
    TimeOfDay? regCheckOut;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request Regularization'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(regDate != null
                      ? DateFormat('d MMM yyyy').format(regDate!)
                      : 'Select Date'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => regDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.login),
                  title: Text(regCheckIn != null
                      ? regCheckIn!.format(ctx)
                      : 'Check-in Time'),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) {
                      setDialogState(() => regCheckIn = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: Text(regCheckOut != null
                      ? regCheckOut!.format(ctx)
                      : 'Check-out Time'),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (picked != null) {
                      setDialogState(() => regCheckOut = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'e.g. Forgot to check in, app issue...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (regDate == null || reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please select date and enter reason')),
                  );
                  return;
                }

                try {
                  final checkInDT = regCheckIn != null
                      ? DateTime(regDate!.year, regDate!.month, regDate!.day,
                              regCheckIn!.hour, regCheckIn!.minute)
                          .toUtc()
                          .toIso8601String()
                      : null;
                  final checkOutDT = regCheckOut != null
                      ? DateTime(regDate!.year, regDate!.month, regDate!.day,
                              regCheckOut!.hour, regCheckOut!.minute)
                          .toUtc()
                          .toIso8601String()
                      : null;

                  await SupabaseService.client
                      .from('attendance_regularizations')
                      .insert({
                    'user_id': SupabaseService.userId,
                    'date': regDate!.toIso8601String().split('T')[0],
                    'requested_check_in': checkInDT,
                    'requested_check_out': checkOutDT,
                    'reason': reasonController.text,
                    'status': 'pending',
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Regularization request submitted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
