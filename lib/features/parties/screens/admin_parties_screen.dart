import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'party_profile_screen.dart';
import 'add_party_screen.dart';

class AdminPartiesScreen extends StatefulWidget {
  const AdminPartiesScreen({super.key});
  @override
  State<AdminPartiesScreen> createState() => _AdminPartiesScreenState();
}

class _AdminPartiesScreenState extends State<AdminPartiesScreen> {
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _typeFilter = 'all';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await SupabaseService.client
        .from('parties')
        .select()
        .order('name');
    if (mounted) {
      setState(() {
        _parties = List<Map<String, dynamic>>.from(data as List);
        _applyFilters();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    _filtered = _parties.where((p) {
      final matchType = _typeFilter == 'all' || p['type'] == _typeFilter;
      final matchSearch = _search.text.isEmpty ||
          (p['name'] ?? '').toLowerCase().contains(_search.text.toLowerCase()) ||
          (p['contact_person'] ?? '').toLowerCase().contains(_search.text.toLowerCase());
      return matchType && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All Parties', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${_filtered.length} parties',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddPartyScreen()));
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() => _applyFilters()),
              decoration: InputDecoration(
                hintText: 'Search parties...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Filters
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['all', 'dealer', 'distributor', 'retailer', 'wholesaler', 'customer']
                  .map((t) {
                final sel = _typeFilter == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.primary)),
                    selected: sel,
                    onSelected: (_) => setState(() {
                      _typeFilter = t;
                      _applyFilters();
                    }),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary,
                    side: BorderSide(color: sel ? AppColors.primary : Colors.grey.shade300),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final creditLimit = (p['credit_limit'] as num?)?.toDouble() ?? 0;
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PartyProfileScreen(
                                  party: p,
                                  isAdmin: true,
                                ),
                              ),
                            );
                            _load();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primarySurface,
                                child: Text(
                                  (p['name'] ?? 'P')[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    Text(
                                      '${p['type'] ?? ''} • ${p['city'] ?? p['address'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (p['contact_person'] != null)
                                      Text(p['contact_person'],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (creditLimit > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Limit ₹${creditLimit.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.grey, size: 18),
                                ],
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

