import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _leaveTypes = [];
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
      final userId = SupabaseService.userId!;
      final now = DateTime.now();
      final year = now.month >= 4 ? now.year : now.year - 1;

      final results = await Future.wait([
        SupabaseService.client
            .from('leave_balances')
            .select('*, leave_types!inner(name, code, is_paid)')
            .eq('user_id', userId)
            .eq('year', year),
        SupabaseService.client
            .from('leave_applications')
            .select('*, leave_types!inner(name, code)')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50),
        SupabaseService.client
            .from('leave_types')
            .select()
            .eq('is_active', true)
            .order('sort_order'),
      ]);

      _balances = List<Map<String, dynamic>>.from(results[0] as List);
      _applications = List<Map<String, dynamic>>.from(results[1] as List);
      _leaveTypes = List<Map<String, dynamic>>.from(results[2] as List);
    } catch (e) {
      debugPrint('Load leave data error: $e');
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
          tabs: const [
            Tab(text: 'Balance'),
            Tab(text: 'Applications'),
            Tab(text: 'Policy'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyLeaveDialog,
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _balanceTab(),
                _applicationsTab(),
                _policyTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // BALANCE TAB
  // ═══════════════════════════════════════════
  Widget _balanceTab() {
    if (_balances.isEmpty) {
      return const Center(child: Text('No leave balances found'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Total Available Leaves',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _totalAvailable().toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'FY ${_currentFY()}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Per-type cards
          ..._balances.map((b) => _balanceCard(b)),
        ],
      ),
    );
  }

  double _totalAvailable() {
    double total = 0;
    for (final b in _balances) {
      final available = (b['opening_balance'] as num).toDouble() +
          (b['credited'] as num).toDouble() +
          (b['adjusted'] as num).toDouble() -
          (b['used'] as num).toDouble() -
          (b['encashed'] as num).toDouble();
      if (available > 0) total += available;
    }
    return total;
  }

  String _currentFY() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return '$year-${(year + 1).toString().substring(2)}';
  }

  Widget _balanceCard(Map<String, dynamic> b) {
    final lt = b['leave_types'] as Map<String, dynamic>;
    final code = lt['code'] ?? '';
    final name = lt['name'] ?? '';
    final isPaid = lt['is_paid'] ?? true;
    final opening = (b['opening_balance'] as num).toDouble();
    final credited = (b['credited'] as num).toDouble();
    final adjusted = (b['adjusted'] as num).toDouble();
    final used = (b['used'] as num).toDouble();
    final encashed = (b['encashed'] as num).toDouble();
    final available = opening + credited + adjusted - used - encashed;
    final total = opening + credited + adjusted;

    final color = _leaveColor(code);
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(code,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              if (!isPaid)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Unpaid',
                      style:
                          TextStyle(fontSize: 10, color: Colors.red.shade700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _balanceStat('Available', available, color, bold: true),
              _balanceStat('Used', used, Colors.grey.shade600),
              _balanceStat('Total', total, Colors.grey.shade600),
              if (encashed > 0)
                _balanceStat('Encashed', encashed, Colors.amber.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceStat(String label, double value, Color color,
      {bool bold = false}) {
    return Column(
      children: [
        Text(value.toStringAsFixed(1),
            style: TextStyle(
                fontSize: bold ? 18 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Color _leaveColor(String code) {
    switch (code) {
      case 'CL':
        return Colors.blue;
      case 'SL':
        return Colors.red;
      case 'EL':
        return Colors.green;
      case 'CO':
        return Colors.teal;
      case 'LWP':
        return Colors.grey;
      case 'ML':
        return Colors.pink;
      case 'PL':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  // ═══════════════════════════════════════════
  // APPLICATIONS TAB
  // ═══════════════════════════════════════════
  Widget _applicationsTab() {
    if (_applications.isEmpty) {
      return const Center(
          child: Text('No leave applications yet',
              style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final app = _applications[index];
          final lt = app['leave_types'] as Map<String, dynamic>;
          final status = app['status'] ?? 'pending';
          final fromDate = DateTime.parse(app['from_date']);
          final toDate = DateTime.parse(app['to_date']);
          final days = (app['days'] as num).toDouble();

          Color statusColor;
          IconData statusIcon;
          switch (status) {
            case 'approved':
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
              break;
            case 'rejected':
              statusColor = Colors.red;
              statusIcon = Icons.cancel;
              break;
            case 'cancelled':
              statusColor = Colors.grey;
              statusIcon = Icons.block;
              break;
            default:
              statusColor = Colors.orange;
              statusIcon = Icons.hourglass_empty;
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
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _leaveColor(lt['code']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${lt['code']}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _leaveColor(lt['code']))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(lt['name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 4),
                    Text(status.toString().toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      fromDate == toDate
                          ? DateFormat('d MMM yyyy').format(fromDate)
                          : '${DateFormat('d MMM').format(fromDate)} - ${DateFormat('d MMM yyyy').format(toDate)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        days == 0.5 ? 'Half Day' : '${days.toStringAsFixed(days == days.roundToDouble() ? 0 : 1)} days',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (app['reason'] != null &&
                    app['reason'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(app['reason'],
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
                if (app['review_remarks'] != null &&
                    app['review_remarks'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.comment, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(app['review_remarks'],
                              style: TextStyle(
                                  fontSize: 11, color: statusColor)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _cancelLeave(app['id']),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red, padding: EdgeInsets.zero),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancelLeave(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave?'),
        content: const Text('Are you sure you want to cancel this leave application?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client.from('leave_applications').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Leave cancelled'),
            backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════
  // POLICY TAB
  // ═══════════════════════════════════════════
  Widget _policyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._leaveTypes.where((lt) => lt['is_active'] == true).map((lt) {
          final color = _leaveColor(lt['code']);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(lt['code'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: color)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(lt['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    if (lt['is_paid'] != true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Unpaid',
                            style: TextStyle(
                                fontSize: 10, color: Colors.red.shade700)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _policyChip('Quota', '${lt['annual_quota']} days/yr'),
                    if ((lt['monthly_accrual'] as num).toDouble() > 0)
                      _policyChip('Accrual',
                          '${lt['monthly_accrual']} days/month'),
                    if ((lt['max_carry_forward'] as num).toInt() > 0)
                      _policyChip('Carry Forward',
                          '${lt['max_carry_forward']} days max'),
                    if ((lt['max_encashable'] as num).toInt() > 0)
                      _policyChip(
                          'Encashable', '${lt['max_encashable']} days max'),
                    _policyChip(
                        'Max Consecutive', '${lt['max_consecutive_days']} days'),
                    if (lt['requires_attachment'] == true)
                      _policyChip('Certificate',
                          'After ${lt['attachment_after_days']} days'),
                    if (lt['gender_applicable'] != 'all')
                      _policyChip('Gender', lt['gender_applicable']),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _policyChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // APPLY LEAVE DIALOG
  // ═══════════════════════════════════════════
  void _showApplyLeaveDialog() {
    String? selectedTypeId;
    DateTime? fromDate;
    DateTime? toDate;
    bool isHalfDay = false;
    String halfDayType = 'first_half';
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final applicableTypes = _leaveTypes.where((lt) {
            if (lt['is_active'] != true) return false;
            if (lt['code'] == 'LWP') return true;
            if (lt['code'] == 'CO') return true;
            return true;
          }).toList();

          double days = 0;
          if (fromDate != null && toDate != null) {
            if (isHalfDay) {
              days = 0.5;
            } else {
              days = toDate!.difference(fromDate!).inDays + 1.0;
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Apply Leave',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Leave type dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Leave Type',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedTypeId,
                    items: applicableTypes.map((lt) {
                      return DropdownMenuItem(
                        value: lt['id'] as String,
                        child: Text('${lt['code']} - ${lt['name']}'),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setSheetState(() => selectedTypeId = v),
                  ),
                  const SizedBox(height: 12),

                  // Half day toggle
                  SwitchListTile(
                    title: const Text('Half Day'),
                    contentPadding: EdgeInsets.zero,
                    value: isHalfDay,
                    onChanged: (v) => setSheetState(() {
                      isHalfDay = v;
                      if (v && fromDate != null) toDate = fromDate;
                    }),
                  ),

                  if (isHalfDay) ...[
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('1st Half',
                                style: TextStyle(fontSize: 13)),
                            value: 'first_half',
                            groupValue: halfDayType,
                            onChanged: (v) =>
                                setSheetState(() => halfDayType = v!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('2nd Half',
                                style: TextStyle(fontSize: 13)),
                            value: 'second_half',
                            groupValue: halfDayType,
                            onChanged: (v) =>
                                setSheetState(() => halfDayType = v!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Date pickers
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today, size: 20),
                          title: Text(
                            fromDate != null
                                ? DateFormat('d MMM yyyy').format(fromDate!)
                                : 'From Date',
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 7)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                fromDate = picked;
                                if (isHalfDay ||
                                    toDate == null ||
                                    toDate!.isBefore(picked)) {
                                  toDate = picked;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      if (!isHalfDay)
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.calendar_today, size: 20),
                            title: Text(
                              toDate != null
                                  ? DateFormat('d MMM yyyy').format(toDate!)
                                  : 'To Date',
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fromDate ?? DateTime.now(),
                                firstDate: fromDate ?? DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() => toDate = picked);
                              }
                            },
                          ),
                        ),
                    ],
                  ),

                  if (days > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${days == 0.5 ? "Half" : days.toStringAsFixed(days == days.roundToDouble() ? 0 : 1)} day${days > 1 ? "s" : ""}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14),
                      ),
                    ),

                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'e.g. Family function, not feeling well...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => _submitLeave(
                        ctx,
                        typeId: selectedTypeId,
                        fromDate: fromDate,
                        toDate: toDate,
                        days: days,
                        isHalfDay: isHalfDay,
                        halfDayType: halfDayType,
                        reason: reasonController.text,
                      ),
                      child: const Text('Submit Application',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitLeave(
    BuildContext ctx, {
    required String? typeId,
    required DateTime? fromDate,
    required DateTime? toDate,
    required double days,
    required bool isHalfDay,
    required String halfDayType,
    required String reason,
  }) async {
    if (typeId == null || fromDate == null || toDate == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    try {
      await SupabaseService.client.from('leave_applications').insert({
        'user_id': SupabaseService.userId,
        'leave_type_id': typeId,
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
        'days': days,
        'half_day_type': isHalfDay ? halfDayType : null,
        'reason': reason.trim(),
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
