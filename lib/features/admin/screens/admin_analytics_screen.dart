import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:field_track_pro/core/services/supabase_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _performers = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  bool _loading = true;
  String _period = '30'; // days

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
      final start = DateTime.now().subtract(Duration(days: int.parse(_period)));
      final results = await Future.wait([
        SupabaseService.client.rpc('get_employee_performance', params: {
          'start_date': start.toIso8601String().substring(0, 10),
          'end_date': DateTime.now().toIso8601String().substring(0, 10),
        }),
        SupabaseService.client.rpc('get_expense_by_category'),
      ]);
      setState(() {
        _performers = List<Map<String, dynamic>>.from(results[0] as List);
        _expenseCategories =
            List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Analytics & Reports',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Performance'),
            Tab(text: 'Expenses'),
            Tab(text: 'Insights')
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _period,
            onSelected: (v) {
              _period = v;
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '7', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30', child: Text('Last 30 days')),
              const PopupMenuItem(value: '90', child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text('${_period}d', style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _performanceTab(),
              _expensesTab(),
              _insightsTab(),
            ]),
    );
  }

  Widget _performanceTab() {
    if (_performers.isEmpty) {
      return const Center(child: Text('No performance data for this period'));
    }
    final maxScore = _performers.fold(
        0.0,
        (m, e) => ((e['performance_score'] as num?)?.toDouble() ?? 0.0) > m
            ? (e['performance_score'] as num).toDouble()
            : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary stats row
          Row(children: [
            _statCard(
              'Avg Visits',
              _performers.isNotEmpty
                  ? (_performers.fold<int>(0,
                              (s, e) => s + (e['total_visits'] as int? ?? 0)) /
                          _performers.length)
                      .toStringAsFixed(1)
                  : '0',
              Icons.place,
              Colors.orange,
            ),
            const SizedBox(width: 12),
            _statCard(
              'Avg Leads',
              _performers.isNotEmpty
                  ? (_performers.fold<int>(0,
                              (s, e) => s + (e['total_leads'] as int? ?? 0)) /
                          _performers.length)
                      .toStringAsFixed(1)
                  : '0',
              Icons.leaderboard,
              Colors.purple,
            ),
            const SizedBox(width: 12),
            _statCard(
              'Conversions',
              '${_performers.fold<int>(0, (s, e) => s + (e['converted_leads'] as int? ?? 0))}',
              Icons.handshake,
              Colors.green,
            ),
          ]),
          const SizedBox(height: 20),

          // Performance horizontal bar chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee Performance Score',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: _performers.length * 52.0,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.center,
                      maxY: (maxScore + 10).ceilToDouble(),
                      barGroups: List.generate(_performers.length, (i) {
                        final score =
                            (_performers[i]['performance_score'] as num?)
                                    ?.toDouble() ??
                                0;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: score,
                              width: 18,
                              color: i == 0
                                  ? Colors.amber
                                  : i == 1
                                      ? Colors.grey.shade400
                                      : i == 2
                                          ? Colors.brown.shade300
                                          : Colors.blue.shade300,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 100,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i >= 0 && i < _performers.length) {
                                final name = (_performers[i]['full_name'] ?? '')
                                    .toString();
                                return Text(
                                  name.length > 12
                                      ? '${name.substring(0, 12)}..'
                                      : name,
                                  style: const TextStyle(fontSize: 11),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Detailed table
          Container(
            decoration: _card(),
            child: Column(
              children: [
                // Table header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 2,
                          child: Text('Employee',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey))),
                      Expanded(
                          child: Text('Visits',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Leads',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Won',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Days',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Table rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _performers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _performers[i];
                    final conv = p['converted_leads'] as int? ?? 0;
                    final leads = p['total_leads'] as int? ?? 0;
                    final convRate = leads > 0
                        ? (conv / leads * 100).toStringAsFixed(0)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  (p['full_name'] ?? 'U')
                                      .toString()[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p['full_name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ),
                          Expanded(
                            child: Text(
                              '${p['total_visits'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${p['total_leads'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$conv ($convRate%)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${p['attendance_days'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expensesTab() {
    if (_expenseCategories.isEmpty) {
      return const Center(child: Text('No approved expenses in this period'));
    }
    final total = _expenseCategories.fold<double>(
        0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.teal
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie chart card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(_expenseCategories.length, (i) {
                        final amt = (_expenseCategories[i]['total'] as num?)
                                ?.toDouble() ??
                            0;
                        return PieChartSectionData(
                          value: amt,
                          color: colors[i % colors.length],
                          radius: 48,
                          title: total > 0
                              ? '${(amt / total * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const Text('Total Approved',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _expenseCategories.length,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _expenseCategories[i]['category'] ?? '',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₹${(_expenseCategories[i]['total'] as num?)?.toStringAsFixed(0) ?? '0'}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category breakdown list
          Container(
            decoration: _card(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 2,
                          child: Text('Category',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey))),
                      Expanded(
                          child: Text('Claims',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _expenseCategories.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = _expenseCategories[i];
                    final amt = (e['total'] as num?)?.toDouble() ?? 0;
                    final pct = total > 0 ? amt / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                e['category'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${e['count'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '₹${amt.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.green),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colors[i % colors.length]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightsTab() {
    if (_performers.isEmpty) return const Center(child: Text('No data yet'));
    final totalVisits = _performers.fold<int>(
        0, (s, e) => s + (e['total_visits'] as int? ?? 0));
    final totalLeads =
        _performers.fold<int>(0, (s, e) => s + (e['total_leads'] as int? ?? 0));
    final totalConv = _performers.fold<int>(
        0, (s, e) => s + (e['converted_leads'] as int? ?? 0));
    final convRate = totalLeads > 0 ? totalConv / totalLeads * 100 : 0.0;
    final topPerf = _performers.isNotEmpty ? _performers.first : null;
    final bottomPerf = _performers.length > 1 ? _performers.last : null;

    final insights = [
      _Insight('🎯', 'Conversion Rate', '${convRate.toStringAsFixed(1)}%',
          '$totalConv deals won out of $totalLeads leads', Colors.green),
      _Insight(
          '📊',
          'Team Visit Average',
          '${_performers.isNotEmpty ? (totalVisits / _performers.length).toStringAsFixed(1) : 0}',
          'visits per employee in last ${_period} days',
          Colors.blue),
      if (topPerf != null)
        _Insight(
            '🏆',
            'Star Performer',
            topPerf['full_name'] ?? '',
            '${topPerf['total_visits']} visits · ${topPerf['converted_leads']} deals · ${topPerf['performance_score']?.toStringAsFixed(0)} pts',
            Colors.amber),
      if (bottomPerf != null)
        _Insight(
            '📌',
            'Needs Coaching',
            bottomPerf['full_name'] ?? '',
            'Only ${bottomPerf['total_visits']} visits in last ${_period} days — consider 1:1',
            Colors.orange),
      _Insight(
          '💡',
          'Predicted Next Month',
          '${(totalVisits * 1.05).toStringAsFixed(0)} visits',
          'Based on current activity trend (+5% projected)',
          Colors.purple),
      _Insight(
          '💰',
          'Revenue Potential',
          '${((totalConv * 1.12)).toStringAsFixed(0)} deals',
          'If conversion rate improves by 5%, projected gain',
          Colors.teal),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          children: insights
              .map((ins) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ins.color.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6)
                        ]),
                    child: Row(children: [
                      Text(ins.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(ins.label,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                            Text(ins.value,
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: ins.color)),
                            Text(ins.detail,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ])),
                    ]),
                  ))
              .toList()),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _card(),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ));

  BoxDecoration _card() => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]);
}

class _Insight {
  final String emoji, label, value, detail;
  final Color color;
  _Insight(this.emoji, this.label, this.value, this.detail, this.color);
}
