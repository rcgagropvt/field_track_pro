import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:field_track_pro/core/services/supabase_service.dart';
import 'employee_list_screen.dart';
import 'live_map_screen.dart';
import 'expense_approval_screen.dart';
import 'assign_task_screen.dart';
import 'admin_analytics_screen.dart';
import 'visit_analytics_screen.dart';
import 'admin_shell.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _dailyVisits = [];
  List<Map<String, dynamic>> _leadPipeline = [];
  List<Map<String, dynamic>> _topPerformers = [];
  List<Map<String, dynamic>> _aiInsights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ✅ Small delay ensures widget is fully mounted before loading
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final stats = await SupabaseService.getAdminDashboardStats();
      if (mounted) {
        setState(() {
          _stats = Map<String, dynamic>.from(stats);
          _loading = false;
        });
        print('STATS LOADED: $_stats');
      }
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.getAdminDashboardStats(),
        SupabaseService.client.rpc('get_daily_visit_counts'),
        SupabaseService.client.rpc('get_lead_pipeline'),
        SupabaseService.client.rpc('get_employee_performance'),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final daily = List<Map<String, dynamic>>.from(results[1] as List);
      final pipeline = List<Map<String, dynamic>>.from(results[2] as List);
      final perf = List<Map<String, dynamic>>.from(results[3] as List);
      setState(() {
        _stats = stats;
        _dailyVisits = daily;
        _leadPipeline = pipeline;
        _topPerformers = perf.take(5).toList();
        _aiInsights = _buildInsights(stats, perf, daily);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildInsights(Map stats, List perf, List daily) {
    final out = <Map<String, dynamic>>[];
    final pending = (stats['pending_expenses'] ?? 0) as int;
    if (pending > 3)
      out.add({
        'icon': '⚠️',
        'color': Colors.red,
        'title': '$pending expense claims need review',
        'subtitle': 'Employees are waiting for reimbursement'
      });
    if (daily.length >= 2) {
      final today = (daily.last['count'] ?? 0) as int;
      final yesterday = (daily[daily.length - 2]['count'] ?? 0) as int;
      if (today > yesterday) {
        out.add({
          'icon': '📈',
          'color': Colors.green,
          'title':
              'Visit activity up ${yesterday > 0 ? ((today - yesterday) / yesterday * 100).toStringAsFixed(0) : 100}% today',
          'subtitle': '$today visits today vs $yesterday yesterday'
        });
      } else if (today < yesterday) {
        out.add({
          'icon': '📉',
          'color': Colors.orange,
          'title': 'Visit activity down today',
          'subtitle':
              'Only $today visits vs $yesterday yesterday — check in with team'
        });
      }
    }
    final total = (stats['total_employees'] ?? 1) as int;
    final checkedIn = (stats['checked_in_today'] ?? 0) as int;
    if (total > 0 && checkedIn / total < 0.6) {
      out.add({
        'icon': '🚨',
        'color': Colors.red,
        'title': 'Low attendance: only $checkedIn/$total checked in',
        'subtitle': 'Send a reminder to absent employees'
      });
    }
    if (perf.isNotEmpty) {
      out.add({
        'icon': '🏆',
        'color': Colors.blue,
        'title': '${perf.first['full_name']} leads performance this month',
        'subtitle':
            '${perf.first['total_visits']} visits · ${perf.first['converted_leads']} deals closed'
      });
    }
    final online = (stats['active_trackers'] ?? 0) as int;
    if (online > 0)
      out.add({
        'icon': '📍',
        'color': Colors.teal,
        'title': '$online employees currently in the field',
        'subtitle': 'Tap Live Map to see real-time positions'
      });
    return out.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('FieldTrack Pro',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Full Analytics',
              onPressed: () => _nav(const AdminAnalyticsScreen())),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await SupabaseService.client.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout')
                  ]))
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => await _loadStats(), // ✅ async wrapper
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _kpiGrid(),
                  const SizedBox(height: 20),
                  if (_aiInsights.isNotEmpty) ...[
                    _header('🤖 AI Insights', null),
                    const SizedBox(height: 8),
                    ..._aiInsights.map(_insightCard),
                    const SizedBox(height: 20),
                  ],
                  _header('📊 Visit Activity — Last 7 Days',
                      () => _nav(const VisitAnalyticsScreen())),
                  const SizedBox(height: 8),
                  _visitBarChart(),
                  const SizedBox(height: 20),
                  _header('🎯 Lead Pipeline',
                      () => _nav(const AdminAnalyticsScreen())),
                  const SizedBox(height: 8),
                  _leadPieChart(),
                  const SizedBox(height: 20),
                  _header('🏆 Top Performers',
                      () => _nav(const AdminAnalyticsScreen())),
                  const SizedBox(height: 8),
                  _performersList(),
                  const SizedBox(height: 20),
                  _header('⚡ Quick Actions', null),
                  const SizedBox(height: 8),
                  _quickActions(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
    );
  }

  void _nav(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _header(String title, VoidCallback? onSeeAll) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          if (onSeeAll != null)
            TextButton(
                onPressed: onSeeAll,
                child: const Text('See All', style: TextStyle(fontSize: 12))),
        ],
      );

  Widget _kpiGrid() {
    final items = [
      _K('Total Staff', '${_stats['total_employees'] ?? 0}', Icons.people,
          Colors.blue),
      _K('Checked In', '${_stats['checked_in_today'] ?? 0}', Icons.login,
          Colors.green),
      _K('Visits Today', '${_stats['total_visits_today'] ?? 0}', Icons.place,
          Colors.orange),
      _K('Total Leads', '${_stats['total_leads'] ?? 0}', Icons.leaderboard,
          Colors.purple),
      _K('Exp. Pending', '${_stats['pending_expenses'] ?? 0}',
          Icons.receipt_long, Colors.red),
      _K('Online Now', '${_stats['active_trackers'] ?? 0}', Icons.gps_fixed,
          Colors.teal),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: items[i].color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(items[i].icon, color: items[i].color, size: 16)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(items[i].value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: items[i].color)),
                Text(items[i].label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ]),
      ),
    );
  }

  Widget _insightCard(Map<String, dynamic> insight) {
    final c = insight['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ]),
      child: Row(children: [
        Text(insight['icon'] as String, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(insight['title'] as String,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(insight['subtitle'] as String,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _visitBarChart() {
    if (_dailyVisits.isEmpty) return _emptyChart('No visit data yet');
    final maxY = _dailyVisits.fold(
        0.0,
        (m, e) => ((e['count'] as int? ?? 0).toDouble() > m
            ? (e['count'] as int).toDouble()
            : m));
    const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: _cardBox(),
      child: SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            maxY: (maxY + 2).ceilToDouble(),
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                        '${rod.toY.toInt()}',
                        const TextStyle(color: Colors.white, fontSize: 11)))),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= _dailyVisits.length) return const Text('');
                        final d = DateTime.tryParse(
                            _dailyVisits[idx]['day']?.toString() ?? '');
                        return Text(d != null ? days[d.weekday - 1] : '',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey));
                      })),
            ),
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
                _dailyVisits.length,
                (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: (_dailyVisits[i]['count'] as int? ?? 0)
                              .toDouble(),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          gradient: const LinearGradient(
                              colors: [Color(0xFF4F8FF7), Color(0xFF7B61FF)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter)),
                    ])),
          ))),
    );
  }

  Widget _leadPieChart() {
    if (_leadPipeline.isEmpty) return _emptyChart('No lead data yet');
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.teal
    ];
    final total =
        _leadPipeline.fold<int>(0, (s, e) => s + (e['count'] as int? ?? 0));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBox(),
      child: Row(children: [
        SizedBox(
            width: 140,
            height: 140,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: List.generate(_leadPipeline.length, (i) {
                final c = (_leadPipeline[i]['count'] as int? ?? 0);
                return PieChartSectionData(
                    value: c.toDouble(),
                    color: colors[i % colors.length],
                    radius: 45,
                    title: total > 0
                        ? '${(c / total * 100).toStringAsFixed(0)}%'
                        : '',
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white));
              }),
            ))),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Total: $total leads',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(
                _leadPipeline.length,
                (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                '${_leadPipeline[i]['status'] ?? ''}: ${_leadPipeline[i]['count']}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                      ]),
                    )),
          ],
        )),
      ]),
    );
  }

  Widget _performersList() {
    if (_topPerformers.isEmpty) return _emptyChart('No performance data yet');
    const medals = ['🥇', '🥈', '🥉'];
    return Container(
      decoration: _cardBox(),
      child: Column(
          children: List.generate(_topPerformers.length, (i) {
        final p = _topPerformers[i];
        return ListTile(
          dense: true,
          leading: Text(i < 3 ? medals[i] : '  ${i + 1}',
              style: const TextStyle(fontSize: 18)),
          title: Text(p['full_name'] ?? '',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
              '${p['total_visits']} visits · ${p['converted_leads']} deals · ${p['attendance_days']} days present',
              style: const TextStyle(fontSize: 11)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
                '${p['performance_score']?.toStringAsFixed(0) ?? 0} pts',
                style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        );
      })),
    );
  }

  Widget _quickActions() {
    final actions = [
      _A('Employees', Icons.people_alt, Colors.blue,
          () => _nav(const EmployeeListScreen())),
      _A('Live Map', Icons.map, Colors.green,
          () => _nav(const LiveMapScreen())),
      _A('Expenses', Icons.check_circle, Colors.orange,
          () => _nav(const ExpenseApprovalScreen())),
      _A('Assign Task', Icons.assignment, Colors.purple,
          () => _nav(const AssignTaskScreen())),
      _A('Analytics', Icons.bar_chart, Colors.indigo,
          () => _nav(const AdminAnalyticsScreen())),
      _A('Visits', Icons.store, Colors.teal,
          () => _nav(const VisitAnalyticsScreen())),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3),
      itemCount: 6,
      itemBuilder: (_, i) => InkWell(
        onTap: actions[i].onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
              color: actions[i].color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: actions[i].color.withOpacity(0.25))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(actions[i].icon, color: actions[i].color, size: 26),
            const SizedBox(height: 6),
            Text(actions[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: actions[i].color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }

  Widget _emptyChart(String msg) => Container(
      height: 100,
      decoration: _cardBox(),
      child:
          Center(child: Text(msg, style: const TextStyle(color: Colors.grey))));

  BoxDecoration _cardBox() => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]);
}

class _K {
  final String label, value;
  final IconData icon;
  final Color color;
  _K(this.label, this.value, this.icon, this.color);
}

class _A {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _A(this.label, this.icon, this.color, this.onTap);
}
