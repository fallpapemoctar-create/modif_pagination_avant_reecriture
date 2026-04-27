// ignore_for_file: use_build_context_synchronously
// lib/pages/quote_edit_page.dart
// AMI v1.4 — Module Devis

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/auth_manager.dart';
import '../core/app_text_styles.dart';
import '../core/models/quote.dart';
import '../services/quote_service.dart';
import '../utils/pdf_download_helper_stub.dart'
    if (dart.library.html) '../utils/pdf_download_helper_web.dart';

/// Page d'édition / visualisation d'un devis.
/// Utilisée aussi bien depuis MissionsTablePage (création) que depuis
/// l'onglet Devis dans BillingPage (liste).
class QuoteEditPage extends StatefulWidget {
  /// Devis à éditer. Peut être null si [missionId] est fourni (création).
  final Quote? initialQuote;

  /// ID de la mission pour créer un devis automatiquement.
  final int? missionId;

  const QuoteEditPage({super.key, this.initialQuote, this.missionId})
      : assert(initialQuote != null || missionId != null,
            'initialQuote ou missionId est requis');

  @override
  State<QuoteEditPage> createState() => _QuoteEditPageState();
}

class _QuoteEditPageState extends State<QuoteEditPage> {
  static final _currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  Quote? _quote;
  bool _loading = true;
  bool _saving = false;
  bool _generatingPdf = false;
  String? _error;

  late TextEditingController _notesCtrl;
  late TextEditingController _validUntilCtrl;

  // Éditeurs de lignes
  final List<_LineEditor> _lineEditors = [];

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _validUntilCtrl = TextEditingController();
    _init();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _validUntilCtrl.dispose();
    for (final e in _lineEditors) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      Quote quote;
      if (widget.initialQuote != null) {
        quote = widget.initialQuote!;
        if (quote.lines.isEmpty) {
          quote = await QuoteService.getQuote(quote.id);
        }
      } else {
        quote = await QuoteService.createFromMission(
          missionId: widget.missionId!,
          userId: AuthManager.userId,
        );
      }
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
        _notesCtrl.text = quote.notes ?? '';
        _validUntilCtrl.text = quote.dateValidUntil ?? '';
        _rebuildLineEditors(quote.lines);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _rebuildLineEditors(List<QuoteLine> lines) {
    for (final e in _lineEditors) {
      e.dispose();
    }
    _lineEditors
      ..clear()
      ..addAll(lines.map((l) => _LineEditor.from(l)));
  }

  List<QuoteLine> _collectLines() {
    return _lineEditors.asMap().entries.map((entry) {
      final e = entry.value;
      final line = e.source.copy();
      line.designation = e.designationCtrl.text.trim();
      line.unitPrice = double.tryParse(e.unitPriceCtrl.text.trim()) ?? line.unitPrice;
      line.quantity = double.tryParse(e.quantityCtrl.text.trim()) ?? line.quantity;
      line.tvaRate = double.tryParse(e.tvaCtrl.text.trim()) ?? line.tvaRate;
      line.discount = double.tryParse(e.discountCtrl.text.trim()) ?? line.discount;
      line.notes = e.notesCtrl.text.trim().isEmpty ? null : e.notesCtrl.text.trim();
      line.sortOrder = entry.key;
      return line;
    }).toList();
  }

