import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/empty_state.dart';
import 'add_party_screen.dart';
import 'party_action_sheet.dart'; // ← NEW (replaces direct PartyProfileScreen push)

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.userId;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = await SupabaseService.client
          .from('parties')
          .select()
          .eq('user_id', uid)
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _parties = List<Map<String, dynamic>>.from(data);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filtered = _parties.where((p) {
      final matchesType = _typeFilter == 'all' || p['type'] == _typeFilter;
      final matchesSearch = _searchController.text.isEmpty ||
          (p['name'] as String)
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          (p['contact_person'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'dealer':
        return Icons.storefront_rounded;
      case 'distributor':
        return Icons.local_shipping_rounded;
      case 'retailer':
        return Icons.store_rounded;
      case 'wholesaler':
        return Icons.warehouse_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parties')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddPartyScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _applyFilters()),
              decoration: InputDecoration(
                hintText: 'Search dealers, distributors...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFilters());
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Type filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                'all',
                'dealer',
                'distributor',
                'retailer',
                'wholesaler',
                'customer',
              ].map((type) {
                final isSelected = _typeFilter == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.white : AppColors.primary,
                        )),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _typeFilter = type;
                        _applyFilters();
                      });
                    },
                    backgroundColor: AppColors.primarySurface,
                    selectedColor: AppColors.primary,
                    checkmarkColor: AppColors.white,
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
          ),

          // Party List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.store_rounded,
                        title: 'No Parties Added',
                        subtitle: 'Add dealers, distributors, or retailers',
                        buttonText: 'Add Party',
                        onButtonPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddPartyScreen()));
                          _load();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final party = _filtered[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primarySurface,
                                  child: Icon(
                                      _typeIcon(party['type'] ?? 'dealer'),
                                      color: AppColors.primary,
                                      size: 20),
                                ),
                                title: Text(party['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (party['contact_person'] != null)
                                      Text(party['contact_person'],
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary)),
                                    if (party['address'] != null)
                                      Text(party['address'],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textTertiary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (party['type'] ?? 'dealer')
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                // ── CHANGED: was Navigator.push → PartyProfileScreen
                                // Now opens the action sheet with Start Visit / View Profile / Call
                                onTap: () => showPartyActionSheet(
                                  context,
                                  party: party,
                                  isAdmin: false,
                                  onActionCompleted: _load,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            )
                                .animate(
                                    delay: Duration(milliseconds: index * 40))
                                .fadeIn(duration: 250.ms)
                                .slideX(begin: 0.03);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  // _showVisitOption removed — replaced by party_action_sheet.dart
}
