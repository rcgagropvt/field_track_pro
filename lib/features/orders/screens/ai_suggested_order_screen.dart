import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class AiSuggestedOrderScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  const AiSuggestedOrderScreen({super.key, required this.party});
  @override
  State<AiSuggestedOrderScreen> createState() => _AiSuggestedOrderScreenState();
}

class _AiSuggestedOrderScreenState extends State<AiSuggestedOrderScreen> {
  List<Map<String, dynamic>> _predictions = [];
  final Map<String, int> _selectedQty = {};
  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .rpc('ai_predict_order', params: {'p_party_id': widget.party['id']}) as List;
      final list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _predictions = list;
          for (final p in list) {
            final pid = p['product_id'].toString();
            _selected.add(pid);
            _selectedQty[pid] = (p['suggested_qty'] as int?) ?? 1;
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AI predict error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _estimatedTotal {
    double total = 0;
    for (final p in _predictions) {
      final pid = p['product_id'].toString();
      if (!_selected.contains(pid)) continue;
      final qty = _selectedQty[pid] ?? 0;
      final price = (p['avg_unit_price'] as num?)?.toDouble() ?? 0;
      total += qty * price;
    }
    return total;
  }

  int get _selectedCount => _selected.length;

  void _sendToCart() {
    final cartItems = <Map<String, dynamic>>[];
    for (final p in _predictions) {
      final pid = p['product_id'].toString();
      if (!_selected.contains(pid)) continue;
      final qty = _selectedQty[pid] ?? 1;
      final price = (p['avg_unit_price'] as num?)?.toDouble() ?? 0;
      cartItems.add({
        'product_id': p['product_id'],
        'product_name': p['product_name'],
        'product_sku': p['product_sku'] ?? '',
        'unit': 'pcs',
        'quantity': qty,
        'unit_price': price,
        'tax_percent': 0.0,
        'discount_percent': 0.0,
        'line_total': qty * price,
        'mrp': price,
      });
    }
    Navigator.pop(context, cartItems);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Suggested Order',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Based on purchase history',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _predictions.isEmpty
              ? _emptyState()
              : Column(children: [
                  // Party header
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Icon(Icons.psychology, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.party['name'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              '${_predictions.length} products predicted · ${_selectedCount} selected',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),

                  // Product list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _predictions.length,
                      itemBuilder: (_, i) => _productCard(_predictions[i], i),
                    ),
                  ),

                  // Bottom bar
                  if (_selectedCount > 0) _bottomBar(),
                ]),
    );
  }

  Widget _productCard(Map<String, dynamic> p, int index) {
    final pid = p['product_id'].toString();
    final isSelected = _selected.contains(pid);
    final qty = _selectedQty[pid] ?? 1;
    final price = (p['avg_unit_price'] as num?)?.toDouble() ?? 0;
    final confidence = p['confidence']?.toString() ?? 'low';
    final timesOrdered = (p['times_ordered'] as num?)?.toInt() ?? 0;
    final avgQty = (p['avg_qty'] as num?)?.toDouble() ?? 0;
    final lastQty = (p['last_ordered_qty'] as int?) ?? 0;
    final daysSince = (p['days_since_last_order'] as int?) ?? 999;

    final confColor = confidence == 'high'
        ? Colors.green
        : confidence == 'medium'
            ? Colors.orange
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary.withOpacity(0.4) : AppColors.divider,
        ),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selected.remove(pid);
              } else {
                _selected.add(pid);
              }
            });
          },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['product_name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(children: [
                    if (p['product_sku'] != null)
                      Text('${p['product_sku']}  ·  ',
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('₹${price.toStringAsFixed(2)}/unit',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ]),
                ]),
              ),
              // Confidence badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: confColor.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.psychology, size: 11, color: confColor),
                  const SizedBox(width: 3),
                  Text(confidence.toUpperCase(),
                      style: TextStyle(color: confColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
        ),

        if (isSelected) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: [
              // AI insights row
              Row(children: [
                _insightChip(Icons.history, 'Ordered $timesOrdered times'),
                const SizedBox(width: 8),
                _insightChip(Icons.analytics, 'Avg qty: ${avgQty.toStringAsFixed(0)}'),
                const SizedBox(width: 8),
                _insightChip(Icons.shopping_bag, 'Last: $lastQty'),
              ]),
              if (daysSince < 999)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    _insightChip(
                      Icons.calendar_today,
                      daysSince == 0 ? 'Ordered today' : '$daysSince days since last order',
                    ),
                  ]),
                ),
              const SizedBox(height: 12),

              // Quantity controls + total
              Row(children: [
                const Text('Qty: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _qtyBtn(Icons.remove, () {
                      if (qty > 1) setState(() => _selectedQty[pid] = qty - 1);
                    }),
                    Container(
                      width: 50,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('$qty',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    _qtyBtn(Icons.add, () {
                      setState(() => _selectedQty[pid] = qty + 1);
                    }),
                  ]),
                ),
                const Spacer(),
                Text('₹${(qty * price).toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ]),
            ]),
          ),
        ],
      ]),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn(duration: 250.ms).slideX(begin: 0.03);
  }

  Widget _insightChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 9, color: Colors.grey.shade700)),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_selectedCount products selected',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text('Est. ₹${_estimatedTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _sendToCart,
            icon: const Icon(Icons.shopping_cart, size: 18),
            label: const Text('Add to Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.psychology, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No order history found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
        const Text('Place orders to train the AI prediction model',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}