  Future<void> _save() async {
    final quote = _quote;
    if (quote == null || !quote.isEditable) return;
    setState(() => _saving = true);
    try {
      final updated = await QuoteService.updateQuote(
        quoteId: quote.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        dateValidUntil: _validUntilCtrl.text.trim().isEmpty
            ? null
            : _validUntilCtrl.text.trim(),
        lines: _collectLines(),
      );
      if (!mounted) return;
      setState(() {
        _quote = updated;
        _saving = false;
        _rebuildLineEditors(updated.lines);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devis sauvegardé')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    final quote = _quote;
    if (quote == null) return;
    setState(() => _saving = true);
    try {
      final updated = await QuoteService.updateQuote(
        quoteId: quote.id,
        status: newStatus,
      );
      if (!mounted) return;
      setState(() {
        _quote = updated;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _convertToInvoice() async {
    final quote = _quote;
    if (quote == null || !quote.canConvert) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convertir en facture ?'),
        content: Text(
          'Le devis #${quote.id} (${quote.clientName ?? ''}) sera converti en facture. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convertir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      final result = await QuoteService.convertToInvoice(
        quoteId: quote.id,
        userId: AuthManager.userId,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Facture créée : ${result.invoiceNumber}'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      Navigator.of(context).pop(true); // signal de retour : converti
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // ---- Générer PDF (§5.4, §7.2) ----
  Future<void> _generatePdf() async {
    final quote = _quote;
    if (quote == null) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildQuotePdfBytes(quote);
      if (!mounted) return;
      if (canSavePdfToDownloads) {
        await savePdfToDownloads(
            bytes, 'devis_${quote.id}_${quote.clientName ?? 'client'}.pdf');
      } else {
        await Printing.layoutPdf(
          name: 'devis_${quote.id}.pdf',
          onLayout: (_) async => bytes,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<Uint8List> _buildQuotePdfBytes(Quote quote) async {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final lines = quote.lines.isEmpty ? _collectLines() : quote.lines;
    double totalHt = 0;
    double totalTtc = 0;
    for (final l in lines) {
      totalHt += l.totalHt;
      totalTtc += l.totalTtc;
    }
    final doc = pw.Document();
    final accent = PdfColor.fromHex('#000091');
    final grey = PdfColor.fromHex('#6B7280');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DEVIS',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: accent)),
                  pw.SizedBox(height: 4),
                  pw.Text('#${quote.id}  •  ${Quote.statusLabel(quote.status)}',
                      style: pw.TextStyle(fontSize: 12, color: grey)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date : $today',
                    style: pw.TextStyle(fontSize: 11)),
                if (quote.dateValidUntil != null)
                  pw.Text('Valable : ${quote.dateValidUntil}',
                      style: pw.TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        if (quote.clientName != null)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Client',
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: grey,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(quote.clientName!,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (quote.missionRef != null)
                  pw.Text('Mission : ${quote.missionRef}',
                      style:
                          pw.TextStyle(fontSize: 10, color: grey)),
              ],
            ),
          ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white),
          headerDecoration:
              pw.BoxDecoration(color: accent),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
          headers: [
            'Désignation',
            'TVA %',
            'P.U. HT',
            'Qté',
            'Total HT'
          ],
          data: lines
              .map((l) => [
                    l.designation,
                    '${l.tvaRate.toStringAsFixed(1)} %',
                    fmt.format(l.unitPrice),
                    l.quantity.toStringAsFixed(2),
                    fmt.format(l.totalHt),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Total HT : ${fmt.format(totalHt)}',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('Total TTC : ${fmt.format(totalTtc)}',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: accent)),
            ],
          ),
        ),
        if (quote.notes != null && quote.notes!.isNotEmpty) ...
          [
            pw.SizedBox(height: 16),
            pw.Text('Notes',
                style: pw.TextStyle(
                    fontSize: 10,
                    color: grey,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(quote.notes!,
                style: const pw.TextStyle(fontSize: 10)),
          ],
      ],
    ));
    return doc.save();
  }

  // ---- Dupliquer un devis rejeté/expiré (RM-06) ----
  Future<void> _duplicateQuote() async {
    final quote = _quote;
    if (quote == null) return;
    setState(() => _saving = true);
    try {
      // Crée un nouveau devis depuis la même mission
      final newQuote = await QuoteService.createFromMission(
        missionId: quote.missionId ?? 0,
        userId: AuthManager.userId,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      // Ouvre le nouveau devis dans la même page
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuoteEditPage(initialQuote: newQuote),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  void _addLine() {
    setState(() {
      _lineEditors.add(_LineEditor.empty());
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lineEditors[index].dispose();
      _lineEditors.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          quote == null ? 'Devis' : 'Devis #${quote.id}',
          style: AppTextStyles.sectionTitle,
        ),
        actions: [
          if (quote != null && quote.isEditable)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Sauvegarder'),
            ),
          if (quote != null)
            TextButton.icon(
              onPressed: _generatingPdf ? null : _generatePdf,
              icon: _generatingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          if (quote != null) ..._buildStatusActions(quote),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(quote),
    );
  }

  List<Widget> _buildStatusActions(Quote quote) {
    return [
      // Bouton Envoyer direct (§7.2) — visible si draft
      if (quote.status == 'draft')
        TextButton.icon(
          onPressed: _saving ? null : () => _changeStatus('sent'),
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('Envoyer'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1D4ED8),
          ),
        ),
      // Menu déroulant avec les autres transitions
      if (quote.status == 'draft')
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Autres actions',
          onSelected: (v) {
            if (v == 'accept') _changeStatus('accepted');
            if (v == 'reject') _changeStatus('rejected');
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'accept', child: Text('Marquer Accepté')),
            PopupMenuItem(value: 'reject', child: Text('Marquer Rejeté')),
          ],
        ),
      if (quote.status == 'sent')
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Actions',
          onSelected: (v) {
            if (v == 'accept') _changeStatus('accepted');
            if (v == 'reject') _changeStatus('rejected');
            if (v == 'expire') _changeStatus('expired');
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'accept', child: Text('Marquer Accepté')),
            PopupMenuItem(value: 'reject', child: Text('Marquer Rejeté')),
            PopupMenuItem(value: 'expire', child: Text('Marquer Expiré')),
          ],
        ),
      // Convertir en facture (RM-05, §6.3)
      if (quote.canConvert)
        FilledButton.icon(
          onPressed: _saving ? null : _convertToInvoice,
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Créer la facture'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
          ),
        ),
      // Dupliquer (RM-06)
      if (quote.status == 'rejected' || quote.status == 'expired')
        if (quote.missionId != null)
          TextButton.icon(
            onPressed: _saving ? null : _duplicateQuote,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Dupliquer'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
            ),
          ),
    ];
  }

  Widget _buildBody(Quote? quote) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFB91C1C), size: 32),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFB91C1C))),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _init,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (quote == null) {
      return const Center(child: Text('Devis non trouvé.'));
    }
    return _buildForm(quote);
  }

