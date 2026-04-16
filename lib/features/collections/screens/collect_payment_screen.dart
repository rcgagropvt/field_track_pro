import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/collection_service.dart';

bool _isPDC = false;
final _chequeNoCtrl = TextEditingController();
final _chequeBankCtrl = TextEditingController();
DateTime _chequeDate = DateTime.now().add(const Duration(days: 7));

class CollectPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const CollectPaymentScreen({super.key, required this.invoice});
  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMode = 'cash';
  bool _whatsappAuto = true;
  bool _saving = false;

  double get _balance => (widget.invoice['balance'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _balance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      _snack('Enter a valid amount', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await CollectionService.submitCollection(
        invoiceId: widget.invoice['id'] as String,
        partyId: widget.invoice['party_id'] as String,
        partyName: widget.invoice['party_name'] as String,
        amount: amount,
        paymentMode: _paymentMode,
        referenceNo: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        whatsappAuto: _whatsappAuto,
      );

      if (mounted) {
        _snack('Payment submitted for admin approval ✅');
        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Collect Payment',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Invoice summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.75)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.invoice['party_name'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(widget.invoice['invoice_number'] ?? '',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _invoiceStat('Invoice', '₹${widget.invoice['amount']}'),
                      _invoiceStat('Paid', '₹${widget.invoice['amount_paid']}'),
                      _invoiceStat('Balance', '₹${_balance.toStringAsFixed(0)}',
                          highlight: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment details
            _card('Payment Details', [
              // Amount
              const Text('Amount Collecting (₹)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter valid amount';
                  if (n > _balance)
                    return 'Cannot exceed balance ₹${_balance.toStringAsFixed(0)}';
                  return null;
                },
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),

              const SizedBox(height: 16),

              // Payment mode
              const Text('Payment Mode',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['cash', 'upi', 'cheque', 'bank_transfer', 'other']
                    .map((mode) {
                  final sel = _paymentMode == mode;
                  final icons = {
                    'cash': Icons.money,
                    'upi': Icons.phone_android,
                    'cheque': Icons.receipt_long,
                    'bank_transfer': Icons.account_balance,
                    'other': Icons.more_horiz,
                  };
                  return GestureDetector(
                    onTap: () => setState(() => _paymentMode = mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            sel ? AppColors.primary : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icons[mode],
                            size: 15, color: sel ? Colors.white : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          mode == 'bank_transfer'
                              ? 'Bank'
                              : mode[0].toUpperCase() + mode.substring(1),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: sel ? Colors.white : Colors.black87),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              if (_paymentMode == 'cheque') ...[
                // PDC Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Post-Dated Cheque (PDC)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('Cheque date is in the future',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ]),
                    ),
                    Switch(
                      value: _isPDC,
                      onChanged: (v) => setState(() => _isPDC = v),
                      activeColor: Colors.orange,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                if (_isPDC) ...[
                  _inputField('Cheque Number', _chequeNoCtrl,
                      hint: 'e.g. 123456'),
                  const SizedBox(height: 12),
                  _inputField('Bank Name', _chequeBankCtrl,
                      hint: 'e.g. HDFC Bank'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _chequeDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                      );
                      if (d != null) setState(() => _chequeDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text('Cheque Date: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 13)),
                        Text(
                          '${_chequeDate.day}/${_chequeDate.month}/${_chequeDate.year}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              // Reference number (shown for non-cash)
              if (_paymentMode != 'cash') ...[
                _inputField(
                  'Reference / UTR / Cheque No.',
                  _refCtrl,
                  hint: 'Optional',
                ),
                const SizedBox(height: 12),
              ],

              _inputField('Notes', _notesCtrl, hint: 'Optional', maxLines: 2),
            ]),

            const SizedBox(height: 16),

            // WhatsApp notification toggle
            _card('Customer Notification', [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.chat, color: Colors.green.shade600, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WhatsApp on Confirmation',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        'Auto-send WhatsApp to customer when admin confirms',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _whatsappAuto,
                  onChanged: (v) => setState(() => _whatsappAuto = v),
                  activeColor: Colors.green,
                ),
              ]),
              if (_whatsappAuto)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer will receive a WhatsApp payment receipt automatically when admin confirms.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.green.shade700),
                      ),
                    ),
                  ]),
                ),
            ]),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Submitting...' : 'Submit for Approval',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _invoiceStat(String label, String value, {bool highlight = false}) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: highlight ? Colors.yellowAccent : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: highlight ? 18 : 15)),
    ]);
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}


