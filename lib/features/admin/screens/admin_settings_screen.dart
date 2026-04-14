import 'package:flutter/material.dart';
import 'admin_shell.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _locationTracking = true;
  bool _expenseNotifs = true;
  bool _checkInNotifs = true;
  bool _taskNotifs = true;
  bool _autoApproveUnder500 = false;
  int _trackingIntervalMin = 5;

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Tracking'),
        _card([
          _toggle('Live Location Tracking', 'Track employee GPS in real time',
              _locationTracking, (v) => setState(() => _locationTracking = v)),
          const Divider(height: 1),
          _slider(
              'Tracking Interval',
              'Update location every $_trackingIntervalMin min',
              _trackingIntervalMin.toDouble(),
              1,
              30,
              (v) => setState(() => _trackingIntervalMin = v.toInt())),
        ]),
        _section('Notifications'),
        _card([
          _toggle('Expense Claims', 'Alert when employees submit expenses',
              _expenseNotifs, (v) => setState(() => _expenseNotifs = v)),
          const Divider(height: 1),
          _toggle('Check-in / Check-out', 'Alert on daily attendance events',
              _checkInNotifs, (v) => setState(() => _checkInNotifs = v)),
          const Divider(height: 1),
          _toggle('Task Updates', 'Alert when tasks are completed or updated',
              _taskNotifs, (v) => setState(() => _taskNotifs = v)),
        ]),
        _section('Expense Policy'),
        _card([
          _toggle(
              'Auto-approve under ₹500',
              'Expenses below ₹500 are auto-approved',
              _autoApproveUnder500,
              (v) => setState(() => _autoApproveUnder500 = v)),
        ]),
        _section('Data'),
        _card([
          _actionTile(Icons.file_download_outlined, 'Export Attendance CSV',
              Colors.green, () => _toast('Export coming soon')),
          const Divider(height: 1),
          _actionTile(Icons.file_download_outlined, 'Export Expense Report',
              Colors.orange, () => _toast('Export coming soon')),
          const Divider(height: 1),
          _actionTile(Icons.sync, 'Force Sync All Data', Colors.blue,
              () => _toast('Sync triggered')),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _toast('✅ Settings saved'),
            icon: const Icon(Icons.save),
            label: const Text('Save Settings',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8)));

  Widget _card(List<Widget> children) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ]),
      child: Column(children: children));

  Widget _toggle(String title, String subtitle, bool value,
          ValueChanged<bool> onChanged) =>
      SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
          title: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey)));

  Widget _slider(String title, String subtitle, double value, double min,
          double max, ValueChanged<double> onChanged) =>
      ListTile(
          title: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Slider(
                value: value,
                min: min,
                max: max,
                divisions: (max - min).toInt(),
                onChanged: onChanged,
                activeColor: Colors.blue),
          ]));

  Widget _actionTile(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
          leading: Icon(icon, color: color, size: 20),
          title: Text(label, style: const TextStyle(fontSize: 14)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap);
}
