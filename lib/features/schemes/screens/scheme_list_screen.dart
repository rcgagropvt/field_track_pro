import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'create_scheme_screen.dart';

class SchemeListScreen extends StatefulWidget {
  const SchemeListScreen({super.key});
  @override
  State<SchemeListScreen> createState() => _SchemeListScreenState();
}

class _SchemeListScreenState extends State<SchemeListScreen> {
  List<Map<String, dynamic>> _schemes = [];
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
          .from('schemes')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _schemes = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> scheme) async {
    await SupabaseService.client
        .from('schemes')
        .update({'is_active': !(scheme['is_active'] as bool)})
        .eq('id', scheme['id'] as String);
    _load();
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Scheme?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.client
          .from('schemes')
          .delete()
          .eq('id', id);
      _load();
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'percentage': return Colors.blue;
      case 'flat':       return Colors.green;
      case 'buy_x_get_y': return Colors.orange;
      case 'min_order':  return Colors.purple;
      default:           return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'percentage':  return '% OFF';
      case 'flat':        return 'FLAT';
      case 'buy_x_get_y': return 'BUY X GET Y';
      case 'min_order':   return 'MIN ORDER';
      default:            return type.toUpperCase();
    }
  }

  String _schemeDetail(Map<String, dynamic> s) {
    switch (s['type']) {
      case 'percentage':
        return '${s['discount_value']}% discount';
      case 'flat':
        return '₹${s['discount_value']} off';
      case 'buy_x_get_y':
        return 'Buy ${s['buy_qty']} Get ${s['free_qty']} Free';
      case 'min_order':
        return '₹${s['discount_value']} off on orders ≥ ₹${s['min_order_amount']}';
      default:
        return '';
    }
  }

  bool _isExpired(Map<String, dynamic> s) {
    final validTo = DateTime.tryParse(s['valid_to'] ?? '');
    return validTo != null && validTo.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Schemes & Offers',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scheme_fab',
        onPressed: () async {
          final result = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateSchemeScreen()));
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Scheme'),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _schemes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No schemes created yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Tap + to create your first scheme',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _schemes.length,
                    itemBuilder: (_, i) => _schemeCard(_schemes[i]),
                  ),
                ),
    );
  }

  Widget _schemeCard(Map<String, dynamic> scheme) {
    final expired = _isExpired(scheme);
    final active = (scheme['is_active'] as bool) && !expired;
    final typeColor = _typeColor(scheme['type'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? typeColor.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_typeLabel(scheme['type'] ?? ''),
                      style: TextStyle(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(scheme['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (expired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Expired',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  Switch(
                    value: scheme['is_active'] as bool,
                    onChanged: (_) => _toggleActive(scheme),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(_schemeDetail(scheme),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${scheme['valid_from']} → ${scheme['valid_to']}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Actions
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CreateSchemeScreen(scheme: scheme)));
                    if (result == true) _load();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary),
                ),
                TextButton.icon(
                  onPressed: () => _delete(scheme['id'] as String),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

