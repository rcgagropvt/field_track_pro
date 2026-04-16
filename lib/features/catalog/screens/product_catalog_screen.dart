import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/empty_state.dart';

class ProductCatalogScreen extends StatefulWidget {
  /// If true, tapping a product adds it to the order (returns the product map)
  final bool selectionMode;

  const ProductCatalogScreen({super.key, this.selectionMode = false});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await SupabaseService.client
          .from('product_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final prods = await SupabaseService.client
          .from('products')
          .select('*, product_categories(name)')
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(cats);
          _products = List<Map<String, dynamic>>.from(prods);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filtered = _products.where((p) {
      final matchesCat = _selectedCategory == 'all' ||
          p['category_id'] == _selectedCategory;
      final query = _searchCtrl.text.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (p['name'] ?? '').toString().toLowerCase().contains(query) ||
          (p['sku'] ?? '').toString().toLowerCase().contains(query) ||
          (p['brand'] ?? '').toString().toLowerCase().contains(query);
      return matchesCat && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Select Products' : 'Product Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() => _applyFilters()),
              decoration: InputDecoration(
                hintText: 'Search products, SKU, brand...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _applyFilters());
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Category chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildCategoryChip('all', 'All'),
                ..._categories.map((cat) =>
                    _buildCategoryChip(cat['id'], cat['name'] ?? '')),
              ],
            ),
          ),

          // Product count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} products',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Product grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_rounded,
                        title: 'No Products Found',
                        subtitle: 'Try a different search or category',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.primary,
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(_filtered[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.primary,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = id;
            _applyFilters();
          });
        },
        backgroundColor: AppColors.primarySurface,
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.white,
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final catName = product['product_categories']?['name'] ?? '';

    return GestureDetector(
      onTap: () {
        if (widget.selectionMode) {
          Navigator.pop(context, product);
        } else {
          _showProductDetail(product);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: product['image_url'] != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      child: CachedNetworkImage(
                        imageUrl: product['image_url'],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                            child: Icon(Icons.inventory_2_rounded,
                                color: AppColors.primary, size: 32)),
                        errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.inventory_2_rounded,
                                color: AppColors.primary, size: 32)),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.inventory_2_rounded,
                          color: AppColors.primary, size: 32)),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category tag
                    if (catName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          catName,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),

                    // Name
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // SKU + Brand
                    Text(
                      '${product['sku'] ?? ''}  •  ${product['brand'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Prices
                    Row(
                      children: [
                        Text(
                          '₹${(product['trade_price'] ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${(product['mrp'] ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 250.ms)
        .scale(begin: const Offset(0.95, 0.95));
  }

  void _showProductDetail(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
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
              const SizedBox(height: 20),

              // Product image
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary, size: 48),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                product['name'] ?? '',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'SKU: ${product['sku'] ?? 'N/A'}  •  Brand: ${product['brand'] ?? 'N/A'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Price table
              _detailRow('MRP', '₹${(product['mrp'] ?? 0).toStringAsFixed(2)}'),
              _detailRow('Trade Price',
                  '₹${(product['trade_price'] ?? 0).toStringAsFixed(2)}'),
              _detailRow('Retail Price',
                  '₹${(product['retail_price'] ?? 0).toStringAsFixed(2)}'),
              _detailRow('Tax', '${product['tax_percent'] ?? 0}%'),
              _detailRow('Unit', product['unit'] ?? 'pcs'),
              _detailRow(
                  'Min Order Qty', '${product['min_order_qty'] ?? 1}'),
              if (product['hsn_code'] != null)
                _detailRow('HSN Code', product['hsn_code']),
              if (product['description'] != null) ...[
                const SizedBox(height: 12),
                const Text('Description',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(product['description'],
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


