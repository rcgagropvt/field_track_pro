import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class WhatsAppService {
  static Future<void> sendOrderConfirmation({
    required String phone,
    required String partyName,
    required double total,
    required String orderId,
  }) async {
    try {
      await SupabaseService.client.functions.invoke(
        'whatsapp-notify',
        body: {
          'type': 'order_created',
          'data': {
            'phone': phone,
            'party_name': partyName,
            'total': total.toStringAsFixed(0),
            'order_id': orderId,
          },
        },
      );
      debugPrint('WhatsApp order notification sent to $phone');
    } catch (e) {
      debugPrint('WhatsApp notify error: $e');
      // Don't rethrow — notification failure should never block order flow
    }
  }

  static Future<void> sendVisitSummary({
    required String phone,
    required String partyName,
    required String time,
  }) async {
    try {
      await SupabaseService.client.functions.invoke(
        'whatsapp-notify',
        body: {
          'type': 'visit_completed',
          'data': {
            'phone': phone,
            'party_name': partyName,
            'time': time,
          },
        },
      );
      debugPrint('WhatsApp visit notification sent to $phone');
    } catch (e) {
      debugPrint('WhatsApp notify error: $e');
    }
  }
}

