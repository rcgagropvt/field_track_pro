import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _regularizations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      final results = await Future.wait([
        SupabaseService.client
            .from('leave_applications')
            .select('*, leave_types!inner(name, code), profiles!inner(full_name)')
            .eq('status', 'pending')
            .order('created_at', ascending: true),
        SupabaseService.client
            .from('leave_applications')
            .select('*, leave_types!inner(name, code), profiles!inner(full_name)')
            .neq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(50),
        SupabaseService.client
            .from('attendance_regularizations')
            .select('*, profiles!inner(full_name)')
            .eq('status', 'pending')
            .order('created_at', ascending: true),
      ]);

      _pending = List<Map<String, dynamic>>.from(results[0] as List);
      _history = List<Map<String, dynamic>>.from(results[1] as List);
      _regularizations = List<Map<String, dynamic>>.from(results[2] as List);
    } catch (e) {
      debugPrint('Admin leave load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Regularizations (${_regularizations.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _pendingTab(),
                _regularizationsTab(),
                _historyTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // PENDING TAB
  // ═══════════════════════════════════════════
  Widget _pendingTab() {
    if (_pending.isEmpty) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 12),
          Text('No pending requests',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        itemBuilder: (context, index) => _leaveCard(_pending[index], true),
      ),
    );
  }

  Widget _historyTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('No history', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) => _leaveCard(_history[index], false),
      ),
    );
  }

  Widget _leaveCard(Map<String, dynamic> app, bool showActions) {
    final lt = app['leave_types'] as Map<String, dynamic>;
    final profile = app['profiles'] as Map<String, dynamic>;
    final status = app['status'] ?? 'pending';
    final fromDate = DateTime.parse(app['from_date']);
    final toDate = DateTime.parse(app['to_date']);
    final days = (app['days'] as num).toDouble();

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  (profile['full_name'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('${lt['code']} - ${lt['name']}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  days == 0.5
                      ? 'Half Day'
                      : '${days.toStringAsFixed(days == days.roundToDouble() ? 0 : 1)} days',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.date_range, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                fromDate == toDate
                    ? DateFormat('d MMM yyyy').format(fromDate)
                    : '${DateFormat('d MMM').format(fromDate)} - ${DateFormat('d MMM yyyy').format(toDate)}',
                style: const TextStyle(fontSize: 13),
              ),
              if (app['half_day_type'] != null) ...[
                const SizedBox(width: 8),
                Text('(${app['half_day_type'] == 'first_half' ? '1st Half' : '2nd Half'})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ],
          ),
          if (app['reason'] != null) ...[
            const SizedBox(height: 6),
            Text('Reason: ${app['reason']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
          if (!showActions && app['review_remarks'] != null) ...[
            const SizedBox(height: 6),
            Text('Remarks: ${app['review_remarks']}',
                style: TextStyle(fontSize: 12, color: statusColor)),
          ],
          if (!showActions)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(status.toString().toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reviewLeave(app['id'], 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _reviewLeave(app['id'], 'approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reviewLeave(String id, String status) async {
    final remarksController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status == 'approved' ? 'Approve' : 'Reject'} Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $status this leave?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                labelText: 'Remarks (optional)',
                border: const OutlineInputBorder(),
                hintText: status == 'rejected'
                    ? 'Reason for rejection...'
                    : 'Any comments...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor:
                    status == 'approved' ? Colors.green : Colors.red),
            child: Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Update leave application
      await SupabaseService.client.from('leave_applications').update({
        'status': status,
        'reviewed_by': SupabaseService.userId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'review_remarks': remarksController.text.isNotEmpty
            ? remarksController.text
            : null,
      }).eq('id', id);

      // If approved, update leave balance
      if (status == 'approved') {
        final app = _pending.firstWhere((a) => a['id'] == id);
        final days = (app['days'] as num).toDouble();
        final userId = app['user_id'];
        final leaveTypeId = app['leave_type_id'];
        final now = DateTime.now();
        final year = now.month >= 4 ? now.year : now.year - 1;

        await SupabaseService.client
            .from('leave_balances')
            .update({
          'used': SupabaseService.client.rpc('', params: {}).toString(), // can't do arithmetic in update
        }).eq('user_id', userId);

        // Use raw SQL via RPC for atomic update
        try {
          await SupabaseService.client.rpc('approve_leave_balance', params: {
            'p_user_id': userId,
            'p_leave_type_id': leaveTypeId,
            'p_year': year,
            'p_days': days,
          });
        } catch (e) {
          // Fallback: manual update
          final balance = await SupabaseService.client
              .from('leave_balances')
              .select('id, used')
              .eq('user_id', userId)
              .eq('leave_type_id', leaveTypeId)
              .eq('year', year)
              .maybeSingle();
          if (balance != null) {
            final currentUsed = (balance['used'] as num).toDouble();
            await SupabaseService.client
                .from('leave_balances')
                .update({
              'used': currentUsed + days,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', balance['id']);
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave ${status}!'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════
  // REGULARIZATIONS TAB
  // ═══════════════════════════════════════════
  Widget _regularizationsTab() {
    if (_regularizations.isEmpty) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 12),
          Text('No pending regularizations',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _regularizations.length,
        itemBuilder: (context, index) {
          final reg = _regularizations[index];
          final profile = reg['profiles'] as Map<String, dynamic>;
          final date = DateTime.parse(reg['date']);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (profile['full_name'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile['full_name'] ?? 'Unknown',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(DateFormat('d MMM yyyy').format(date),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar,
                        color: Colors.orange, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                if (reg['requested_check_in'] != null)
                  Text(
                    'Check-in: ${DateFormat('hh:mm a').format(DateTime.parse(reg['requested_check_in']).toLocal())}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if (reg['requested_check_out'] != null)
                  Text(
                    'Check-out: ${DateFormat('hh:mm a').format(DateTime.parse(reg['requested_check_out']).toLocal())}',
                    style: const TextStyle(fontSize: 13),
                  ),
                const SizedBox(height: 4),
                Text('Reason: ${reg['reason']}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _reviewRegularization(reg, 'rejected'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red)),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            _reviewRegularization(reg, 'approved'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text('Approve'),
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

  Future<void> _reviewRegularization(
      Map<String, dynamic> reg, String status) async {
    try {
      await SupabaseService.client
          .from('attendance_regularizations')
          .update({
        'status': status,
        'reviewed_by': SupabaseService.userId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', reg['id']);

      // If approved, create/update attendance record
      if (status == 'approved') {
        final existing = await SupabaseService.client
            .from('attendance')
            .select('id')
            .eq('user_id', reg['user_id'])
            .eq('date', reg['date'])
            .maybeSingle();

        if (existing != null) {
          final updates = <String, dynamic>{
            'regularization_status': 'approved',
          };
          if (reg['requested_check_in'] != null) {
            updates['check_in_time'] = reg['requested_check_in'];
          }
          if (reg['requested_check_out'] != null) {
            updates['check_out_time'] = reg['requested_check_out'];
          }
          if (reg['requested_check_in'] != null &&
              reg['requested_check_out'] != null) {
            final cin = DateTime.parse(reg['requested_check_in']);
            final cout = DateTime.parse(reg['requested_check_out']);
            updates['work_hours'] =
                cout.difference(cin).inMinutes / 60.0;
            updates['status'] = 'present';
          }
          await SupabaseService.client
              .from('attendance')
              .update(updates)
              .eq('id', existing['id']);
        } else {
          // Create new attendance record
          final newRecord = <String, dynamic>{
            'user_id': reg['user_id'],
            'date': reg['date'],
            'status': 'present',
            'regularization_status': 'approved',
          };
          if (reg['requested_check_in'] != null) {
            newRecord['check_in_time'] = reg['requested_check_in'];
          }
          if (reg['requested_check_out'] != null) {
            newRecord['check_out_time'] = reg['requested_check_out'];
          }
          if (reg['requested_check_in'] != null &&
              reg['requested_check_out'] != null) {
            final cin = DateTime.parse(reg['requested_check_in']);
            final cout = DateTime.parse(reg['requested_check_out']);
            newRecord['work_hours'] =
                cout.difference(cin).inMinutes / 60.0;
          }
          await SupabaseService.client
              .from('attendance')
              .insert(newRecord);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Regularization $status!'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
