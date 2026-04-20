import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/geofence_service.dart';

class AdminCompanyScreen extends StatefulWidget {
  const AdminCompanyScreen({super.key});

  @override
  State<AdminCompanyScreen> createState() => _AdminCompanyScreenState();
}

class _AdminCompanyScreenState extends State<AdminCompanyScreen> {
  final _nameC = TextEditingController();
  final _addressC = TextEditingController();
  final _panC = TextEditingController();
  final _tanC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _websiteC = TextEditingController();
  final _footerC = TextEditingController();
  String _logoUrl = '';
  String _brandColor = '#006A61';
  bool _isLoading = true;
  bool _isSaving = false;

  // Geofence settings
  double _defaultRadius = 200;
  String _enforcement = 'warn';

  final _settingKeys = [
    'company_name',
    'company_address',
    'company_logo_url',
    'company_pan',
    'company_tan',
    'company_email',
    'company_phone',
    'company_website',
    'brand_color',
    'payslip_footer_text',
    'default_geofence_radius',
    'geofence_enforcement',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _addressC.dispose();
    _panC.dispose();
    _tanC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _websiteC.dispose();
    _footerC.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.client
          .from('company_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', _settingKeys);

      final settings = <String, String>{};
      for (final s in result as List) {
        settings[s['setting_key']] =
            (s['setting_value'] ?? '').toString().replaceAll('"', '');
      }

      _nameC.text = settings['company_name'] ?? '';
      _addressC.text = settings['company_address'] ?? '';
      _panC.text = settings['company_pan'] ?? '';
      _tanC.text = settings['company_tan'] ?? '';
      _emailC.text = settings['company_email'] ?? '';
      _phoneC.text = settings['company_phone'] ?? '';
      _websiteC.text = settings['company_website'] ?? '';
      _footerC.text = settings['payslip_footer_text'] ??
          'This is a system-generated payslip and does not require a signature.';
      _logoUrl = settings['company_logo_url'] ?? '';
      _brandColor = settings['brand_color'] ?? '#006A61';
      _defaultRadius =
          double.tryParse(settings['default_geofence_radius'] ?? '200') ?? 200;
      _enforcement = settings['geofence_enforcement'] ?? 'warn';
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await image.readAsBytes();
      final fileName =
          'company/logo_${DateTime.now().millisecondsSinceEpoch}.png';

      await SupabaseService.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes);

      final url =
          SupabaseService.client.storage.from('uploads').getPublicUrl(fileName);

      setState(() => _logoUrl = url);