  Widget _buildForm(Quote quote) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- En-tête du devis -----
          _QuoteHeader(quote: quote),
          const SizedBox(height: 24),

          // ---- Informations générales ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _validUntilCtrl,
                          enabled: quote.isEditable,
                          decoration: const InputDecoration(
                            labelText: 'Valable jusqu\'au (YYYY-MM-DD)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    enabled: quote.isEditable,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ---- Lignes ----
          Row(
            children: [
              Text('Lignes du devis', style: AppTextStyles.sectionTitle),
              const Spacer(),
              if (quote.isEditable)
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter une ligne'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._lineEditors.asMap().entries.map((entry) => _buildLineRow(
              entry.key, entry.value, quote.isEditable)),
          const SizedBox(height: 16),

          // ---- Totaux ----
          Align(
            alignment: Alignment.centerRight,
            child: _buildTotals(quote),
          ),
        ],
      ),
    );
  }

  Widget _buildLineRow(int index, _LineEditor e, bool editable) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: e.designationCtrl,
                    enabled: editable,
                    decoration: const InputDecoration(
                      labelText: 'Désignation',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: AppTextStyles.tableCell,
                  ),
                ),
                const SizedBox(width: 8),
                _NumField(
                  label: 'P.U. HT',
                  ctrl: e.unitPriceCtrl,
                  enabled: editable,
                  flex: 2,
                ),
                const SizedBox(width: 8),
                _NumField(
                  label: 'Qté',
                  ctrl: e.quantityCtrl,
                  enabled: editable,
                  flex: 1,
                ),
                const SizedBox(width: 8),
                _NumField(
                  label: 'TVA %',
                  ctrl: e.tvaCtrl,
                  enabled: editable,
                  flex: 1,
                ),
                const SizedBox(width: 8),
                _NumField(
                  label: 'Réduc. %',
                  ctrl: e.discountCtrl,
                  enabled: editable,
                  flex: 1,
                ),
                if (editable) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFB91C1C), size: 20),
                    onPressed: () => _removeLine(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(Quote quote) {
    final lines = _collectLines();
    double totalHt = 0;
    double totalTtc = 0;
    for (final l in lines) {
      totalHt += l.totalHt;
      totalTtc += l.totalTtc;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF000091), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Total HT : ${_currencyFmt.format(totalHt)}',
            style: AppTextStyles.totalMain,
          ),
          const SizedBox(height: 4),
          Text(
            'Total TTC : ${_currencyFmt.format(totalTtc)}',
            style: AppTextStyles.totalTtc,
          ),
        ],
      ),
    );
  }
}

