import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final cats = await SupabaseService.client
          .from('product_categories')
          .select()
          .order('sort_order');
      final prods = await SupabaseService.client
          .from('products')
          .select('*, product_categories(name)')
          .order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(cats);
          _products = List<Map<String, dynamic>>.from(prods);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddProduct() {
    final skuCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final tradeCtrl = TextEditingController();
    final retailCtrl = TextEditingController();
    final taxCtrl = TextEditingController(text: '18');
    final unitCtrl = TextEditingController(text: 'pcs');
    final minQtyCtrl = TextEditingController(text: '1');
    final descCtrl = TextEditingController();
    String? selectedCatId;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Add Product',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                CustomTextField(
                    controller: skuCtrl,
                    label: 'SKU *',
                    hint: 'e.g. BEV001'),
                const SizedBox(height: 10),
                CustomTextField(
                    controller: nameCtrl,
                    label: 'Product Name *',
                    hint: 'e.g. Cola 500ml'),
                const SizedBox(height: 10),
                CustomTextField(
                    controller: brandCtrl,
                    label: 'Brand',
                    hint: 'e.g. CoolCola'),
                const SizedBox(height: 10),

                // Category dropdown
                DropdownButtonFormField<String>(
                  value: selectedCatId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_rounded, size: 20),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setModalState(() => selectedCatId = v),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                        child: CustomTextField(
                            controller: mrpCtrl,
                            label: 'MRP *',
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: CustomTextField(
                            controller: tradeCtrl,
                            label: 'Trade Price *',
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                        child: CustomTextField(
                            controller: retailCtrl,
                            label: 'Retail Price',
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: CustomTextField(
                            controller: taxCtrl,
                            label: 'Tax %',
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                        child: CustomTextField(
                            controller: unitCtrl,
                            label: 'Unit',
                            hint: 'pcs, kg, ml')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: CustomTextField(
                            controller: minQtyCtrl,
                            label: 'Min Order Qty',
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),

                CustomTextField(
                    controller: descCtrl,
                    label: 'Description',
                    maxLines: 2),
                const SizedBox(height: 16),

                CustomButton(
                  text: 'Save Product',
                  isLoading: saving,
                  onPressed: () async {
                    if (skuCtrl.text.trim().isEmpty ||
                        nameCtrl.text.trim().isEmpty ||
                        mrpCtrl.text.trim().isEmpty ||
                        tradeCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Fill all required fields (*)'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }

                    setModalState(() => saving = true);
                    try {
                      await SupabaseService.client
                          .from('products')
                          .insert({
                        'sku': skuCtrl.text.trim(),
                        'name': nameCtrl.text.trim(),
                        'brand': brandCtrl.text.trim().isEmpty
                            ? null
                            : brandCtrl.text.trim(),
                        'category_id': selectedCatId,
                        'mrp': double.parse(mrpCtrl.text.trim()),
                        'trade_price':
                            double.parse(tradeCtrl.text.trim()),
                        'retail_price': retailCtrl.text.trim().isEmpty
                            ? double.parse(tradeCtrl.text.trim())
                            : double.parse(retailCtrl.text.trim()),
                        'tax_percent': double.tryParse(taxCtrl.text) ?? 0,
                        'unit': unitCtrl.text.trim(),
                        'min_order_qty':
                            int.tryParse(minQtyCtrl.text) ?? 1,
                        'description': descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        'is_active': true,
                      });
                      Navigator.pop(ctx);
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product added!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ));
                    } finally {
                      setModalState(() => saving = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleProduct(String id, bool currentActive) async {
    await SupabaseService.client
        .from('products')
        .update({'is_active': !currentActive}).eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProduct,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final p = _products[index];
                  final isActive = p['is_active'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.white
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.inventory_2_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textTertiary,
                                  )),
                              Text(
                                '${p['sku']}  •  ₹${(p['trade_price'] ?? 0).toStringAsFixed(0)}  •  ${p['product_categories']?['name'] ?? 'Uncategorized'}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isActive,
                          activeColor: AppColors.primary,
                          onChanged: (_) =>
                              _toggleProduct(p['id'], isActive),
                        ),
                      ],
                    ),
                  ).animate(delay: Duration(milliseconds: index * 30))
                      .fadeIn(duration: 200.ms);
                },
              ),
            ),
    );
  }
}
