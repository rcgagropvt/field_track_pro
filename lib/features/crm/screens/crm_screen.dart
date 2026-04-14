import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../router/app_router.dart';

class CRMScreen extends StatefulWidget {
  const CRMScreen({super.key});

  @override
  State<CRMScreen> createState() => _CRMScreenState();
}

class _CRMScreenState extends State<CRMScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _leads = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  final _filters = [
    'all',
    'new',
    'contacted',
    'qualified',
    'proposal',
    'negotiation',
    'won',
    'lost'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _isLoading = true);
    try {
      final leads = await SupabaseService.getLeads(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      if (mounted) {
        setState(() {
          _leads = leads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return AppColors.leadNew;
      case 'contacted':
        return AppColors.leadContacted;
      case 'qualified':
        return AppColors.leadQualified;
      case 'proposal':
        return AppColors.leadProposal;
      case 'negotiation':
        return AppColors.leadNegotiation;
      case 'won':
        return AppColors.leadWon;
      case 'lost':
        return AppColors.leadLost;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRouter.addLead);
          _loadLeads();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Pipeline filter chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.white
                            : _getStatusColor(filter),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                      _loadLeads();
                    },
                    backgroundColor: _getStatusColor(filter).withOpacity(0.1),
                    selectedColor: _getStatusColor(filter),
                    checkmarkColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Leads List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _leads.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No Leads Yet',
                        subtitle: 'Tap + to add your first lead',
                        buttonText: 'Add Lead',
                        onButtonPressed: () async {
                          await Navigator.pushNamed(context, AppRouter.addLead);
                          _loadLeads();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLeads,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _leads.length,
                          itemBuilder: (context, index) {
                            final lead = _leads[index];
                            return _LeadCard(
                              lead: lead,
                              onTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  AppRouter.leadDetail,
                                  arguments: lead,
                                );
                                _loadLeads();
                              },
                            )
                                .animate(
                                    delay: Duration(milliseconds: index * 50))
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.05);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                  radius: 20,
                  backgroundColor: AppColors.primarySurface,
                  child: Text(
                    (lead['company_name'] ?? 'C')[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead['company_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        lead['contact_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: lead['status'] ?? 'new'),
              ],
            ),
            if (lead['estimated_value'] != null &&
                lead['estimated_value'] > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '₹${(lead['estimated_value'] as num).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
