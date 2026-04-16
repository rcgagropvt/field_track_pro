import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import 'create_beat_screen.dart';

class BeatListScreen extends StatefulWidget {
  const BeatListScreen({super.key});
  @override
  State<BeatListScreen> createState() => _BeatListScreenState();
}

class _BeatListScreenState extends State<BeatListScreen> {
  List<Map<String, dynamic>> _beats = [];
  bool _loading = true;

  final _days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final beats = await SupabaseService.client
          .from('beats')
          .select('*, profiles!assigned_user(full_name)')
          .order('created_at', ascending: false);

      // Get stop counts per beat
      final beatList = List<Map<String, dynamic>>.from(beats as List);

      for (final beat in beatList) {
        final stops = await SupabaseService.client
            .from('beat_stops')
            .select('id')
            .eq('beat_id', beat['id'] as String);
        beat['stop_count'] = (stops as List).length;
      }

      if (mounted) setState(() { _beats = beatList; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> beat) async {
    await SupabaseService.client
        .from('beats')
        .update({'is_active': !(beat['is_active'] as bool)})
        .eq('id', beat['id'] as String);
    _load();
  }

  Future<void> _delete(String beatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Beat?'),
        content: const Text('This will also delete all stops. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.client.from('beats').delete().eq('id', beatId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Beat Plans', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'beat_list_fab',
        onPressed: () async {
          final result = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateBeatScreen()));
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Beat'),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _beats.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.route, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No beats created yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text('Tap + to create the first beat plan',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _beats.length,
                    itemBuilder: (_, i) => _beatCard(_beats[i]),
                  ),
                ),
    );
  }

  Widget _beatCard(Map<String, dynamic> beat) {
    final isActive = beat['is_active'] as bool? ?? true;
    final day = beat['day_of_week'] as int?;
    final dayLabel = day != null ? _days[day] : 'Every Day';
    final emp = beat['profiles'] as Map<String, dynamic>?;
    final stopCount = beat['stop_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        border: isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(beat['name'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isActive ? Colors.black87 : Colors.grey)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                            fontSize: 11,
                            color: isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  _chip(Icons.person_outline, emp?['full_name'] ?? 'Unassigned', Colors.blue),
                  _chip(Icons.calendar_today, dayLabel, Colors.orange),
                  _chip(Icons.place_outlined, '$stopCount stops', AppColors.primary),
                ]),
              ]),
            ),
          ]),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 16),
              label: Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12)),
              onPressed: () => _toggleActive(beat),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final result = await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CreateBeatScreen(beat: beat)));
                if (result == true) _load();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
              onPressed: () => _delete(beat['id'] as String),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      );
}


