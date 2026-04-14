import 'package:flutter/material.dart';
import 'admin_shell.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title:
            const Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade400]),
                  shape: BoxShape.circle),
              child:
                  const Icon(Icons.location_on, size: 48, color: Colors.white)),
          const SizedBox(height: 16),
          const Text('FieldTrack Pro',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          _infoCard([
            _row(Icons.business, 'Publisher', 'Your Company Name'),
            const Divider(height: 1),
            _row(Icons.build, 'Built With', 'Flutter + Supabase'),
            const Divider(height: 1),
            _row(Icons.code, 'Platform', 'Android & iOS'),
            const Divider(height: 1),
            _row(Icons.calendar_today, 'Release Year', '2026'),
          ]),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 8)
                  ]),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What is FieldTrack Pro?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 10),
                    Text(
                        'FieldTrack Pro is a field sales force management platform '
                        'designed to help businesses track, manage and optimize their '
                        'field employee operations in real time.\n\n'
                        'Features include GPS tracking, visit management, expense '
                        'approvals, lead tracking, task assignment, attendance '
                        'monitoring, and AI-powered performance analytics.',
                        style: TextStyle(
                            color: Colors.black87, fontSize: 13, height: 1.6)),
                  ])),
          const SizedBox(height: 20),
          _infoCard([
            _row(Icons.privacy_tip_outlined, 'Privacy Policy', 'View Policy',
                isLink: true),
            const Divider(height: 1),
            _row(Icons.article_outlined, 'Terms of Service', 'View Terms',
                isLink: true),
            const Divider(height: 1),
            _row(Icons.support_agent, 'Support', 'support@yourcompany.com',
                isLink: true),
          ]),
          const SizedBox(height: 32),
          Text('© 2026 FieldTrack Pro. All rights reserved.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _infoCard(List<Widget> items) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ]),
      child: Column(children: items));

  Widget _row(IconData icon, String label, String value,
          {bool isLink = false}) =>
      ListTile(
          leading: Icon(icon, color: Colors.blue, size: 20),
          title: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          trailing: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isLink ? Colors.blue : Colors.black87)));
}
