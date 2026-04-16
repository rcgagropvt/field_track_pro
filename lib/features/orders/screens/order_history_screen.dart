import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.userId ?? '';
      List<dynamic> data;

      if (_statusFilter != 'all') {
        data = await SupabaseService.client
            .from('orders')
            .select()
            .eq('user_id', uid)
            .eq('status', _statusFilter)
            .order('created_at', ascending: false)
            .limit(50);
      } else {
        data = await SupabaseService.client
            .from('orders')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(50);
      }

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':
        return AppColors.info;
      case 'confirmed':
        return AppColors.leadQualified;
      case 'dispatched':
        return AppColors.warning;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'placed', child: Text('Placed')),
              const PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
              const PopupMenuItem(
                  value: 'dispatched', child: Text('Dispatched')),
              const PopupMenuItem(value: 'delivered', child: Text('Delivered')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _orders.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Orders Yet',
                  subtitle: 'Orders placed during visits will appear here',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final createdAt = order['created_at'] != null
                          ? DateTime.tryParse(order['created_at'])
                          : null;

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailScreen(orderId: order['id']),
                            ),
                          );
                          _load();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order number + status
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                              order['status'] ?? 'placed')
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.receipt_rounded,
                                      color: _statusColor(
                                          order['status'] ?? 'placed'),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order['order_number'] ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          order['party_name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(
                                      status: order['status'] ?? 'placed'),
                                ],
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Amount + Date
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹${(order['total_amount'] ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    createdAt != null
                                        ? DateFormat('dd MMM yyyy, hh:mm a')
                                            .format(createdAt.toLocal())
                                        : '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),

                              // Payment info
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.payment_rounded,
                                      size: 14, color: AppColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    (order['payment_mode'] ?? 'credit')
                                        .toString()
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (order['payment_status'] == 'paid'
                                              ? AppColors.success
                                              : AppColors.warning)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (order['payment_status'] ?? 'unpaid')
                                          .toString()
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: order['payment_status'] == 'paid'
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(delay: Duration(milliseconds: index * 50))
                          .fadeIn(duration: 250.ms)
                          .slideX(begin: 0.03);
                    },
                  ),
                ),
    );
  }
}


