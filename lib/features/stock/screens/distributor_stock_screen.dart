import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';

class DistributorStockScreen extends StatefulWidget {
  const DistributorStockScreen({super.key});

  @override
  State<DistributorStockScreen> createState() =>
      _DistributorStockScreenState();
}

class _DistributorStockScreenState extends State<DistributorStockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _filter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      final filters = ['all', 'out_of_stock', 'low', 'adequate'];
      if (_tabs.indexIsChanging) return;
      setState(() => _filter = filters[_tabs.index]);
      _applyFilter();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('distributor_stock')
          .select('''
            *,
            parties(name, city, type),
            products(name, sku, unit),
            profiles(full_name)
          ''')
          .order('stock_status')
          .order('last_checked', ascending: false);

      if (mounted) {
        setState(() {
          _allEntries = List<Map<String, dynamic>>.from(data);
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('DistributorStock load error: \$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allEntries.where((e) {
        final matchFilter = _filter == 'all' || e['stock_status'] == _filter;
        final partyName =
            (e['parties'] as Map?)?['name']?.toString().toLowerCase() ?? '';
        final productName =
            (e['products'] as Map?)?['name']?.toString().toLowerCase() ?? '';
        final matchSearch =
            q.isEmpty || partyName.contains(q) || productName.contains(q);
        return matchFilter && matchSearch;
      }).toList();
    });
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'out_of_stock':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'out_of_stock':
        return 'Out of Stock';
      case 'low':
        return 'Low Stock';
      default:
        return 'Adequate';
    }
  }

  Map<String, int> get _counts => {
        'out_of_stock': _allEntries
            .where((e) => e['stock_status'] == 'out_of_stock')
            .length,
        'low': _allEntries.where((e) => e['stock_status'] == 'low').length,
        'adequate':
            _allEntries.where((e) => e['stock_status'] == 'adequate').length,
      };

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributor Stock'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'All'),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Stock-Out'),
                if (counts['out_of_stock']! > 0) ...[
                  const SizedBox(width: 4),
                  _badge(counts['out_of_stock']!, Colors.red),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Low'),
                if (counts['low']! > 0) ...[
                  const SizedBox(width: 4),
                  _badge(counts['low']!, Colors.orange),
                ],
              ]),
            ),
            const Tab(text: 'Adequate'),
          ],
        ),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _kpiCard('Total SKUs', '\${_allEntries.length}', AppColors.primary),
            const SizedBox(width: 8),
            _kpiCard('Stock-Outs', '\${counts["out_of_stock"]}', Colors.red),
            const SizedBox(width: 8),
            _kpiCard('Low Stock', '\${counts["low"]}', Colors.orange),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilter(),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by party or product...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
                  ? _emptyState()
                  : TabBarView(
                      controller: _tabs,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(4, (_) => _buildList()),
                    ),
        ),
      ]),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildCard(_filtered[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> entry) {
    final party = (entry['parties'] as Map?) ?? {};
    final product = (entry['products'] as Map?) ?? {};
    final rep = (entry['profiles'] as Map?) ?? {};
    final status = entry['stock_status'] as String? ?? 'adequate';
    final statusColor = _statusColor(status);
    final qty = entry['quantity'] as int? ?? 0;
    final threshold = entry['low_stock_threshold'] as int? ?? 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '\$qty',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: statusColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(product['name'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.store, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '\${party["name"] ?? ""} • \${party["city"] ?? ""}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              'Rep: \${rep["full_name"] ?? "Unknown"} • Low at: \$threshold \${product["unit"] ?? "pcs"}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel(status),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor),
          ),
        ),
      ]),
    );
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _badge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(10)),
      child: Text('\$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined,
            size: 64, color: AppColors.textTertiary),
        const SizedBox(height: 12),
        const Text('No stock records',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        const Text('Stock checks by reps will appear here',
            style: TextStyle(
                fontSize: 13, color: AppColors.textTertiary)),
      ]),
    );
  }
}
