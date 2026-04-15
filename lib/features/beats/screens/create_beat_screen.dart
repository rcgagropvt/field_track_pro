import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class CreateBeatScreen extends StatefulWidget {
  final Map<String, dynamic>? beat; // null = create, non-null = edit
  const CreateBeatScreen({super.key, this.beat});

  @override
  State<CreateBeatScreen> createState() => _CreateBeatScreenState();
}

class _CreateBeatScreenState extends State<CreateBeatScreen> {
  final _nameCtrl = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _selectedStops = []; // ordered list
  String? _selectedUserId;
  int? _selectedDay; // null = every day
  bool _saving = false;
  bool _loading = true;

  final _days = ['Every Day', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.beat != null) {
      _nameCtrl.text = widget.beat!['name'] ?? '';
      _selectedUserId = widget.beat!['assigned_user'];
      _selectedDay = widget.beat!['day_of_week'];
    }
  }

  Future<void> _load() async {
    try {
      final emps = await SupabaseService.client
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'employee')
          .eq('is_active', true)
          .order('full_name');

      final pts = await SupabaseService.client
          .from('parties')
          .select('id, name, city, type, address')
          .eq('is_active', true)
          .order('name');

      List<Map<String, dynamic>> existingStops = [];
      if (widget.beat != null) {
        final stops = await SupabaseService.client
            .from('beat_stops')
            .select('*, parties(id, name, city, type, address)')
            .eq('beat_id', widget.beat!['id'])
            .order('sequence');
        existingStops = List<Map<String, dynamic>>.from(stops as List);
        existingStops = existingStops.map((s) => s['parties'] as Map<String, dynamic>).toList();
      }

      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(emps as List);
          _parties = List<Map<String, dynamic>>.from(pts as List);
          _selectedStops = existingStops;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addParty() async {
    final available = _parties
        .where((p) => !_selectedStops.any((s) => s['id'] == p['id']))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All parties already added')),
      );
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PartyPickerDialog(parties: available),
    );

    if (selected != null) {
      setState(() => _selectedStops.add(selected));
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beat name is required')),
      );
      return;
    }
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign to an employee')),
      );
      return;
    }
    if (_selectedStops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one stop')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String beatId;

      if (widget.beat == null) {
        // Create
        final result = await SupabaseService.client.from('beats').insert({
          'name': _nameCtrl.text.trim(),
          'assigned_user': _selectedUserId,
          'day_of_week': _selectedDay,
          'created_by': SupabaseService.userId,
          'is_active': true,
        }).select().single();
        beatId = result['id'] as String;
      } else {
        // Update
        beatId = widget.beat!['id'] as String;
        await SupabaseService.client.from('beats').update({
          'name': _nameCtrl.text.trim(),
          'assigned_user': _selectedUserId,
          'day_of_week': _selectedDay,
        }).eq('id', beatId);
        // Delete old stops
        await SupabaseService.client.from('beat_stops').delete().eq('beat_id', beatId);
      }

      // Insert stops in sequence
      for (int i = 0; i < _selectedStops.length; i++) {
        await SupabaseService.client.from('beat_stops').insert({
          'beat_id': beatId,
          'party_id': _selectedStops[i]['id'],
          'sequence': i + 1,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.beat == null ? 'Beat created!' : 'Beat updated!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Save beat error: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.beat == null ? 'Create Beat' : 'Edit Beat',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Beat name
                _sectionCard([
                  CustomTextField(controller: _nameCtrl, label: 'Beat Name', hint: 'e.g. North Zone Monday Route'),
                  const SizedBox(height: 16),

                  // Assign employee
                  const Text('Assign To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    hint: const Text('Select employee'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _employees.map((e) => DropdownMenuItem(
                      value: e['id'] as String,
                      child: Text(e['full_name'] as String),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedUserId = v),
                  ),
                  const SizedBox(height: 16),

                  // Day of week
                  const Text('Day', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _selectedDay,
                    hint: const Text('Every day'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Every Day')),
                      ...List.generate(7, (i) => DropdownMenuItem<int?>(
                        value: i + 1,
                        child: Text(_days[i + 1]),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedDay = v),
                  ),
                ]),

                const SizedBox(height: 16),

                // Stops
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Stops (${_selectedStops.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Stop'),
                    onPressed: _addParty,
                  ),
                ]),
                const SizedBox(height: 8),

                if (_selectedStops.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('No stops added yet.\nTap "Add Stop" to build the route.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedStops.length,
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          if (newIdx > oldIdx) newIdx--;
                          final item = _selectedStops.removeAt(oldIdx);
                          _selectedStops.insert(newIdx, item);
                        });
                      },
                      itemBuilder: (_, i) {
                        final stop = _selectedStops[i];
                        return ListTile(
                          key: ValueKey(stop['id']),
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                          title: Text(stop['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(stop['city'] ?? '',
                              style: const TextStyle(fontSize: 12)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.drag_handle, color: Colors.grey),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: () => setState(() => _selectedStops.removeAt(i)),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),
                CustomButton(
                  text: widget.beat == null ? 'Create Beat' : 'Update Beat',
                  isLoading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 20),
              ]),
            ),
    );
  }

  Widget _sectionCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _PartyPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> parties;
  const _PartyPickerDialog({required this.parties});
  @override
  State<_PartyPickerDialog> createState() => _PartyPickerDialogState();
}

class _PartyPickerDialogState extends State<_PartyPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.parties;
    _searchCtrl.addListener(() {
      setState(() {
        _filtered = widget.parties
            .where((p) =>
                (p['name'] ?? '').toString().toLowerCase().contains(_searchCtrl.text.toLowerCase()) ||
                (p['city'] ?? '').toString().toLowerCase().contains(_searchCtrl.text.toLowerCase()))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Select Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search parties...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final p = _filtered[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text((p['name'] as String)[0].toUpperCase(),
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(p['city'] ?? ''),
                onTap: () => Navigator.pop(context, p),
              );
            },
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
