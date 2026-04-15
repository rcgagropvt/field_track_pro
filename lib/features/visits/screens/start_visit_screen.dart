import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../orders/screens/order_booking_screen.dart';

class StartVisitScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  const StartVisitScreen({super.key, required this.party});

  @override
  State<StartVisitScreen> createState() => _StartVisitScreenState();
}

class _StartVisitScreenState extends State<StartVisitScreen> {
  // Visit state
  String _status = 'not_started'; // not_started, in_progress, completed
  String? _visitId;
  DateTime? _checkInTime;
  Timer? _durationTimer;
  int _durationSeconds = 0;

  // Form controllers
  final _notesCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final _orderValueCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  String _purpose = 'sales';
  String _outcome = 'successful';
  String _paymentMode = 'none';
  int _rating = 3;

  // Photos
  final List<String> _photoUrls = [];
  String? _checkInSelfie;
  final _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _startVisit() async {
    setState(() => _isLoading = true);

    try {
      // Get current location
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        _showSnack('Location required to start visit', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Take mandatory selfie
      final selfie = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 60,
        maxWidth: 640,
      );

      if (selfie == null) {
        _showSnack('Selfie is mandatory to start visit', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Upload selfie
      final bytes = await selfie.readAsBytes();
      final fileName =
          'visits/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}_checkin.jpg';
      await SupabaseService.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes);
      final selfieUrl =
          SupabaseService.client.storage.from('uploads').getPublicUrl(fileName);

      // Create visit record
      final response = await SupabaseService.client
          .from('visits')
          .insert({
            'user_id': SupabaseService.userId,
            'party_id': widget.party['id'],
            'party_name': widget.party['name'],
            'party_address': widget.party['address'],
            'check_in_time': DateTime.now().toIso8601String(),
            'check_in_lat': pos.latitude,
            'check_in_lng': pos.longitude,
            'check_in_selfie': selfieUrl,
            'purpose': _purpose,
            'status': 'in_progress',
          })
          .select()
          .single();

      setState(() {
        _status = 'in_progress';
        _visitId = response['id'];
        _checkInTime = DateTime.now();
        _checkInSelfie = selfieUrl;
      });

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _durationSeconds++);
      });

