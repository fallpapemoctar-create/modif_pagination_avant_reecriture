import 'package:flutter/material.dart';

import '../core/brand_footer.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../models/company_info.dart';
import '../services/company_info_service.dart';

class CompanyInfoPage extends StatefulWidget {
  final UserRights userRights;
  const CompanyInfoPage({super.key, required this.userRights});

  @override
  State<CompanyInfoPage> createState() => _CompanyInfoPageState();
}

class _CompanyInfoPageState extends State<CompanyInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _address1Ctrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  CompanyInfo? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _siretCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await CompanyInfoService.fetch();
      if (!mounted) return;
      _current = info;
      _populate(info);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      _current = CompanyInfo.fallback();
      _populate(_current!);
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _populate(CompanyInfo info) {
    _nameCtrl.text = info.name;
    _address1Ctrl.text = info.addressLine1;
    _address2Ctrl.text = info.addressLine2;
    _postalCodeCtrl.text = info.postalCode;
    _cityCtrl.text = info.city;
    _siretCtrl.text = info.siret;
    _phoneCtrl.text = info.phone;
    _emailCtrl.text = info.email;
    _websiteCtrl.text = info.website;
    _logoUrlCtrl.text = info.logoUrl;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final bankInfo = _current;
    final info = CompanyInfo(
      name: _nameCtrl.text.trim(),
      addressLine1: _address1Ctrl.text.trim(),
      addressLine2: _address2Ctrl.text.trim(),
      postalCode: _postalCodeCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      siret: _siretCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: _websiteCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      bankLabel: bankInfo?.bankLabel ?? '',
      bankName: bankInfo?.bankName ?? '',
      bankCode: bankInfo?.bankCode ?? '',
      bankBranchCode: bankInfo?.bankBranchCode ?? '',
      bankAccountNumber: bankInfo?.bankAccountNumber ?? '',
      bankRibKey: bankInfo?.bankRibKey ?? '',
      bankBic: bankInfo?.bankBic ?? '',
      bankIban: bankInfo?.bankIban ?? '',
      bankDomiciliation: bankInfo?.bankDomiciliation ?? '',
      bankAccountHolder: bankInfo?.bankAccountHolder ?? '',
      bankOwnerAddress: bankInfo?.bankOwnerAddress ?? '',
      bankOwnerPostalCode: bankInfo?.bankOwnerPostalCode ?? '',
      bankOwnerCity: bankInfo?.bankOwnerCity ?? '',
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await CompanyInfoService.update(info);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _current = saved;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Informations enregistrées')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.userRights.isAdmin())) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuration entreprise')),
        body: const Center(child: Text('Vous n\'avez pas les droits pour accéder à cette page.')),
      );
    }

    final spacing = ResponsiveHelper.getSpacing(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration entreprise'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing),
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Attention: $_error',
                                    style: const TextStyle(color: Color(0xFFB45309)),
                                  ),
                                ),
                              _buildSectionTitle('Identité'),
                              _buildTextField(_nameCtrl, 'Nom de l\'entreprise', requiredField: true),
                              const SizedBox(height: 8),
                              _buildTextField(_logoUrlCtrl, 'URL du logo (optionnel)', keyboardType: TextInputType.url),
                              const SizedBox(height: 24),
                              _buildSectionTitle('Adresse'),
                              _buildTextField(_address1Ctrl, 'Adresse ligne 1', requiredField: true),
                              const SizedBox(height: 8),
                              _buildTextField(_address2Ctrl, 'Adresse ligne 2'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(_postalCodeCtrl, 'Code postal', requiredField: true)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTextField(_cityCtrl, 'Ville', requiredField: true)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildSectionTitle('Informations légales & contact'),
                              _buildTextField(_siretCtrl, 'Siret', requiredField: true),
                              const SizedBox(height: 8),
                              _buildTextField(_phoneCtrl, 'Téléphone'),
                              const SizedBox(height: 8),
                              _buildTextField(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 8),
                              _buildTextField(_websiteCtrl, 'Site web', keyboardType: TextInputType.url),
                              const SizedBox(height: 24),
                              _buildPreviewCard(),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool requiredField = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Champ requis';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildPreviewCard() {
    final bankInfo = _current;
    final info = CompanyInfo(
      name: _nameCtrl.text.trim().isEmpty ? 'Nom entreprise' : _nameCtrl.text.trim(),
      addressLine1: _address1Ctrl.text.trim(),
      addressLine2: _address2Ctrl.text.trim(),
      postalCode: _postalCodeCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      siret: _siretCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: _websiteCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      bankLabel: bankInfo?.bankLabel ?? '',
      bankName: bankInfo?.bankName ?? '',
      bankCode: bankInfo?.bankCode ?? '',
      bankBranchCode: bankInfo?.bankBranchCode ?? '',
      bankAccountNumber: bankInfo?.bankAccountNumber ?? '',
      bankRibKey: bankInfo?.bankRibKey ?? '',
      bankBic: bankInfo?.bankBic ?? '',
      bankIban: bankInfo?.bankIban ?? '',
      bankDomiciliation: bankInfo?.bankDomiciliation ?? '',
      bankAccountHolder: bankInfo?.bankAccountHolder ?? '',
      bankOwnerAddress: bankInfo?.bankOwnerAddress ?? '',
      bankOwnerPostalCode: bankInfo?.bankOwnerPostalCode ?? '',
      bankOwnerCity: bankInfo?.bankOwnerCity ?? '',
    );

    final lines = info.addressLines;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.apartment, color: Color(0xFF4B5563)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Émetteur', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...lines.map((line) => Text(line)),
                  if (info.siret.isNotEmpty) Text('Siret : ${info.siret}'),
                  if (info.phone.isNotEmpty) Text('Tél. : ${info.phone}'),
                  if (info.email.isNotEmpty) Text('Email : ${info.email}'),
                  if (info.website.isNotEmpty) Text('Web : ${info.website}'),
                  if (info.hasBankDetails) ...[
                    const SizedBox(height: 10),
                    Text('Coordonnées bancaires', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    if (info.bankLabel.trim().isNotEmpty) Text('Compte : ${info.bankLabel.trim()}'),
                    if (info.bankName.trim().isNotEmpty) Text('Banque : ${info.bankName.trim()}'),
                    if (info.bankAccountHolder.trim().isNotEmpty) Text('Titulaire : ${info.bankAccountHolder.trim()}'),
                    if (info.bankIban.trim().isNotEmpty) Text('IBAN : ${info.bankIban.trim()}'),
                    if (info.bankBic.trim().isNotEmpty) Text('BIC : ${info.bankBic.trim()}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
