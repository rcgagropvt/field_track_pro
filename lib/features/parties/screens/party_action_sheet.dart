import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../visits/screens/start_visit_screen.dart';
import 'party_profile_screen.dart';

/// Replace every:
///   Navigator.push(... PartyProfileScreen(party: p))
/// in rep-facing screens with:
///   showPartyActionSheet(context, party: p)
Future<void> showPartyActionSheet(
  BuildContext context, {
  required Map<String, dynamic> party,
  bool isAdmin = false,
  VoidCallback? onActionCompleted,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PartyActionSheet(
      party: party,
      isAdmin: isAdmin,
      onActionCompleted: onActionCompleted,
    ),
  );
}

class _PartyActionSheet extends StatefulWidget {
  final Map<String, dynamic> party;
  final bool isAdmin;
  final VoidCallback? onActionCompleted;
  const _PartyActionSheet({
    required this.party,
    required this.isAdmin,
    this.onActionCompleted,
  });
  @override
  State<_PartyActionSheet> createState() => _PartyActionSheetState();
}

class _PartyActionSheetState extends State<_PartyActionSheet> {
  double _outstanding = 0;
  bool _loadingOutstanding = true;

  @override
  void initState() {
    super.initState();
    _fetchOutstanding();
  }

  Future<void> _fetchOutstanding() async {
    try {
      final rows = await SupabaseService.client
          .from('invoices')
          .select('balance, status')
          .eq('party_id', widget.party['id'] as String);
      final total = (rows as List).fold<double>(0, (s, i) =>
          i['status'] != 'paid' ? s + ((i['balance'] as num?)?.toDouble() ?? 0) : s);
      if (mounted) setState(() { _outstanding = total; _loadingOutstanding = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOutstanding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final party  = widget.party;
    final name   = (party['name'] ?? 'Party') as String;
    final phone  = party['phone'] as String?;
    final city   = party['city'] as String?;
    final type   = (party['type'] ?? 'party').toString().toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ──────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // ── Party identity strip ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        _typePill(type),
                        if (city != null && city.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Text(city,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ]),
                    ],
                  ),
                ),
                // Outstanding badge (right corner)
                _loadingOutstanding
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Outstanding',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade400)),
                        Text(
                          '₹${_fmtShort(_outstanding)}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _outstanding > 0
                                  ? Colors.orange.shade700
                                  : Colors.green),
                        ),
                      ]),
              ]),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── PRIMARY: Start Visit ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StartVisitScreen(party: party)),
                    );
                    widget.onActionCompleted?.call();
                  },
                  icon: const Icon(Icons.directions_walk_rounded,
                      color: Colors.white, size: 20),
                  label: const Text('Start Visit',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── SECONDARY ROW: View Profile + Call ──────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: _SecondaryBtn(
                    icon: Icons.person_outline_rounded,
                    label: 'View Profile',
                    color: AppColors.primary,
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PartyProfileScreen(
                            party: party,
                            isAdmin: widget.isAdmin,
                          ),
                        ),
                      );
                      widget.onActionCompleted?.call();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SecondaryBtn(
                    icon: Icons.phone_outlined,
                    label: phone != null ? 'Call' : 'No Phone',
                    color: phone != null ? Colors.green : Colors.grey,
                    onTap: phone != null
                        ? () async {
                            Navigator.pop(context);
                            final uri = Uri(scheme: 'tel', path: phone);
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          }
                        : null,
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _typePill(String type) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(type,
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );

  String _fmtShort(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
