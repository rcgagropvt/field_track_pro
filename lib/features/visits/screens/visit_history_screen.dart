import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = SupabaseService.userId;
      if (uid == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      final data = await SupabaseService.client
          .from('visits')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _visits = List<Map<String, dynamic>>.from(data ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // FIX: filter by check_in_time, not missing 'date' field
    final todayVisits = _visits.where((v) {
      if (v['check_in_time'] == null) return false;
      return (v['check_in_time'] as String).startsWith(today);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Visits')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildErrorState() // ← replaced raw error text
              : _visits.isEmpty
                  ? const EmptyState(
                      icon: Icons.assignment_rounded,
                      title: 'No Visits Yet',
                      subtitle: 'Go to Parties → tap a dealer → Start Visit',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: AppColors.cardGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _stat('Total', '${_visits.length}',
                                    Icons.list_alt),
                                _stat('Today', '${todayVisits.length}',
                                    Icons.today),
                                _stat(
                                  'Orders',
                                  '₹${_visits.fold<double>(0, (s, v) => s + ((v['order_value'] as num?) ?? 0).toDouble()).toStringAsFixed(0)}',
                                  Icons.shopping_cart,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._visits.asMap().entries.map((entry) {
                            return _visitCard(entry.value, entry.key);
                          }),
                        ],
                      ),
                    ),
    );
  }

// ADD this new method:
  Widget _buildErrorState() {
    final isNetworkError = _error!.toLowerCase().contains('socket') ||
        _error!.toLowerCase().contains('failed host') ||
        _error!.toLowerCase().contains('network');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkError
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError
                  ? 'No Internet Connection'
                  : 'Something went wrong',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNetworkError ? 'Check your connection and try again' : _error!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load, // ← retry button
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.white, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppColors.white.withOpacity(0.8))),
      ],
    );
  }

  Widget _visitCard(Map<String, dynamic> visit, int index) {
    final checkIn = visit['check_in_time'] != null
        ? DateFormat('hh:mm a').format(DateTime.parse(visit['check_in_time']))
        : '--';
    final date = visit['date'] != null
        ? DateFormat('dd MMM').format(DateTime.parse(visit['date']))
        : '';
    final duration = visit['duration_minutes'] ?? 0;
    final orderVal = (visit['order_value'] as num?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  (visit['party_name'] ?? 'V')[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit['party_name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('$date • $checkIn • ${duration}min',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusBadge(status: visit['status'] ?? 'planned'),
            ],
          ),

          // Purpose + outcome
          if (visit['purpose'] != null || visit['outcome'] != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                if (visit['purpose'] != null)
                  _chip(visit['purpose'].toString().replaceAll('_', ' '),
                      AppColors.info),
                if (visit['outcome'] != null)
                  _chip(visit['outcome'].toString().replaceAll('_', ' '),
                      AppColors.warning),
              ],
            ),
          ],

          // Order value
          if (orderVal > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _chip('Order: ₹${orderVal.toStringAsFixed(0)}',
                    AppColors.success),
                if (visit['payment_collected'] != null &&
                    (visit['payment_collected'] as num) > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _chip(
                        'Paid: ₹${(visit['payment_collected'] as num).toStringAsFixed(0)}',
                        AppColors.primary),
                  ),
              ],
            ),
          ],

          // Notes preview
          if (visit['discussion_notes'] != null &&
              (visit['discussion_notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              visit['discussion_notes'],
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Photos indicator
          if (visit['photos'] != null &&
              (visit['photos'] as List).isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.photo_library_rounded,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${(visit['photos'] as List).length} photos',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ],
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 200.ms)
        .slideX(begin: 0.02);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}


