import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'admin_shell.dart';

class AiCommandCenterScreen extends StatefulWidget {
  const AiCommandCenterScreen({super.key});
  @override
  State<AiCommandCenterScreen> createState() => _AiCommandCenterScreenState();
}

class _AiCommandCenterScreenState extends State<AiCommandCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;

  // Data
  List<Map<String, dynamic>> _anomalies = [];
  List<Map<String, dynamic>> _partyHealth = [];
  List<Map<String, dynamic>> _forecast = [];
  Map<String, int> _anomalyCounts = {};
  int _criticalParties = 0;
  int _atRiskParties = 0;
  int _healthyParties = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadAnomalies(),
      _loadPartyHealth(),
      _loadForecast(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAnomalies() async {
    try {
      final data = await SupabaseService.client.rpc('ai_detect_anomalies') as List;
      final list = List<Map<String, dynamic>>.from(data);
      final counts = <String, int>{};
      for (final a in list) {
        final type = a['anomaly_type']?.toString() ?? 'unknown';
        counts[type] = (counts[type] ?? 0) + 1;
      }
      if (mounted) {
        setState(() {
          _anomalies = list;
          _anomalyCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Anomaly load error: $e');
    }
  }

  Future<void> _loadPartyHealth() async {
    try {
      final data = await SupabaseService.client.rpc('ai_party_health_scores') as List;
      final list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _partyHealth = list;
          _criticalParties = list.where((p) => p['out_risk_level'] == 'critical').length;
          _atRiskParties = list.where((p) => p['out_risk_level'] == 'at_risk').length;
          _healthyParties = list.where((p) => p['out_risk_level'] == 'healthy').length;
        });
      }
    } catch (e) {
      debugPrint('Party health load error: $e');
    }
  }

  Future<void> _loadForecast() async {
    try {
      final data = await SupabaseService.client.rpc('ai_revenue_forecast') as List;
      if (mounted) {
        setState(() => _forecast = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('Forecast load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1123),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1123),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3DBFFF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Command Center',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Predictive Intelligence',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber, size: 16),
                const SizedBox(width: 6),
                Text('Anomalies${_anomalies.isNotEmpty ? ' (${_anomalies.length})' : ''}'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite, size: 16),
                const SizedBox(width: 6),
                Text('Party Health${_criticalParties > 0 ? ' ($_criticalParties!)' : ''}'),
              ]),
            ),
            const Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up, size: 16),
                SizedBox(width: 6),
                Text('Revenue Forecast'),
              ]),
            ),
            const Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, size: 16),
                SizedBox(width: 6),
                Text('AI Summary'),
              ]),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _anomalyTab(),
                _partyHealthTab(),
                _forecastTab(),
                _summaryTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 1: ANOMALY DETECTION
  // ═══════════════════════════════════════════
  Widget _anomalyTab() {
    if (_anomalies.isEmpty) {
      return _emptyState(Icons.check_circle_outline, 'No anomalies detected',
          'All field operations look normal');
    }

    final high = _anomalies.where((a) => a['severity'] == 'high').toList();
    final medium = _anomalies.where((a) => a['severity'] == 'medium').toList();
    final low = _anomalies.where((a) => a['severity'] == 'low').toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Anomaly type breakdown
          Row(children: [
            _anomalyKpi('Total', _anomalies.length, const Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            _anomalyKpi('High', high.length, Colors.red),
            const SizedBox(width: 8),
            _anomalyKpi('Medium', medium.length, Colors.orange),
            const SizedBox(width: 8),
            _anomalyKpi('Low', low.length, Colors.blue),
          ]),
          const SizedBox(height: 16),

          // Type breakdown chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _anomalyCounts.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _anomalyColor(e.key).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _anomalyColor(e.key).withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_anomalyIcon(e.key), size: 14, color: _anomalyColor(e.key)),
                  const SizedBox(width: 6),
                  Text('${_anomalyLabel(e.key)}: ${e.value}',
                      style: TextStyle(color: _anomalyColor(e.key), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          if (high.isNotEmpty) ...[
            _sectionLabel('HIGH SEVERITY', Colors.red),
            const SizedBox(height: 8),
            ...high.map(_anomalyCard),
            const SizedBox(height: 16),
          ],
          if (medium.isNotEmpty) ...[
            _sectionLabel('MEDIUM SEVERITY', Colors.orange),
            const SizedBox(height: 8),
            ...medium.map(_anomalyCard),
            const SizedBox(height: 16),
          ],
          if (low.isNotEmpty) ...[
            _sectionLabel('LOW SEVERITY', Colors.blue),
            const SizedBox(height: 8),
            ...low.map(_anomalyCard),
          ],
        ]),
      ),
    );
  }

  Widget _anomalyKpi(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _anomalyCard(Map<String, dynamic> a) {
    final severity = a['severity']?.toString() ?? 'low';
    final color = severity == 'high'
        ? Colors.red
        : severity == 'medium'
            ? Colors.orange
            : Colors.blue;
    final time = a['detected_at'] != null
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(a['detected_at'].toString()).toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_anomalyIcon(a['anomaly_type']?.toString() ?? ''), size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(a['title']?.toString() ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(severity.toUpperCase(),
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(a['description']?.toString() ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        if (time.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.access_time, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              const Spacer(),
              Text(a['user_name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 2: PARTY HEALTH
  // ═══════════════════════════════════════════
  Widget _partyHealthTab() {
    if (_partyHealth.isEmpty) {
      return _emptyState(Icons.store, 'No party data', 'Add parties and visits to see health scores');
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Health distribution
          Row(children: [
            _healthKpi('Critical', _criticalParties, Colors.red),
            const SizedBox(width: 8),
            _healthKpi('At Risk', _atRiskParties, Colors.orange),
            const SizedBox(width: 8),
            _healthKpi('Healthy', _healthyParties, Colors.green),
          ]),
          const SizedBox(height: 16),

          // Health distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: [
              if (_criticalParties > 0)
                Expanded(
                  flex: _criticalParties,
                  child: Container(height: 8, color: Colors.red),
                ),
              if (_atRiskParties > 0)
                Expanded(
                  flex: _atRiskParties,
                  child: Container(height: 8, color: Colors.orange),
                ),
              if (_healthyParties > 0)
                Expanded(
                  flex: _healthyParties,
                  child: Container(height: 8, color: Colors.green),
                ),
            ]),
          ),
          const SizedBox(height: 20),

          // Party list
          ..._partyHealth.map(_partyHealthCard),
        ]),
      ),
    );
  }

  Widget _healthKpi(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _partyHealthCard(Map<String, dynamic> p) {
    final score = p['out_health_score'] as int? ?? 0;
    final risk = p['out_risk_level']?.toString() ?? 'critical';
    final color = risk == 'healthy'
        ? Colors.green
        : risk == 'at_risk'
            ? Colors.orange
            : Colors.red;
    final days = p['out_days_since_visit'] as int? ?? 999;
    final visitTrend = p['out_visit_trend']?.toString() ?? 'stable';
    final orderTrend = p['out_order_trend']?.toString() ?? 'stable';
    final outstanding = (p['out_total_outstanding'] as num?)?.toDouble() ?? 0;
    final factors = p['out_factors'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Score circle
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                strokeWidth: 4,
              ),
              Text('$score',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['out_party_name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(risk.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(p['out_party_type']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (p['out_party_city'] != null) ...[
                  const Text(' · ', style: TextStyle(color: Colors.white38)),
                  Text(p['out_party_city'].toString(),
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        // Metrics row
        Row(children: [
          _metricChip(Icons.calendar_today, days >= 999 ? 'Never' : '${days}d ago', Colors.white54),
          const SizedBox(width: 8),
          _metricChip(
            visitTrend == 'increasing' ? Icons.trending_up : visitTrend == 'declining' ? Icons.trending_down : Icons.trending_flat,
            'Visits: $visitTrend',
            visitTrend == 'increasing' ? Colors.green : visitTrend == 'declining' ? Colors.red : Colors.white54,
          ),
          const SizedBox(width: 8),
          _metricChip(
            orderTrend == 'growing' ? Icons.trending_up : orderTrend == 'declining' ? Icons.trending_down : Icons.trending_flat,
            'Orders: $orderTrend',
            orderTrend == 'growing' ? Colors.green : orderTrend == 'declining' ? Colors.red : Colors.white54,
          ),
        ]),
        const SizedBox(height: 8),

        // Details row
        Row(children: [
          if (outstanding > 0)
            _metricChip(Icons.account_balance_wallet, 'Due: Rs.${outstanding.toStringAsFixed(0)}', Colors.orange),
          if ((factors['visits_30d'] as num? ?? 0) > 0) ...[
            const SizedBox(width: 8),
            _metricChip(Icons.place, '${factors['visits_30d']} visits/30d', Colors.blue),
          ],
          if ((factors['collection_rate'] as num? ?? 0) > 0) ...[
            const SizedBox(width: 8),
            _metricChip(Icons.payments, '${factors['collection_rate']}% collected', Colors.teal),
          ],
        ]),

        // Rep name
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Rep: ${p['out_rep_name'] ?? ''}',
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ),
      ]),
    );
  }

  Widget _metricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 3: REVENUE FORECAST
  // ═══════════════════════════════════════════
  Widget _forecastTab() {
    if (_forecast.isEmpty) {
      return _emptyState(Icons.show_chart, 'No revenue data', 'Orders will power the forecast engine');
    }

    final actuals = _forecast.where((f) => f['is_forecast'] == false).toList();
    final forecasts = _forecast.where((f) => f['is_forecast'] == true).toList();
    final totalActual = actuals.fold<double>(0, (s, f) => s + ((f['actual_revenue'] as num?)?.toDouble() ?? 0));
    final totalForecast = forecasts.fold<double>(0, (s, f) => s + ((f['forecast_revenue'] as num?)?.toDouble() ?? 0));

    // Build chart spots
    final actualSpots = <FlSpot>[];
    final forecastSpots = <FlSpot>[];
    for (var i = 0; i < actuals.length; i++) {
      actualSpots.add(FlSpot(i.toDouble(), ((actuals[i]['actual_revenue'] as num?)?.toDouble() ?? 0)));
    }
    for (var i = 0; i < forecasts.length; i++) {
      forecastSpots.add(FlSpot((actuals.length + i).toDouble(), ((forecasts[i]['forecast_revenue'] as num?)?.toDouble() ?? 0)));
    }

    // Connect actual to forecast
    if (actualSpots.isNotEmpty && forecastSpots.isNotEmpty) {
      forecastSpots.insert(0, actualSpots.last);
    }

    final maxY = [
      ...actualSpots.map((s) => s.y),
      ...forecastSpots.map((s) => s.y),
    ].fold<double>(0, (m, v) => v > m ? v : m);

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // KPIs
          Row(children: [
            Expanded(
              child: _forecastKpi('Last 30 Days', 'Rs.${NumberFormat.compact().format(totalActual)}', Colors.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _forecastKpi('Next 30 Days', 'Rs.${NumberFormat.compact().format(totalForecast)}', const Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _forecastKpi(
                'Trend',
                totalActual > 0
                    ? '${((totalForecast - totalActual) / totalActual * 100).toStringAsFixed(1)}%'
                    : 'N/A',
                totalForecast >= totalActual ? Colors.green : Colors.red,
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Chart
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text('Revenue: Actual vs Forecast',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                height: 220,
                child: LineChart(LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF2A2D3E), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (v, _) => Text(
                          NumberFormat.compact().format(v),
                          style: const TextStyle(color: Colors.white30, fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY * 1.2,
                  lineBarsData: [
                    // Actual line
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.0)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Forecast line
                    if (forecastSpots.isNotEmpty)
                      LineChartBarData(
                        spots: forecastSpots,
                        isCurved: true,
                        color: const Color(0xFF6C63FF),
                        barWidth: 2.5,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [const Color(0xFF6C63FF).withOpacity(0.2), const Color(0xFF6C63FF).withOpacity(0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                  ],
                )),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _chartLegend(Colors.blue, 'Actual (30d)'),
                const SizedBox(width: 20),
                _chartLegend(const Color(0xFF6C63FF), 'Forecast (30d)'),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Daily forecast table
          _sectionLabel('DAILY FORECAST', const Color(0xFF6C63FF)),
          const SizedBox(height: 8),
          ...forecasts.take(7).map((f) {
            final date = f['forecast_date']?.toString() ?? '';
            final rev = (f['forecast_revenue'] as num?)?.toDouble() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
                const SizedBox(width: 10),
                Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Text('Rs.${NumberFormat('#,##,###').format(rev)}',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _forecastKpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
      ]),
    );
  }

  Widget _chartLegend(Color color, String label) {
    return Row(children: [
      Container(width: 20, height: 3, color: color),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]);
  }

  // ═══════════════════════════════════════════
  // TAB 4: AI SUMMARY
  // ═══════════════════════════════════════════
  Widget _summaryTab() {
    final highAnomalies = _anomalies.where((a) => a['severity'] == 'high').length;
    final ghostVisits = _anomalyCounts['ghost_visit'] ?? 0;
    final geofenceBreaches = _anomalyCounts['geofence_breach'] ?? 0;
    final lateCheckins = _anomalyCounts['late_checkin'] ?? 0;
    final expenseSpikes = _anomalyCounts['expense_spike'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Overall health gauge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: highAnomalies > 3
                    ? [Colors.red.shade900, Colors.red.shade700]
                    : highAnomalies > 0
                        ? [Colors.orange.shade900, Colors.orange.shade700]
                        : [Colors.green.shade900, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Icon(
                highAnomalies > 3 ? Icons.error : highAnomalies > 0 ? Icons.warning : Icons.check_circle,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                highAnomalies > 3
                    ? 'Attention Required'
                    : highAnomalies > 0
                        ? 'Some Issues Detected'
                        : 'Operations Look Good',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_anomalies.length} anomalies · $_criticalParties critical parties · $_healthyParties healthy',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          _sectionLabel('AI FINDINGS', const Color(0xFF6C63FF)),
          const SizedBox(height: 10),

          if (ghostVisits > 0)
            _findingCard(
              Icons.timer_off,
              Colors.red,
              '$ghostVisits suspicious ghost visits',
              'Visits under 2 minutes detected — possible fake check-ins. Review these reps.',
            ),
          if (geofenceBreaches > 0)
            _findingCard(
              Icons.gps_off,
              Colors.red,
              '$geofenceBreaches geofence violations',
              'Reps checked in far from the party location. Could indicate location spoofing.',
            ),
          if (lateCheckins > 0)
            _findingCard(
              Icons.schedule,
              Colors.orange,
              '$lateCheckins late attendance check-ins',
              'Employees checking in after 10:30 AM. Consider sending morning reminders.',
            ),
          if (expenseSpikes > 0)
            _findingCard(
              Icons.receipt_long,
              Colors.orange,
              '$expenseSpikes unusual expense claims',
              'Expense amounts significantly higher than the rep\'s historical average.',
            ),
          if (_criticalParties > 0)
            _findingCard(
              Icons.store,
              Colors.red,
              '$_criticalParties parties at critical risk',
              'These parties haven\'t been visited recently and show declining order trends. Immediate action needed.',
            ),
          if (_atRiskParties > 0)
            _findingCard(
              Icons.trending_down,
              Colors.orange,
              '$_atRiskParties parties at risk of churning',
              'Visit frequency or order values declining. Schedule priority visits this week.',
            ),
          if (_anomalies.isEmpty && _criticalParties == 0)
            _findingCard(
              Icons.auto_awesome,
              Colors.green,
              'All clear!',
              'No anomalies or at-risk parties detected. Your field operations are running smoothly.',
            ),

          const SizedBox(height: 20),
          _sectionLabel('RECOMMENDATIONS', Colors.teal),
          const SizedBox(height: 10),

          if (ghostVisits > 0)
            _recommendCard('Set minimum visit duration to 5 minutes in app settings'),
          if (geofenceBreaches > 0)
            _recommendCard('Reduce geofence radius for frequently violated parties'),
          if (_criticalParties > 0)
            _recommendCard('Assign critical parties to top-performing reps this week'),
          if (lateCheckins > 0)
            _recommendCard('Enable automated morning attendance reminders at 9:00 AM'),
          _recommendCard('Review AI Command Center daily for early warning signals'),
        ]),
      ),
    );
  }

  Widget _findingCard(IconData icon, Color color, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _recommendCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.lightbulb_outline, color: Colors.teal, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.teal, fontSize: 12))),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════
  Widget _sectionLabel(String text, Color color) {
    return Text(text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2));
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 60, color: Colors.white12),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 12)),
      ]),
    );
  }

  Color _anomalyColor(String type) {
    switch (type) {
      case 'ghost_visit': return Colors.red;
      case 'geofence_breach': return Colors.deepOrange;
      case 'visit_drop': return Colors.orange;
      case 'expense_spike': return Colors.amber;
      case 'zero_order_visit': return Colors.blue;
      case 'late_checkin': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _anomalyIcon(String type) {
    switch (type) {
      case 'ghost_visit': return Icons.timer_off;
      case 'geofence_breach': return Icons.gps_off;
      case 'visit_drop': return Icons.trending_down;
      case 'expense_spike': return Icons.receipt_long;
      case 'zero_order_visit': return Icons.remove_shopping_cart;
      case 'late_checkin': return Icons.schedule;
      default: return Icons.info;
    }
  }

  String _anomalyLabel(String type) {
    switch (type) {
      case 'ghost_visit': return 'Ghost Visits';
      case 'geofence_breach': return 'Geofence';
      case 'visit_drop': return 'Visit Drop';
      case 'expense_spike': return 'Expense Spike';
      case 'zero_order_visit': return 'Zero Orders';
      case 'late_checkin': return 'Late Check-in';
      default: return type;
    }
  }
}
