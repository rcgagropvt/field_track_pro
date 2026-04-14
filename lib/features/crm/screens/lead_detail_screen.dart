import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/status_badge.dart';

class LeadDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late Map<String, dynamic> _lead;
  final _statuses = ['new', 'contacted', 'qualified', 'proposal', 'negotiation', 'won', 'lost'];

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
  }

  Future<void> _updateStatus(String status) async {
    try {
      await SupabaseService.updateLead(_lead['id'], {'status': status});
      setState(() => _lead['status'] = status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${status.toUpperCase()}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Details'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _updateStatus,
            itemBuilder: (context) => _statuses
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: _getColor(s)),
                          const SizedBox(width: 8),
                          Text(s.toUpperCase()),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.white.withOpacity(0.2),
                        child: Text(
                          (_lead['company_name'] ?? 'C')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lead['company_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              _lead['contact_name'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_lead['estimated_value'] != null)
                    Text(
                      '\$${(_lead['estimated_value'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                StatusBadge(status: _lead['status'] ?? 'new'),
              ],
            ),

            const SizedBox(height: 24),

            // Pipeline Progress
            const Text(
              'Pipeline',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildPipeline(),

            const SizedBox(height: 24),

            // Contact Info
            _buildSection('Contact Information', [
              _buildInfoRow(Icons.email_outlined, 'Email', _lead['email'] ?? 'N/A'),
              _buildInfoRow(Icons.phone_outlined, 'Phone', _lead['phone'] ?? 'N/A'),
              _buildInfoRow(Icons.location_on_outlined, 'Address', _lead['address'] ?? 'N/A'),
            ]),

            const SizedBox(height: 16),

            _buildSection('Details', [
              _buildInfoRow(Icons.source_rounded, 'Source',
                  (_lead['source'] ?? 'N/A').toString().replaceAll('_', ' ').toUpperCase()),
              _buildInfoRow(Icons.flag_rounded, 'Priority',
                  (_lead['priority'] ?? 'medium').toString().toUpperCase()),
              _buildInfoRow(Icons.calendar_today_rounded, 'Created',
                  _lead['created_at'] != null
                      ? DateFormat('dd MMM yyyy').format(DateTime.parse(_lead['created_at']))
                      : 'N/A'),
            ]),

            if (_lead['notes'] != null && (_lead['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection('Notes', [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _lead['notes'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPipeline() {
    final currentIndex = _statuses.indexOf(_lead['status'] ?? 'new');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statuses.asMap().entries.map((entry) {
          final index = entry.key;
          final status = entry.value;
          final isActive = index <= currentIndex;
          final color = _getColor(status);

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? color : AppColors.divider,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.white : AppColors.textTertiary,
                  ),
                ),
              ),
              if (index < _statuses.length - 1)
                Container(
                  width: 16,
                  height: 2,
                  color: isActive ? color : AppColors.divider,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(String status) {
    switch (status) {
      case 'new': return AppColors.leadNew;
      case 'contacted': return AppColors.leadContacted;
      case 'qualified': return AppColors.leadQualified;
      case 'proposal': return AppColors.leadProposal;
      case 'negotiation': return AppColors.leadNegotiation;
      case 'won': return AppColors.leadWon;
      case 'lost': return AppColors.leadLost;
      default: return AppColors.textTertiary;
    }
  }
}
