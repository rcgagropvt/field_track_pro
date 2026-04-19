import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../admin/screens/admin_payroll_screen.dart';

class EmployeePayslipScreen extends StatefulWidget {
  const EmployeePayslipScreen({super.key});

  @override
  State<EmployeePayslipScreen> createState() => _EmployeePayslipScreenState();
}

class _EmployeePayslipScreenState extends State<EmployeePayslipScreen> {
  List<Map<String, dynamic>> _payslips = [];
  Map<String, dynamic>? _salary;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.userId!;
      final results = await Future.wait([
        SupabaseService.client
            .from('payslips')
            .select()
            .eq('user_id', userId)
            .order('year', ascending: false)
            .order('month', ascending: false)
            .limit(24),
        SupabaseService.client
            .from('employee_salary')
            .select()
            .eq('user_id', userId)
            .isFilter('effective_to', null)
            .limit(1),
        SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .single(),
      ]);

      _payslips = List<Map<String, dynamic>>.from(results[0] as List);
      final salaries = List<Map<String, dynamic>>.from(results[1] as List);
      _salary = salaries.isNotEmpty ? salaries.first : null;
      _profile = results[2] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Payslip load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Payslips')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payslips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No payslips yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                      if (_salary == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Salary not yet configured by admin',
                              style:
                                  TextStyle(color: Colors.orange, fontSize: 13)),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Current salary summary
                      if (_salary != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8)
                            ]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Annual CTC',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                ],
                              ),
                              Text(
                                '₹${NumberFormat('#,##,###').format((_salary!['annual_ctc'] as num).toInt())}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Payslip list
                      ..._payslips.map((ps) {
                        final monthDate =
                            DateTime(ps['year'], ps['month']);
                        final isPaid = ps['payment_status'] == 'paid';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            tileColor: Colors.white,
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM').format(monthDate),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isPaid
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                            title: Text(
                                DateFormat('MMMM yyyy').format(monthDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              isPaid ? 'Paid' : 'Processing',
                              style: TextStyle(
                                  color: isPaid ? Colors.green : Colors.orange,
                                  fontSize: 12),
                            ),
                            trailing: Text(
                              '₹${NumberFormat('#,##,###').format((ps['net_pay'] as num).toInt())}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PayslipDetailScreen(
                                    payslip: ps,
                                    profile: _profile ?? {},
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
