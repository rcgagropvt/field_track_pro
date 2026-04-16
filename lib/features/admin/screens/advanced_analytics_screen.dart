import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});
  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;

  // Revenue data
  List<_DailyRevenue> _dailyRevenue = [];
  double _totalRevenue = 0;
  double _totalCollected = 0;
  double _totalOutstanding = 0;

  // Leaderboard
  List<Map<String, dynamic>> _leaderboard = [];

  // Period
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = DateTime.now().subtract(Duration(days: _days));
      final startStr = start.toIso8601String().substring(0, 10);

      // 1. Fetch orders for revenue chart
      final orders = await SupabaseService.client
          .from('orders')
          .select('total_amount, created_at, user_id, payment_status')
          .gte('created_at', '${startStr}T00:00:00')
          .order('created_at');
      final orderList = List<Map<String, dynamic>>.from(orders as List);

      // 2. Fetch collections for collected amount
      final collections = await SupabaseService.client
          .from('collections')
          .select('amount_collected, confirmed_at, user_id, status')
          .eq('status', 'confirmed')
          .gte('created_at', '${startStr}T00:00:00');
      final collList = List<Map<String, dynamic>>.from(collections as List);

      // 3. Fetch employees
      final employees = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, role, email, phone')
          .eq('is_active', true)
          .neq('role', 'admin');
      final empList = List<Map<String, dynamic>>.from(employees as List);

      // 4. Fetch visits
      final visits = await SupabaseService.client
          .from('visits')
          .select('user_id, status, created_at')
          .gte('created_at', '${startStr}T00:00:00');
      final visitList = List<Map<String, dynamic>>.from(visits as List);

      // ── Build daily revenue ──
      final Map<String, double> dailyMap = {};
      double totalRev = 0;
      for (final o in orderList) {
        final date = (o['created_at'] as String).substring(0, 10);
        final amt = _num(o['total_amount']);
        dailyMap[date] = (dailyMap[date] ?? 0) + amt;
        totalRev += amt;
      }
      final dailyRevenue = dailyMap.entries
          .map((e) => _DailyRevenue(date: e.key, amount: e.value))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      double totalColl = 0;
      for (final c in collList) {
        totalColl += _num(c['amount_collected']);
      }

      // ── Build leaderboard ──
      final List<Map<String, dynamic>> board = [];
      for (final emp in empList) {
        final uid = emp['id'] as String;

        final empOrders = orderList.where((o) => o['user_id'] == uid).toList();
        final empRevenue = empOrders.fold<double>(0, (s, o) => s + _num(o['total_amount']));
        final empOrderCount = empOrders.length;

        final empColl = collList.where((c) => c['user_id'] == uid).toList();
        final empCollected = empColl.fold<double>(0, (s, c) => s + _num(c['amount_collected']));

        final empVisits = visitList.where((v) => v['user_id'] == uid).toList();
        final empVisitCount = empVisits.length;
        final completedVisits = empVisits.where((v) => v['status'] == 'completed').length;

        // Score: revenue weight 40%, collection 30%, visits 20%, completion rate 10%
        final maxRev = empList.length > 1 ? 1.0 : 0.0; // normalize later
        final score = empRevenue * 0.4 +
            empCollected * 0.3 +
            empVisitCount * 100 * 0.2 +
            (empVisitCount > 0 ? completedVisits / empVisitCount * 1000 : 0) * 0.1;

        board.add({
          ...emp,
          'revenue': empRevenue,
          'collected': empCollected,
          'orders': empOrderCount,
          'visits': empVisitCount,
          'completed_visits': completedVisits,
          'score': score,
        });
      }
      board.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      // Assign ranks
      for (int i = 0; i < board.length; i++) {
        board[i]['rank'] = i + 1;
      }

      if (mounted) {
        setState(() {
          _dailyRevenue = dailyRevenue;
          _totalRevenue = totalRev;
          _totalCollected = totalColl;
          _totalOutstanding = totalRev - totalColl;
          _leaderboard = board;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AdvancedAnalytics error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Advanced Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Revenue'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Summary'),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: _days,
            onSelected: (v) { _days = v; _load(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text('${_days}d', style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _revenueTab(fmt),
              _leaderboardTab(fmt),
              _summaryTab(fmt),
            ]),
    );
  }

  // ─── REVENUE TAB ───────────────────────────────────────
  Widget _revenueTab(NumberFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // KPI row
        Row(children: [
          _kpi('Total Revenue', '₹${fmt.format(_totalRevenue)}', Colors.blue),
          const SizedBox(width: 10),
          _kpi('Collected', '₹${fmt.format(_totalCollected)}', AppColors.success),
          const SizedBox(width: 10),
          _kpi('Outstanding', '₹${fmt.format(_totalOutstanding)}', AppColors.error),
        ]),
        const SizedBox(height: 20),

        // Revenue trend chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revenue Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Last $_days days', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: _dailyRevenue.isEmpty
                    ? const Center(child: Text('No orders in this period'))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _maxRevenue() / 4,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (v, _) => Text(
                                  '₹${(v / 1000).toStringAsFixed(0)}k',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: (_dailyRevenue.length / 5).ceilToDouble().clamp(1, 999),
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx < 0 || idx >= _dailyRevenue.length) return const SizedBox();
                                  final d = _dailyRevenue[idx].date;
                                  return Text(
                                    '${d.substring(8, 10)}/${d.substring(5, 7)}',
                                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(_dailyRevenue.length,
                                  (i) => FlSpot(i.toDouble(), _dailyRevenue[i].amount)),
                              isCurved: true,
                              color: AppColors.primary,
                              barWidth: 2.5,
                              dotData: FlDotData(show: _dailyRevenue.length < 15),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.primary.withOpacity(0.08),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Collection rate gauge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(children: [
            const Text('Collection Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: CircularProgressIndicator(
                      value: _totalRevenue > 0 ? (_totalCollected / _totalRevenue).clamp(0, 1) : 0,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _totalRevenue > 0 && _totalCollected / _totalRevenue >= 0.8
                            ? AppColors.success
                            : _totalCollected / _totalRevenue >= 0.5
                                ? AppColors.warning
                                : AppColors.error,
                      ),
                    ),
                  ),
                  Text(
                    _totalRevenue > 0
                        ? '${(_totalCollected / _totalRevenue * 100).toStringAsFixed(0)}%'
                        : '0%',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '₹${fmt.format(_totalCollected)} collected of ₹${fmt.format(_totalRevenue)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
        ),
      ]),
    );
  }

  double _maxRevenue() {
    if (_dailyRevenue.isEmpty) return 100;
    return _dailyRevenue.map((d) => d.amount).reduce((a, b) => a > b ? a : b).clamp(100, double.infinity);
  }

  // ─── LEADERBOARD TAB ──────────────────────────────────
  Widget _leaderboardTab(NumberFormat fmt) {
    if (_leaderboard.isEmpty) {
      return const Center(child: Text('No employee data for this period'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Top 3 podium
        if (_leaderboard.length >= 1) _podium(fmt),
        const SizedBox(height: 16),

        // Full list
        Container(
          decoration: _cardDeco(),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leaderboard.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final emp = _leaderboard[i];
              final rank = emp['rank'] as int;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  // Rank
                  SizedBox(
                    width: 30,
                    child: rank <= 3
                        ? Icon(
                            Icons.emoji_events,
                            color: rank == 1
                                ? Colors.amber
                                : rank == 2
                                    ? Colors.grey.shade400
                                    : Colors.brown.shade300,
                            size: 22,
                          )
                        : Text('#$rank',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primarySurface,
                    child: Text(
                      (emp['full_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emp['full_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '${emp['orders']} orders · ${emp['visits']} visits',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Revenue
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${fmt.format(emp['revenue'])}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      Text('₹${fmt.format(emp['collected'])} coll.',
                          style: const TextStyle(fontSize: 10, color: AppColors.success)),
                    ],
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _podium(NumberFormat fmt) {
    final topN = _leaderboard.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Text('Top Performers',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(topN.length, (i) {
            final emp = topN[i];
            final isFirst = i == 0;
            return Column(children: [
              if (isFirst) const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              if (!isFirst) const SizedBox(height: 28),
              CircleAvatar(
                radius: isFirst ? 28 : 22,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  (emp['full_name'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isFirst ? 20 : 16,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                (emp['full_name'] ?? '').toString().split(' ').first,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isFirst ? 14 : 12,
                ),
              ),
              Text(
                '₹${fmt.format(emp['revenue'])}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: isFirst ? 13 : 11,
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }

  // ─── SUMMARY TAB ──────────────────────────────────────
  Widget _summaryTab(NumberFormat fmt) {
    final totalOrders = _leaderboard.fold<int>(0, (s, e) => s + (e['orders'] as int));
    final totalVisits = _leaderboard.fold<int>(0, (s, e) => s + (e['visits'] as int));
    final completedVisits = _leaderboard.fold<int>(0, (s, e) => s + (e['completed_visits'] as int));
    final avgOrderValue = totalOrders > 0 ? _totalRevenue / totalOrders : 0.0;
    final visitCompletionRate = totalVisits > 0 ? completedVisits / totalVisits * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _summaryCard('Total Revenue', '₹${fmt.format(_totalRevenue)}', Icons.trending_up, Colors.blue),
        _summaryCard('Total Collected', '₹${fmt.format(_totalCollected)}', Icons.payments, AppColors.success),
        _summaryCard('Outstanding', '₹${fmt.format(_totalOutstanding)}', Icons.warning_amber, AppColors.error),
        _summaryCard('Total Orders', '$totalOrders', Icons.shopping_bag, Colors.indigo),
        _summaryCard('Avg Order Value', '₹${fmt.format(avgOrderValue)}', Icons.analytics, Colors.purple),
        _summaryCard('Total Visits', '$totalVisits', Icons.place, Colors.orange),
        _summaryCard('Visit Completion', '${visitCompletionRate.toStringAsFixed(1)}%', Icons.check_circle, AppColors.success),
        _summaryCard('Active Reps', '${_leaderboard.length}', Icons.people, AppColors.primary),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco(),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      );
}

class _DailyRevenue {
  final String date;
  final double amount;
  _DailyRevenue({required this.date, required this.amount});
}