// ---- En-tête du devis ----
class _QuoteHeader extends StatelessWidget {
  final Quote quote;
  const _QuoteHeader({required this.quote});

  @override
  Widget build(BuildContext context) {
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Quote.statusColor(quote.status).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Quote.statusColor(quote.status)),
      ),
      child: Text(
        Quote.statusLabel(quote.status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Quote.statusColor(quote.status),
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Devis #${quote.id}', style: AppTextStyles.pageTitle),
                  const SizedBox(width: 12),
                  statusBadge,
                ],
              ),
              const SizedBox(height: 4),
              if (quote.clientName != null)
                Text(quote.clientName!,
                    style: AppTextStyles.subTitle
                        .copyWith(color: const Color(0xFF374151))),
              if (quote.missionRef != null)
                Text('Mission : ${quote.missionRef}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: const Color(0xFF6B7280))),
              if (quote.dateValidUntil != null)
                Text('Valable jusqu\'au : ${quote.dateValidUntil}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: const Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Widget champ numérique compact ----
class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool enabled;
  final int flex;

  const _NumField({
    required this.label,
    required this.ctrl,
    required this.enabled,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        style: AppTextStyles.tableCell,
      ),
    );
  }
}

// ---- Éditeur d'une ligne ----
class _LineEditor {
  final QuoteLine source;
  final TextEditingController designationCtrl;
  final TextEditingController unitPriceCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController tvaCtrl;
  final TextEditingController discountCtrl;
  final TextEditingController notesCtrl;

  _LineEditor({
    required this.source,
    required this.designationCtrl,
    required this.unitPriceCtrl,
    required this.quantityCtrl,
    required this.tvaCtrl,
    required this.discountCtrl,
    required this.notesCtrl,
  });

  factory _LineEditor.from(QuoteLine line) {
    return _LineEditor(
      source: line.copy(),
      designationCtrl: TextEditingController(text: line.designation),
      unitPriceCtrl:
          TextEditingController(text: line.unitPrice.toStringAsFixed(2)),
      quantityCtrl:
          TextEditingController(text: line.quantity.toStringAsFixed(2)),
      tvaCtrl: TextEditingController(text: line.tvaRate.toStringAsFixed(2)),
      discountCtrl:
          TextEditingController(text: line.discount.toStringAsFixed(2)),
      notesCtrl: TextEditingController(text: line.notes ?? ''),
    );
  }

  factory _LineEditor.empty() {
    final empty = QuoteLine(designation: 'Nouvelle ligne');
    return _LineEditor.from(empty);
  }

  void dispose() {
    designationCtrl.dispose();
    unitPriceCtrl.dispose();
    quantityCtrl.dispose();
    tvaCtrl.dispose();
    discountCtrl.dispose();
    notesCtrl.dispose();
  }
}
