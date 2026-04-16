import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/status_badge.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final order = await SupabaseService.client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();

      final items = await SupabaseService.client
          .from('order_items')
          .select()
          .eq('order_id', widget.orderId)
          .order('created_at');

      if (mounted) {
        setState(() {
          _order = order;
          _items = List<Map<String, dynamic>>.from(items);
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
      appBar: AppBar(
        title: Text(_order?['order_number'] ?? 'Order Detail'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _order == null
              ? const Center(child: Text('Order not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.cardGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _order!['order_number'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  StatusBadge(
                                      status: _order!['status'] ?? ''),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _order!['party_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      AppColors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              if (_order!['party_address'] != null)
                                Text(
                                  _order!['party_address'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.white
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Text(
                                '₹${(_order!['total_amount'] ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Order info
                        _sectionTitle('Order Information'),
                        const SizedBox(height: 8),
                        _infoCard([
                          _infoRow(
                              'Date',
                              _order!['created_at'] != null
                                  ? DateFormat('dd MMM yyyy, hh:mm a').format(
                                      DateTime.parse(_order!['created_at'])
                                          .toLocal())
                                  : 'N/A'),
                          _infoRow(
                              'Payment Mode',
                              (_order!['payment_mode'] ?? 'credit')
                                  .toString()
                                  .toUpperCase()),
                          _infoRow(
                              'Payment Status',
                              (_order!['payment_status'] ?? 'unpaid')
                                  .toString()
                                  .toUpperCase()),
                          if (_order!['notes'] != null &&
                              _order!['notes'].toString().isNotEmpty)
                            _infoRow('Notes', _order!['notes']),
                        ]),

                        const SizedBox(height: 20),

                        // Items
                        _sectionTitle('Items (${_items.length})'),
                        const SizedBox(height: 8),
                        ..._items.map((item) => _buildItemCard(item)),

                        const SizedBox(height: 20),

                        // Summary
                        _sectionTitle('Summary'),
                        const SizedBox(height: 8),
                        _infoCard([
                          _infoRow('Subtotal',
                              '₹${(_order!['subtotal'] ?? 0).toStringAsFixed(2)}'),
                          _infoRow('Tax',
                              '₹${(_order!['tax_amount'] ?? 0).toStringAsFixed(2)}'),
                          _infoRow('Discount',
                              '-₹${(_order!['discount_amount'] ?? 0).toStringAsFixed(2)}'),
                          const Divider(),
                          _infoRow('Total',
                              '₹${(_order!['total_amount'] ?? 0).toStringAsFixed(2)}',
                              isBold: true),
                        ]),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isBold
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              )),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 16 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold ? AppColors.primary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.inventory_2_rounded,
                  color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item['product_sku'] ?? ''}  •  ${item['quantity']} × ₹${(item['unit_price'] ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
                if ((item['discount_percent'] ?? 0) > 0)
                  Text(
                    'Discount: ${item['discount_percent']}%',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.success),
                  ),
              ],
            ),
          ),
          Text(
            '₹${(item['line_total'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}


