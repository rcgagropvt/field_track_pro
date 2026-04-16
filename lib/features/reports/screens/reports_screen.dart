import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  int _totalVisits = 0;
  int _completedVisits = 0;
  double _totalOrders = 0;
  double _totalPayments = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  double _totalExpenses = 0;
  int _attendanceDays = 0;
  List<Map<String, dynamic>> _recentVisits = [];
  Map<String, int> _visitsByOutcome = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;

      // Attendance this month
      final now = DateTime.now();
      final monthStart =
          DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

      // Visits
      final visits = await SupabaseService.client
          .from('visits')
          .select()
          .eq('user_id', uid)
          .gte('check_in_time', '${monthStart}T00:00:00.000');
      final visitList = List<Map<String, dynamic>>.from(visits ?? []);

      // Tasks
      final tasks = await SupabaseService.client
          .from('tasks')
          .select('id, status')
          .or('assigned_to.eq.$uid,assigned_by.eq.$uid');
      final taskList = List<Map<String, dynamic>>.from(tasks ?? []);

      // Expenses
      final expenses = await SupabaseService.client
          .from('expenses')
          .select('amount, status')
          .eq('user_id', uid);
      final expList = List<Map<String, dynamic>>.from(expenses ?? []);
      final attendance = await SupabaseService.client
          .from('attendance')
          .select('id')
          .eq('user_id', uid)
          .gte('date', monthStart);
      final attList = List<Map<String, dynamic>>.from(attendance ?? []);

      // Calculate
      final completed =
          visitList.where((v) => v['status'] == 'completed').toList();
      double orders = 0;
      double payments = 0;
      Map<String, int> outcomes = {};

      for (final v in visitList) {
        orders += ((v['order_value'] as num?) ?? 0).toDouble();
        payments += ((v['payment_collected'] as num?) ?? 0).toDouble();
        final outcome = (v['outcome'] ?? 'other').toString();
        outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
      }

      double totalExp = 0;
      for (final e in expList) {
        totalExp += ((e['amount'] as num?) ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _totalVisits = visitList.length;
          _completedVisits = completed.length;
          _totalOrders = orders;
          _totalPayments = payments;
          _totalTasks = taskList.length;
          _completedTasks =
              taskList.where((t) => t['status'] == 'completed').length;
          _totalExpenses = totalExp;
          _attendanceDays = attList.length;
          _recentVisits = visitList.take(5).toList();
          _visitsByOutcome = outcomes;
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
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadReports,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This Month',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),

                    // Stats grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.8,
                      children: [
                        _miniStat('Attendance', '$_attendanceDays days',
                            Icons.event_available, AppColors.primary),
                        _miniStat('Visits', '$_completedVisits / $_totalVisits',
                            Icons.storefront, AppColors.success),
                        _miniStat(
                            'Tasks Done',
                            '$_completedTasks / $_totalTasks',
                            Icons.task_alt,
                            AppColors.info),
                        _miniStat(
                            'Expenses',
                            '₹${_totalExpenses.toStringAsFixed(0)}',
                            Icons.receipt,
                            AppColors.warning),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Orders Summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.cardGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Summary',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.white.withOpacity(0.8))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Orders',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70)),
                                    Text('₹${_totalOrders.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.white)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Payments Collected',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70)),
                                    Text(
                                        '₹${_totalPayments.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Visit Outcomes Chart
                    if (_visitsByOutcome.isNotEmpty) ...[
                      const Text('Visit Outcomes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: _buildPieSections(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Legend
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: _visitsByOutcome.entries.map((e) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _outcomeColor(e.key),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('${e.key.replaceAll('_', ' ')} (${e.value})',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ],
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Recent visits
                    if (_recentVisits.isNotEmpty) ...[
                      const Text('Recent Visits',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ...(_recentVisits.map((v) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.storefront,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v['party_name'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                        v['check_in_time'] != null
                                            ? DateFormat('dd MMM').format(
                                                DateTime.parse(
                                                    v['check_in_time']))
                                            : '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (v['order_value'] != null &&
                                    (v['order_value'] as num) > 0)
                                  Text(
                                      '₹${(v['order_value'] as num).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success)),
                              ],
                            ),
                          ))),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final total = _visitsByOutcome.values.fold<int>(0, (s, v) => s + v);
    return _visitsByOutcome.entries.map((e) {
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${((e.value / total) * 100).round()}%',
        color: _outcomeColor(e.key),
        titleStyle: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
        radius: 45,
      );
    }).toList();
  }

  Color _outcomeColor(String outcome) {
    switch (outcome) {
      case 'successful':
        return AppColors.success;
      case 'follow_up_needed':
        return AppColors.warning;
      case 'not_interested':
        return AppColors.error;
      case 'shop_closed':
        return AppColors.textTertiary;
      default:
        return AppColors.info;
    }
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


