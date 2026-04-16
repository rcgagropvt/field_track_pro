import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class CollectionService {
  /// Called right after an order is inserted — creates the invoice
  static Future<String?> createInvoiceForOrder({
    required String orderId,
    required String partyId,
    required String partyName,
    required String userId,
    required double amount,
    required int dueDays,
  }) async {
    try {
      final dueDate = DateTime.now().add(Duration(days: dueDays));
      final result = await SupabaseService.client
          .from('invoices')
          .insert({
            'order_id': orderId,
            'party_id': partyId,
            'party_name': partyName,
            'user_id': userId,
            'amount': amount,
            'amount_paid': 0,
            'due_date': dueDate.toIso8601String().substring(0, 10),
            'status': 'unpaid',
          })
          .select('id')
          .single();
      return result['id'] as String?;
    } catch (e) {
      debugPrint('Invoice creation error: $e');
      return null;
    }
  }

  /// Fetch all invoices for a party
  static Future<List<Map<String, dynamic>>> getPartyInvoices(
      String partyId) async {
    final data = await SupabaseService.client
        .from('invoices')
        .select()
        .eq('party_id', partyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Fetch all outstanding invoices for current rep
  static Future<List<Map<String, dynamic>>> getOutstandingInvoices() async {
    final uid = SupabaseService.userId!;
    final data = await SupabaseService.client
        .from('invoices')
        .select()
        .eq('user_id', uid)
        .neq('status', 'paid')
        .order('due_date', ascending: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Submit a collection (payment received)
  static Future<String?> submitCollection({
    required String invoiceId,
    required String partyId,
    required String partyName,
    required double amount,
    required String paymentMode,
    String? referenceNo,
    String? notes,
    required bool whatsappAuto,
  }) async {
    final uid = SupabaseService.userId!;
    final result = await SupabaseService.client
        .from('collections')
        .insert({
          'invoice_id': invoiceId,
          'party_id': partyId,
          'party_name': partyName,
          'user_id': uid,
          'amount_collected': amount,
          'payment_mode': paymentMode,
          'reference_no': referenceNo,
          'notes': notes,
          'status': 'pending',
          'whatsapp_auto': whatsappAuto,
          'whatsapp_sent': false,
        })
        .select('id')
        .single();
    return result['id'] as String?;
  }

  /// Admin confirms a collection — updates invoice + optionally sends WhatsApp
  static Future<void> confirmCollection({
    required String collectionId,
    required String invoiceId,
    required double amountCollected,
    required bool sendWhatsApp,
    Map<String, dynamic>? whatsappData,
  }) async {
    final uid = SupabaseService.userId!;

    // 1. Update collection status
    await SupabaseService.client.from('collections').update({
      'status': 'confirmed',
      'confirmed_at': DateTime.now().toIso8601String(),
      'confirmed_by': uid,
      'whatsapp_sent': sendWhatsApp,
    }).eq('id', collectionId);

    // 2. Fetch invoice
    final invoice = await SupabaseService.client
        .from('invoices')
        .select()
        .eq('id', invoiceId)
        .single();

    final currentPaid = (invoice['amount_paid'] as num?)?.toDouble() ?? 0;
    final total = (invoice['amount'] as num).toDouble();
    final newPaid = currentPaid + amountCollected;
    final newStatus =
        newPaid >= total ? 'paid' : (newPaid > 0 ? 'partial' : 'unpaid');

    // 3. Update invoice
    await SupabaseService.client.from('invoices').update({
      'amount_paid': newPaid,
      'status': newStatus,
    }).eq('id', invoiceId);

    // 4. Send WhatsApp if requested
    if (sendWhatsApp && whatsappData != null) {
      await SupabaseService.client.functions.invoke(
        'whatsapp-notify',
        body: {
          'type': 'payment_confirmed',
          'data': whatsappData,
        },
      );
    }
  }

  /// Admin sends payment reminder manually
  static Future<void> sendPaymentReminder({
    required String phone,
    required String partyName,
    required String invoiceNumber,
    required double balance,
    required String dueDate,
  }) async {
    await SupabaseService.client.functions.invoke(
      'whatsapp-notify',
      body: {
        'type': 'payment_reminder',
        'data': {
          'phone': phone,
          'party_name': partyName,
          'invoice_number': invoiceNumber,
          'balance': balance.toStringAsFixed(0),
          'due_date': dueDate,
        },
      },
    );
  }

  /// Check if party has exceeded credit limit
  static Future<Map<String, dynamic>> checkCreditLimit({
    required String partyId,
    required double newOrderAmount,
  }) async {
    try {
      final party = await SupabaseService.client
          .from('parties')
          .select('credit_limit, name')
          .eq('id', partyId)
          .single();

      final limit = (party['credit_limit'] as num?)?.toDouble() ?? 0;
      if (limit == 0) return {'exceeded': false, 'limit': 0, 'outstanding': 0};

      final invoices = await SupabaseService.client
          .from('invoices')
          .select('balance')
          .eq('party_id', partyId)
          .neq('status', 'paid');

      final outstanding = (invoices as List)
          .fold(0.0, (s, i) => s + ((i['balance'] as num?)?.toDouble() ?? 0));

      final total = outstanding + newOrderAmount;
      return {
        'exceeded': total > limit,
        'limit': limit,
        'outstanding': outstanding,
        'total': total,
        'party_name': party['name'],
      };
    } catch (e) {
      return {'exceeded': false, 'limit': 0, 'outstanding': 0};
    }
  }

  /// Submit a PDC (Post-Dated Cheque) collection
  static Future<String?> submitPDC({
    required String invoiceId,
    required String partyId,
    required String partyName,
    required double amount,
    required String chequeNumber,
    required DateTime chequeDate,
    required String chequeBank,
    String? notes,
  }) async {
    final uid = SupabaseService.userId!;
    final result = await SupabaseService.client
        .from('collections')
        .insert({
          'invoice_id': invoiceId,
          'party_id': partyId,
          'party_name': partyName,
          'user_id': uid,
          'amount_collected': amount,
          'payment_mode': 'cheque',
          'is_pdc': true,
          'cheque_number': chequeNumber,
          'cheque_date': chequeDate.toIso8601String().substring(0, 10),
          'cheque_bank': chequeBank,
          'notes': notes,
          'status': 'pending',
          'whatsapp_auto': false,
        })
        .select('id')
        .single();
    return result['id'] as String?;
  }

  /// Get collection target for current rep this month
  static Future<Map<String, dynamic>?> getCollectionTarget() async {
    final uid = SupabaseService.userId!;
    final now = DateTime.now();
    final result = await SupabaseService.client
        .from('collection_targets')
        .select()
        .eq('user_id', uid)
        .eq('month', now.month)
        .eq('year', now.year)
        .limit(1);
    return (result as List).isNotEmpty ? result.first : null;
  }

  /// Get total confirmed collections this month for current rep
  static Future<double> getMonthlyCollected() async {
    final uid = SupabaseService.userId!;
    final now = DateTime.now();
    final from =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01T00:00:00.000';
    final nm = now.month == 12 ? 1 : now.month + 1;
    final ny = now.month == 12 ? now.year + 1 : now.year;
    final to = '$ny-${nm.toString().padLeft(2, '0')}-01T00:00:00.000';

    final result = await SupabaseService.client
        .from('collections')
        .select('amount_collected')
        .eq('user_id', uid)
        .eq('status', 'confirmed')
        .gte('collected_at', from)
        .lt('collected_at', to);

    return (result as List).fold<double>(
        0.0, (s, c) => s + ((c['amount_collected'] as num).toDouble()));
  }
}
