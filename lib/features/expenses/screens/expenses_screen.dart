import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../router/app_router.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final data = await SupabaseService.getExpenses();
      if (mounted) {
        setState(() {
          _expenses = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'travel':
        return Icons.directions_car_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'accommodation':
        return Icons.hotel_rounded;
      case 'supplies':
        return Icons.shopping_bag_rounded;
      case 'communication':
        return Icons.phone_rounded;
      case 'entertainment':
        return Icons.celebration_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _expenses
        .where((e) => e['status'] == 'pending')
        .fold<double>(0, (sum, e) => sum + (e['amount'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRouter.addExpense);
          _loadExpenses();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Claims',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${totalPending.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.05),

                // Expenses List
                Expanded(
                  child: _expenses.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'No Expenses',
                          subtitle: 'Tap + to add your first expense',
                          buttonText: 'Add Expense',
                          onButtonPressed: () async {
                            await Navigator.pushNamed(
                                context, AppRouter.addExpense);
                            _loadExpenses();
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: _loadExpenses,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final expense = _expenses[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _categoryIcon(
                                            expense['category'] ?? 'other'),
                                        color: AppColors.primary,
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
                                            (expense['category'] ?? 'other')
                                                .toString()
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (expense['description'] != null)
                                            Text(
                                              expense['description'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            expense['expense_date'] != null
                                                ? DateFormat('dd MMM yyyy')
                                                    .format(DateTime.parse(
                                                        expense[
                                                            'expense_date']))
                                                : '',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${(expense['amount'] as num).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        StatusBadge(
                                            status:
                                                expense['status'] ?? 'pending'),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                                  .animate(
                                      delay: Duration(milliseconds: index * 60))
                                  .fadeIn(duration: 300.ms)
                                  .slideX(begin: 0.05);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}