      _showSnack('Visit started at ${widget.party['name']}');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (photo == null) return;

    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          'visits/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}_proof.jpg';
      await SupabaseService.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes);
      final url =
          SupabaseService.client.storage.from('uploads').getPublicUrl(fileName);
      setState(() => _photoUrls.add(url));
      _showSnack('Photo added');
    } catch (e) {
      _showSnack('Upload failed', isError: true);
    }
  }

  Future<void> _endVisit() async {
    if (_visitId == null) return;
    setState(() => _isLoading = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      _durationTimer?.cancel();

      // Take checkout selfie
      final selfie = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 60,
        maxWidth: 640,
      );

      String? checkOutSelfie;
      if (selfie != null) {
        final bytes = await selfie.readAsBytes();
        final fileName =
            'visits/${SupabaseService.userId}/${DateTime.now().millisecondsSinceEpoch}_checkout.jpg';
        await SupabaseService.client.storage
            .from('uploads')
            .uploadBinary(fileName, bytes);
        checkOutSelfie = SupabaseService.client.storage
            .from('uploads')
            .getPublicUrl(fileName);
      }

      await SupabaseService.client.from('visits').update({
        'check_out_time': DateTime.now().toIso8601String(),
        'check_out_lat': pos?.latitude,
        'check_out_lng': pos?.longitude,
        'check_out_selfie': checkOutSelfie,
        'discussion_notes': _notesCtrl.text.trim(),
        'feedback': _feedbackCtrl.text.trim(),
        'purpose': _purpose,
        'outcome': _outcome,
        'order_value': double.tryParse(_orderValueCtrl.text) ?? 0,
        'payment_collected': double.tryParse(_paymentCtrl.text) ?? 0,
        'payment_mode': _paymentMode,
        'photos': _photoUrls,
        'visit_rating': _rating,
        'duration_minutes': (_durationSeconds / 60).round(),
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _visitId!);

      setState(() => _status = 'completed');
      _showSnack('Visit completed successfully!');

      // Wait a moment then pop
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _notesCtrl.dispose();
    _feedbackCtrl.dispose();
    _orderValueCtrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.party['name'] ?? 'Visit'),
        actions: [
          if (_status == 'in_progress')
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_durationSeconds),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Party Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.party['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white)),
                  if (widget.party['contact_person'] != null)
                    Text(widget.party['contact_person'],
                        style:
                            TextStyle(color: AppColors.white.withOpacity(0.8))),
                  if (widget.party['address'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14,
                              color: AppColors.white.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(widget.party['address'],
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.white.withOpacity(0.7))),
                          ),
                        ],
                      ),
                    ),
                  if (widget.party['phone'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.phone,
                              size: 14,
                              color: AppColors.white.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(widget.party['phone'],
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.white.withOpacity(0.7))),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── NOT STARTED: Show Start button ──
            if (_status == 'not_started') ...[
              // Purpose selector
              const Text('Visit Purpose',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'sales',
                  'collection',
                  'delivery',
                  'complaint',
                  'follow_up',
                  'new_introduction'
                ].map((p) {
                  final selected = _purpose == p;
                  return ChoiceChip(
                    label: Text(p.replaceAll('_', ' ').toUpperCase()),
                    selected: selected,
                    onSelected: (_) => setState(() => _purpose = p),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.white : AppColors.primary),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will need to take a selfie and allow GPS access to start this visit.',
                        style: TextStyle(fontSize: 13, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              CustomButton(
                text: 'Start Visit (Selfie + GPS)',
                onPressed: _startVisit,
                isLoading: _isLoading,
                icon: Icons.play_arrow_rounded,
              ),
            ],

            // ── IN PROGRESS: Show visit form ──
            if (_status == 'in_progress') ...[
              // Check-in confirmation
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Checked In',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success)),
                          Text(
                            _checkInTime != null
                                ? DateFormat('hh:mm a').format(_checkInTime!)
                                : '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Discussion Notes
              const Text('Discussion Notes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _notesCtrl,
                hint: 'What was discussed with the dealer...',
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Order Booking
              const Text('Order',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderBookingScreen(
                              party: widget.party,
                              visitId: _visitId,
                            ),
                          ),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _orderValueCtrl.text =
                                result['total'].toStringAsFixed(2);
                          });
                          _showSnack('Order ${result['order_number']} placed!');
                        }
                      },
                      icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                      label: const Text('Book Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _orderValueCtrl,
                      label: 'Order Value (₹)',
                      prefixIcon: Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Payment collected manually
              CustomTextField(
                controller: _paymentCtrl,
                label: 'Payment Collected (₹)',
                prefixIcon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              // Payment mode
              DropdownButtonFormField<String>(
                value: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: Icon(Icons.account_balance_wallet, size: 20),
                ),
                items: ['none', 'cash', 'upi', 'cheque', 'online', 'credit']
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.toUpperCase(),
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _paymentMode = v!),
              ),

              const SizedBox(height: 16),

              // Photo proof
              const Text('Photo Proof',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._photoUrls.map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(url,
                            width: 70, height: 70, fit: BoxFit.cover),
                      )),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary, style: BorderStyle.solid),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Feedback
              CustomTextField(
                controller: _feedbackCtrl,
                label: 'Dealer Feedback / Complaints',
                hint: 'Any feedback or complaints...',
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Outcome
              const Text('Visit Outcome',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'successful',
                  'follow_up_needed',
                  'not_interested',
                  'shop_closed'
                ].map((o) {
                  final selected = _outcome == o;
                  return ChoiceChip(
                    label: Text(o.replaceAll('_', ' ').toUpperCase()),
                    selected: selected,
                    onSelected: (_) => setState(() => _outcome = o),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.white : AppColors.primary),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Rating
              const Text('Rate This Visit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppColors.warning,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // End Visit Button
              CustomButton(
                text: 'End Visit (Selfie + GPS)',
                onPressed: _endVisit,
                isLoading: _isLoading,
                icon: Icons.stop_rounded,
                color: AppColors.error,
              ),
            ],

            // ── COMPLETED ──
            if (_status == 'completed') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 48, color: AppColors.success),
                    SizedBox(height: 12),
                    Text('Visit Completed!',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
