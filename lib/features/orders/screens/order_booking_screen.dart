import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../core/widgets/custom_button.dart';
import '../../catalog/screens/product_catalog_screen.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/services/scheme_service.dart';
import '../../../core/services/collection_service.dart';

class OrderBookingScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  final String? visitId;
  final List<Map<String, dynamic>>? prefillItems;

  const OrderBookingScreen({
    super.key,
    required this.party,
    this.visitId,
    this.prefillItems,
  });

  @override
  State<OrderBookingScreen> createState() => _OrderBookingScreenState();
}

class _OrderBookingScreenState extends State<OrderBookingScreen> {
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentMode = 'credit';
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  List<AppliedScheme> _appliedSchemes = [];
  double _schemeDiscount = 0;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Pre-fill AI suggested items
    if (widget.prefillItems != null && widget.prefillItems!.isNotEmpty) {
      _cartItems.addAll(widget.prefillItems!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _applySchemes());
    }

    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() => _isOffline = result == ConnectivityResult.none);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOffline = result == ConnectivityResult.none);
  }

  double get _subtotal =>
      _cartItems.fold(0, (sum, item) => sum + (item['line_total'] as double));

  double get _taxAmount => _cartItems.fold(
        0,
        (sum, item) =>
            sum +
            ((item['line_total'] as double) *
                (item['tax_percent'] as double) /
                100),
      );

  double get _totalAmount => _subtotal + _taxAmount - _schemeDiscount;

  int get _totalItems =>
      _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));

  Future<void> _addProduct() async {
    final product = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductCatalogScreen(selectionMode: true),
      ),
    );
    if (product == null) return;

    final existingIdx =
        _cartItems.indexWhere((i) => i['product_id'] == product['id']);
    if (existingIdx >= 0) {
      _showSnack('Product already in cart. Update quantity instead.');
      return;
    }

    final unitPrice = (product['trade_price'] as num).toDouble();
    final minQty = product['min_order_qty'] ?? 1;
    final taxPercent = (product['tax_percent'] as num?)?.toDouble() ?? 0;

    setState(() {
      _cartItems.add({
        'product_id': product['id'],
        'product_name': product['name'],
        'product_sku': product['sku'],
        'unit': product['unit'] ?? 'pcs',
        'quantity': minQty as int,
        'unit_price': unitPrice,
        'tax_percent': taxPercent,
        'discount_percent': 0.0,
        'line_total': unitPrice * (minQty as int),
        'mrp': (product['mrp'] as num).toDouble(),
      });
      _applySchemes();
    });
  }

  void _updateQuantity(int index, int newQty) {
    if (newQty < 1) return;
    setState(() {
      _cartItems[index]['quantity'] = newQty;
      _recalcLine(index);
    });
    _applySchemes();
  }

  void _updateDiscount(int index, double discount) {
    if (discount < 0 || discount > 100) return;
    setState(() {
      _cartItems[index]['discount_percent'] = discount;
      _recalcLine(index);
    });
    _applySchemes();
  }

  void _recalcLine(int index) {
    final item = _cartItems[index];
    final qty = item['quantity'] as int;
    final price = item['unit_price'] as double;
    final disc = item['discount_percent'] as double;
    final lineBeforeDisc = price * qty;
    item['line_total'] = lineBeforeDisc - (lineBeforeDisc * disc / 100);
  }

  void _removeItem(int index) {
    setState(() => _cartItems.removeAt(index));
    _applySchemes();
  }

  Future<void> _applySchemes() async {
    if (_cartItems.isEmpty) {
      setState(() {
        _appliedSchemes = [];
        _schemeDiscount = 0;
      });
      return;
    }
    final schemes = await SchemeService.applySchemes(
      cartItems: _cartItems,
      subtotal: _subtotal,
    );
    if (mounted) {
      setState(() {
        _appliedSchemes = schemes;
        _schemeDiscount = schemes.fold(0, (s, e) => s + e.discountAmount);
      });
    }
  }

  // ── OFFLINE ORDER SUBMISSION ─────────────────────────────────────────────
  Future<void> _submitOrderOffline() async {
    final orderId = const Uuid().v4();
    final orderNumber =
        'ORD-OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final orderData = {
      'id': orderId,
      'user_id': SupabaseService.userId,
      'party_id': widget.party['id'],
      'visit_id': widget.visitId,
      'party_name': widget.party['name'],
      'party_address': widget.party['address'],
      'subtotal': _subtotal,
      'tax_amount': _taxAmount,
      'discount_amount': _cartItems.fold<double>(
        0,
        (sum, item) =>
            sum +
            ((item['unit_price'] as double) *
                (item['quantity'] as int) *
                (item['discount_percent'] as double) /
                100),
      ),
      'total_amount': _totalAmount,
      'payment_mode': _paymentMode,
      'payment_status': 'unpaid',
      'amount_paid': 0,
      'status': 'placed',
      'notes': _notesCtrl.text.trim(),
      'order_number': orderNumber,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await OfflineQueueService.queueInsert('orders', orderData, priority: 5);

    for (final item in _cartItems) {
      await OfflineQueueService.queueInsert('order_items', {
        'id': const Uuid().v4(),
        'order_id': orderId,
        'product_id': item['product_id'],
        'product_name': item['product_name'],
        'product_sku': item['product_sku'],
        'unit': item['unit'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'discount_percent': item['discount_percent'],
        'tax_percent': item['tax_percent'],
        'line_total': item['line_total'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      _showSnack('Order saved offline — will sync when connected');
      await Future.delayed(const Duration(milliseconds: 800));
      Navigator.pop(context, {
        'order_id': orderId,
        'order_number': orderNumber,
        'total': _totalAmount,
        'offline': true,
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) {
      _showSnack('Add at least one product', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // ── Offline path ─────────────────────────────────────────────────────
    if (_isOffline) {
      try {
        await _submitOrderOffline();
      } catch (e) {
        _showSnack('Offline save failed: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    // ── Online path ──────────────────────────────────────────────────────
    try {
      final creditCheck = await CollectionService.checkCreditLimit(
        partyId: widget.party['id'] as String,
        newOrderAmount: _totalAmount,
      );

      if (creditCheck['exceeded'] == true && mounted) {
        final override = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Credit Limit Exceeded'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Credit Limit: ₹${creditCheck['limit']}'),
                Text(
                    'Outstanding: ₹${creditCheck['outstanding'].toStringAsFixed(0)}'),
                Text('This Order: ₹${_totalAmount.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                Text(
                  'Total ₹${creditCheck['total'].toStringAsFixed(0)} exceeds by ₹${(creditCheck['total'] - creditCheck['limit']).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Override & Place'),
              ),
            ],
          ),
        );
        if (override != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final orderData = {
        'user_id': SupabaseService.userId,
        'party_id': widget.party['id'],
        'visit_id': widget.visitId,
        'party_name': widget.party['name'],
        'party_address': widget.party['address'],
        'subtotal': _subtotal,
        'tax_amount': _taxAmount,
        'discount_amount': _cartItems.fold<double>(
          0,
          (sum, item) =>
              sum +
              ((item['unit_price'] as double) *
                  (item['quantity'] as int) *
                  (item['discount_percent'] as double) /
                  100),
        ),
        'total_amount': _totalAmount,
        'payment_mode': _paymentMode,
        'payment_status': 'unpaid',
        'amount_paid': 0,
        'status': 'placed',
        'notes': _notesCtrl.text.trim(),
        'order_number': '',
      };

      final orderResult = await SupabaseService.client
          .from('orders')
          .insert(orderData)
          .select('id, order_number')
          .single();

      final orderId = orderResult['id'] as String;
      final orderNumber = orderResult['order_number'] as String;

      await SupabaseService.client.from('order_items').insert(
            _cartItems
                .map((item) => {
                      'order_id': orderId,
                      'product_id': item['product_id'],
                      'product_name': item['product_name'],
                      'product_sku': item['product_sku'],
                      'unit': item['unit'],
                      'quantity': item['quantity'],
                      'unit_price': item['unit_price'],
                      'discount_percent': item['discount_percent'],
                      'tax_percent': item['tax_percent'],
                      'line_total': item['line_total'],
                    })
                .toList(),
          );

      await CollectionService.createInvoiceForOrder(
        orderId: orderId,
        partyId: widget.party['id'] as String,
        partyName: widget.party['name'] ?? '',
        userId: SupabaseService.userId!,
        amount: _totalAmount,
        dueDays: 30,
      );

      if (widget.party['phone'] != null) {
        await WhatsAppService.sendOrderConfirmation(
          phone: widget.party['phone'].toString(),
          partyName: widget.party['name'] ?? 'Customer',
          total: _totalAmount,
          orderId: orderId,
        );
      }

      if (widget.visitId != null && !widget.visitId!.startsWith('offline_')) {
        await SupabaseService.client.from('visits').update({
          'order_value': _totalAmount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.visitId!);
      }

      if (mounted) {
        _showSnack('Order $orderNumber placed successfully!');

        // Award XP + loyalty
        try {
          await SupabaseService.client.rpc('award_xp', params: {
            'p_user_id': SupabaseService.userId,
            'p_action': 'order_placed',
            'p_description': 'Order at ${widget.party['name']}',
            'p_reference_id': orderId,
          });
          await SupabaseService.client.rpc('award_loyalty_points', params: {
            'p_party_id': widget.party['id'],
            'p_order_amount': _totalAmount,
            'p_reference_id': orderId,
          });
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pop(context, {
          'order_id': orderId,
          'order_number': orderNumber,
          'total': _totalAmount,
        });
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        actions: [
          if (_isOffline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                SizedBox(width: 4),
                Text('Offline',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              ]),
            ),
          if (_cartItems.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_totalItems items',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.store_rounded, color: AppColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.party['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  if (widget.party['address'] != null)
                    Text(
                      widget.party['address'],
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.white.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ]),
        ).animate().fadeIn(duration: 300.ms),
        Expanded(
          child: _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      const Text('Cart is empty',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      const Text('Tap + to add products',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _cartItems.length,
                  itemBuilder: (_, i) => _buildCartItem(i),
                ),
        ),
        if (_cartItems.isNotEmpty) _buildBottomBar(),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cartItems[index];
    final qty = item['quantity'] as int;
    final unitPrice = item['unit_price'] as double;
    final lineTotal = item['line_total'] as double;
    final discPct = item['discount_percent'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['product_name'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                '${item['product_sku']}  •  ₹${unitPrice.toStringAsFixed(2)} / ${item['unit']}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: () => _removeItem(index),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _qtyButton(Icons.remove, () => _updateQuantity(index, qty - 1)),
              Container(
                width: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('$qty',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              _qtyButton(Icons.add, () => _updateQuantity(index, qty + 1)),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            height: 36,
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Disc%',
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              controller: TextEditingController(
                  text: discPct > 0 ? discPct.toStringAsFixed(1) : ''),
              onChanged: (v) => _updateDiscount(index, double.tryParse(v) ?? 0),
            ),
          ),
          const Spacer(),
          Text('₹${lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
      ]),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 200.ms)
        .slideX(begin: 0.03);
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('Payment:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      ['credit', 'cash', 'upi', 'cheque', 'online'].map((mode) {
                    final isSelected = _paymentMode == mode;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          mode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.primary,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _paymentMode = mode),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primarySurface,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Order notes (optional)',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
              _summaryRow('Tax', '₹${_taxAmount.toStringAsFixed(2)}'),
              if (_appliedSchemes.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.local_offer, size: 13, color: Colors.green),
                    SizedBox(width: 6),
                    Text('Applied Schemes',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.green)),
                  ]),
                ),
                ..._appliedSchemes.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(s.description,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ),
                        Text('- ₹${s.discountAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ]),
                    )),
              ],
              const Divider(),
              _summaryRow('Total', '₹${_totalAmount.toStringAsFixed(2)}',
                  isBold: true),
            ]),
          ),
          const SizedBox(height: 12),
          if (_isOffline)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline — order will sync when connected',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ]),
            ),
          CustomButton(
            text: _isOffline
                ? 'Save Order Offline  •  ₹${_totalAmount.toStringAsFixed(0)}'
                : 'Place Order  •  ₹${_totalAmount.toStringAsFixed(0)}',
            onPressed: _submitOrder,
            isLoading: _isSubmitting,
            icon: _isOffline ? Icons.save_rounded : Icons.check_circle_rounded,
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              )),
          Text(value,
              style: TextStyle(
                fontSize: isBold ? 16 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold ? AppColors.primary : AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}