      await _saveSetting('company_logo_url', url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Logo uploaded!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    await SupabaseService.client
        .from('company_settings')
        .update({'setting_value': '"$value"'}).eq('setting_key', key);
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final updates = {
        'company_name': _nameC.text.trim(),
        'company_address': _addressC.text.trim(),
        'company_pan': _panC.text.trim().toUpperCase(),
        'company_tan': _tanC.text.trim().toUpperCase(),
        'company_email': _emailC.text.trim(),
        'company_phone': _phoneC.text.trim(),
        'company_website': _websiteC.text.trim(),
        'brand_color': _brandColor,
        'payslip_footer_text': _footerC.text.trim(),
      };

      for (final entry in updates.entries) {
        await _saveSetting(entry.key, entry.value);
      }

      // Save geofence settings
      await GeofenceService.updateDefaultRadius(_defaultRadius);
      await GeofenceService.updateEnforcement(_enforcement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('All settings saved!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _pickColor() {
    final colors = [
      '#006A61',
      '#1B5E20',
      '#0D47A1',
      '#4A148C',
      '#B71C1C',
      '#E65100',
      '#F57F17',
      '#263238',
      '#37474F',
      '#880E4F',
      '#1A237E',
      '#004D40',
      '#33691E',
      '#BF360C',
      '#3E2723',
      '#0097A7',
      '#7B1FA2',
      '#C62828',
      '#2E7D32',
      '#1565C0',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick Brand Color'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((hex) {
              final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
              final isSelected = hex.toUpperCase() == _brandColor.toUpperCase();
              return GestureDetector(
                onTap: () {
                  setState(() => _brandColor = hex);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.5), blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Company Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final brandColorParsed =
        Color(int.parse(_brandColor.replaceFirst('#', '0xFF')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveAll,
                  tooltip: 'Save All',
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo Section ──
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _uploadLogo,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _logoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(_logoUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.business,
                                      size: 40,
                                      color: Colors.grey)),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate,
                                    size: 36, color: Colors.grey.shade400),
                                const SizedBox(height: 4),
                                Text('Upload Logo',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                    ),
                  ),
                  if (_logoUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        setState(() => _logoUrl = '');
                        await _saveSetting('company_logo_url', '');
                      },
                      icon:
                          const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Remove Logo',
                          style: TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Brand Color ──
            _sectionTitle('Brand Color'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickColor,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: brandColorParsed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_brandColor.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Tap to change',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.color_lens, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Company Details ──
            _sectionTitle('Company Details'),
            const SizedBox(height: 8),
            _field('Company Name', _nameC, Icons.business),
            _field('Address', _addressC, Icons.location_on, maxLines: 3),
            _field('Email', _emailC, Icons.email,
                keyboardType: TextInputType.emailAddress),
            _field('Phone', _phoneC, Icons.phone,
                keyboardType: TextInputType.phone),
            _field('Website', _websiteC, Icons.language,
                keyboardType: TextInputType.url),
            const SizedBox(height: 20),

            // ── Statutory ──
            _sectionTitle('Statutory Details'),
            const SizedBox(height: 8),
            _field('PAN Number', _panC, Icons.credit_card,
                textCap: TextCapitalization.characters),
            _field('TAN Number', _tanC, Icons.credit_card,
                textCap: TextCapitalization.characters),
            const SizedBox(height: 20),

            // ── Payslip ──
            _sectionTitle('Payslip Settings'),
            const SizedBox(height: 8),
            _field('Payslip Footer Text', _footerC, Icons.text_fields,
                maxLines: 2),
            const SizedBox(height: 24),

            // ── Geofence Settings ──
            _sectionTitle('Geofence Settings'),
            const SizedBox(height: 4),
            Text(
              'Control how strictly employees must be near the client location to start a visit.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location,
                          size: 20, color: brandColorParsed),
                      const SizedBox(width: 8),
                      const Text('Default Radius',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: brandColorParsed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_defaultRadius.toStringAsFixed(0)}m',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: brandColorParsed),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: brandColorParsed,
                      thumbColor: brandColorParsed,
                      overlayColor: brandColorParsed.withOpacity(0.2),
                      inactiveTrackColor: brandColorParsed.withOpacity(0.15),
                    ),
                    child: Slider(
                      value: _defaultRadius,
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      label: '${_defaultRadius.toStringAsFixed(0)}m',
                      onChanged: (v) => setState(() => _defaultRadius = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('50m',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      Text('1000m',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 20, color: brandColorParsed),
                      const SizedBox(width: 8),
                      const Text('Enforcement Mode',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _enforcementOption(
                    'strict',
                    'Strict',
                    'Block check-in if outside geofence',
                    Icons.block,
                    Colors.red,
                    brandColorParsed,
                  ),
                  const SizedBox(height: 6),
                  _enforcementOption(
                    'warn',
                    'Warn',
                    'Allow check-in but show warning',
                    Icons.warning_amber_rounded,
                    Colors.orange,
                    brandColorParsed,
                  ),
                  const SizedBox(height: 6),
                  _enforcementOption(
                    'off',
                    'Off',
                    'No geofence validation',
                    Icons.location_off,
                    Colors.grey,
                    brandColorParsed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Payslip Header Preview ──
            _sectionTitle('Payslip Header Preview'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandColorParsed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_logoUrl.isNotEmpty)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.business, size: 20)),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _nameC.text.isNotEmpty
                              ? _nameC.text.toUpperCase()
                              : 'COMPANY NAME',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const Text('PAYSLIP',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('April 2026',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text('CONFIDENTIAL',
                          style: TextStyle(color: Colors.white70, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Save Button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAll,
                icon: const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save All Settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: brandColorParsed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _enforcementOption(String value, String title, String subtitle,
      IconData icon, Color iconColor, Color brandColor) {
    final isSelected = _enforcement == value;
    return GestureDetector(
      onTap: () => setState(() => _enforcement = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? brandColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isSelected ? brandColor : Colors.black87)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: brandColor),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF006A61)));
  }

  Widget _field(String label, TextEditingController controller, IconData icon,
      {int maxLines = 1,
      TextInputType? keyboardType,
      TextCapitalization textCap = TextCapitalization.none}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
