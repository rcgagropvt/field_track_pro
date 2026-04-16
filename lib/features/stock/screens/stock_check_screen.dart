import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/offline_queue_service.dart';

class StockCheckScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  final String? visitId;

  const StockCheckScreen({super.key, required this.party, this.visitId});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _stockEntries = [];
  bool _loading = true;
  bool _saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load all active products
      final products = await SupabaseService.client
          .from('products')
          .select('id, name, sku, unit, product_categories(name)')
          .eq('is_active', true)
          .order('name');

      // Load existing stock entries for this party
      final existing = await SupabaseService.client
          .from('distributor_stock')
          .select()
          .eq('party_id', widget.party['id'] as String);

      final existingMap = {
        for (final e in existing as List) e['product_id'] as String: e
      };

      // Build merged list
      final entries = (products as List).map((p) {
        final ex = existingMap[p['id'] as String];
        return {
          'product_id': p['id'],
          'product_name': p['name'],
          'product_sku': p['sku'],
          'unit': p['unit'] ?? 'pcs',
          'category': (p['product_categories'] as Map?)?['name'] ?? '',
          'quantity': ex?['quantity'] ?? 0,
          'stock_status': ex?['stock_status'] ?? 'adequate',
          'low_stock_threshold': ex?['low_stock_threshold'] ?? 10,
          'shelf_photo': ex?['shelf_photo'],
          'notes': ex?['notes'] ?? '',
          'existing_id': ex?['id'],
          'qty_ctrl': TextEditingController(
              text: (ex?['quantity'] ?? 0).toString()),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(products);
          _stockEntries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('StockCheck load error: \$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _captureShelfPhoto(int index) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo == null) return;

    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        _showSnack('No connection — photo not uploaded', isError: true);
        return;
      }
      final bytes = await photo.readAsBytes();
      final fileName =
          'stock/\${SupabaseService.userId}/\${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes);
      final url = SupabaseService.client.storage
          .from('uploads')
          .getPublicUrl(fileName);
      setState(() => _stockEntries[index]['shelf_photo'] = url);
      _showSnack('Shelf photo captured');
    } catch (e) {
      _showSnack('Photo upload failed', isError: true);
    }
  }

  String _statusFromQty(int qty, int threshold) {
    if (qty == 0) return 'out_of_stock';
    if (qty <= threshold) return 'low';
    return 'adequate';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'out_of_stock': return Colors.red;
      case 'low':          return Colors.orange;
      default:              return Colors.green;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'out_of_stock': return Icons.remove_shopping_cart_rounded;
      case 'low':          return Icons.warning_amber_rounded;
      default:              return Icons.check_circle_rounded;
    }
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final result = await Connectivity().checkConnectivity();
      final isOnline = result != ConnectivityResult.none;
      int saved = 0;

      for (final entry in _stockEntries) {
        final qty = int.tryParse(
                (entry['qty_ctrl'] as TextEditingController).text) ?? 0;
        final threshold = entry['low_stock_threshold'] as int;
        final status = _statusFromQty(qty, threshold);

        final data = {
          'party_id': widget.party['id'],
          'product_id': entry['product_id'],
          'user_id': SupabaseService.userId,
          'quantity': qty,
          'stock_status': status,
          'low_stock_threshold': threshold,
          'shelf_photo': entry['shelf_photo'],
          'notes': entry['notes'] ?? '',
          'last_checked': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (isOnline) {
          if (entry['existing_id'] != null) {
            await SupabaseService.client
                .from('distributor_stock')
                .update(data)
                .eq('id', entry['existing_id'] as String);
          } else {
            await SupabaseService.client
                .from('distributor_stock')
                .insert(data);
          }
        } else {
          if (entry['existing_id'] != null) {
            await OfflineQueueService.queueUpdate(
                'distributor_stock', entry['existing_id'] as String, data);
          } else {
            await OfflineQueueService.queueInsert('distributor_stock', data);
          }
        }
        saved++;
      }

      _showSnack(isOnline
          ? '\$saved stock entries saved successfully'
          : 'Saved offline — will sync when connected');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Error saving: \$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
    for (final e in _stockEntries) {
      (e['qty_ctrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outOfStock = _stockEntries
        .where((e) {
          final qty = int.tryParse(
                  (e['qty_ctrl'] as TextEditingController).text) ?? 0;
          return qty == 0;
        })
        .length;
    final lowStock = _stockEntries
        .where((e) {
          final qty = int.tryParse(
                  (e['qty_ctrl'] as TextEditingController).text) ?? 0;
          final threshold = e['low_stock_threshold'] as int;
          return qty > 0 && qty <= threshold;
        })
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Stock Check',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(widget.party['name'] ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              // Summary bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  _summaryChip('${_stockEntries.length}', 'Total', AppColors.primary),
                  const SizedBox(width: 8),
                  _summaryChip('$outOfStock', 'Out of Stock', Colors.red),
                  const SizedBox(width: 8),
                  _summaryChip('$lowStock', 'Low Stock', Colors.orange),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _stockEntries.length,
                  itemBuilder: (_, i) => _buildStockCard(i),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveAll,
                      icon: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving...' : 'Save All Stock Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _summaryChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(count,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildStockCard(int i) {
    final entry = _stockEntries[i];
    final ctrl = entry['qty_ctrl'] as TextEditingController;
    final qty = int.tryParse(ctrl.text) ?? 0;
    final threshold = entry['low_stock_threshold'] as int;
    final status = _statusFromQty(qty, threshold);
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry['product_name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${entry['product_sku']} • ${entry['category']}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_statusIcon(status), size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusColor),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Qty on shelf:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _qtyBtn(Icons.remove, () {
                final v = (int.tryParse(ctrl.text) ?? 0) - 1;
                if (v >= 0) {
                  ctrl.text = v.toString();
                  setState(() {});
                }
              }),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 6),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _qtyBtn(Icons.add, () {
                final v = (int.tryParse(ctrl.text) ?? 0) + 1;
                ctrl.text = v.toString();
                setState(() {});
              }),
            ]),
          ),
          const SizedBox(width: 8),
          Text(entry['unit'] ?? 'pcs',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          // Shelf photo button
          GestureDetector(
            onTap: () => _captureShelfPhoto(i),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: entry['shelf_photo'] != null
                    ? AppColors.successLight
                    : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry['shelf_photo'] != null
                    ? Icons.check_circle_rounded
                    : Icons.add_a_photo_rounded,
                size: 18,
                color: entry['shelf_photo'] != null
                    ? AppColors.success
                    : AppColors.primary,
              ),
            ),
          ),
        ]),
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
}
