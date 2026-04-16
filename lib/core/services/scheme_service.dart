import 'supabase_service.dart';

class AppliedScheme {
  final String schemeId;
  final String schemeName;
  final String type;
  final double discountAmount;
  final String description;

  AppliedScheme({
    required this.schemeId,
    required this.schemeName,
    required this.type,
    required this.discountAmount,
    required this.description,
  });
}

class SchemeService {
  /// Fetch all currently active schemes
  static Future<List<Map<String, dynamic>>> fetchActiveSchemes() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await SupabaseService.client
        .from('schemes')
        .select()
        .eq('is_active', true)
        .lte('valid_from', today)
        .gte('valid_to', today)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// Auto-apply all eligible schemes to the cart and return applied schemes
  static Future<List<AppliedScheme>> applySchemes({
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
  }) async {
    final schemes = await fetchActiveSchemes();
    final applied = <AppliedScheme>[];

    for (final scheme in schemes) {
      final type = scheme['type'] as String;
      final applicableProducts = List<String>.from(
          (scheme['applicable_products'] as List?) ?? []);

      switch (type) {
        case 'percentage':
          // Apply % discount to eligible cart items
          for (final item in cartItems) {
            final productId = item['product_id'] as String;
            if (applicableProducts.isEmpty ||
                applicableProducts.contains(productId)) {
              final disc = (scheme['discount_value'] as num).toDouble();
              final lineTotal = (item['line_total'] as double);
              final discAmount = lineTotal * disc / 100;
              if (discAmount > 0) {
                applied.add(AppliedScheme(
                  schemeId: scheme['id'],
                  schemeName: scheme['name'],
                  type: type,
                  discountAmount: discAmount,
                  description:
                      '${disc.toStringAsFixed(0)}% off on ${item['product_name']}',
                ));
              }
            }
          }
          break;

        case 'flat':
          // Flat discount on entire order (no product filter)
          final disc = (scheme['discount_value'] as num).toDouble();
          if (disc > 0) {
            applied.add(AppliedScheme(
              schemeId: scheme['id'],
              schemeName: scheme['name'],
              type: type,
              discountAmount: disc,
              description: '₹${disc.toStringAsFixed(0)} flat discount',
            ));
          }
          break;

        case 'min_order':
          // Flat discount only if order exceeds minimum amount
          final minAmt = (scheme['min_order_amount'] as num).toDouble();
          final disc = (scheme['discount_value'] as num).toDouble();
          if (subtotal >= minAmt && disc > 0) {
            applied.add(AppliedScheme(
              schemeId: scheme['id'],
              schemeName: scheme['name'],
              type: type,
              discountAmount: disc,
              description:
                  '₹${disc.toStringAsFixed(0)} off on orders above ₹${minAmt.toStringAsFixed(0)}',
            ));
          }
          break;

        case 'buy_x_get_y':
          // Check if any applicable product has enough qty
          for (final item in cartItems) {
            final productId = item['product_id'] as String;
            if (applicableProducts.isEmpty ||
                applicableProducts.contains(productId)) {
              final buyQty = (scheme['buy_qty'] as num?)?.toInt() ?? 0;
              final freeQty = (scheme['free_qty'] as num?)?.toInt() ?? 0;
              final itemQty = item['quantity'] as int;
              if (buyQty > 0 && itemQty >= buyQty) {
                final unitPrice = (item['unit_price'] as double);
                final discAmount = unitPrice * freeQty.toDouble();
                applied.add(AppliedScheme(
                  schemeId: scheme['id'],
                  schemeName: scheme['name'],
                  type: type,
                  discountAmount: discAmount,
                  description:
                      'Buy $buyQty Get $freeQty Free on ${item['product_name']}',
                ));
              }
            }
          }
          break;
      }
    }

    // Deduplicate — only one scheme of same ID applied once
    final seen = <String>{};
    return applied.where((s) => seen.add(s.schemeId)).toList();
  }
}

