import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class LeaderboardShare {
  static Future<void> shareToWhatsApp({
    required List<Map<String, dynamic>> leaderboard,
    required String period,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🏆 *FieldTrack Pro - ${period.toUpperCase()} Leaderboard* 🏆');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('');

    const medals = ['🥇', '🥈', '🥉'];

    for (int i = 0; i < leaderboard.length && i < 10; i++) {
      final e = leaderboard[i];
      final name = e['out_full_name'] ?? e['full_name'] ?? '';
      final visits = e['out_visits'] ?? e['total_visits'] ?? 0;
      final orders = e['out_orders'] ?? e['total_orders'] ?? 0;
      final revenue = e['out_revenue'] ?? e['total_revenue'] ?? 0;
      final medal = i < 3 ? medals[i] : '  ${i + 1}.';

      buffer.writeln('$medal *$name*');
      buffer.writeln('    📍 $visits visits  •  📦 $orders orders  •  💰 ₹${_formatNum(revenue)}');
      buffer.writeln('');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Keep pushing team! 💪🔥');
    buffer.writeln('');
    buffer.writeln('_Sent via FieldTrack Pro_');

    final text = Uri.encodeComponent(buffer.toString());
    final whatsappUrl = Uri.parse('https://wa.me/?text=$text');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to share_plus
        await Share.share(buffer.toString(), subject: 'FieldTrack Pro Leaderboard');
      }
    } catch (_) {
      await Share.share(buffer.toString(), subject: 'FieldTrack Pro Leaderboard');
    }
  }

  static String _formatNum(dynamic num) {
    if (num == null) return '0';
    final n = double.tryParse(num.toString()) ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}
