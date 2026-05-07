import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/app_config.dart';
import '../core/models/invoice_line.dart';

class BillingService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static String translatePaymentTermLabel(String value) {
    return ClientPaymentTerm.translateLabel(value);
  }

  static Future<ClientInvoiceListResult> getClientInvoices({
    int page = 1,
    int pageSize = 50,
    String? clientName,
    String? status,
    String? invoiceNumber,
    String? missionRef,
    String? search,
  }) async {
    final payload = <String, dynamic>{'page': page, 'pageSize': pageSize};
    void addIfNotEmpty(String key, String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      payload[key] = trimmed;
    }

    addIfNotEmpty('client', clientName);
    addIfNotEmpty('status', status);
    addIfNotEmpty('invoice_number', invoiceNumber);
    addIfNotEmpty('mission_ref', missionRef);
    addIfNotEmpty('search', search);

    final response = await http.post(
      Uri.parse("${_baseUrl}get_client_invoices.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de récupérer les factures clients (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final invoicesJson = decoded['invoices'] as List? ?? const [];
      final invoices = invoicesJson
          .whereType<Map>()
          .map(
            (row) =>
                ClientInvoiceSummary.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
      final total = decoded['total'] is num
          ? (decoded['total'] as num).toInt()
          : invoices.length;
      final currentPage = decoded['page'] is num
          ? (decoded['page'] as num).toInt()
          : page;
      final currentPageSize = decoded['pageSize'] is num
          ? (decoded['pageSize'] as num).toInt()
          : pageSize;
      return ClientInvoiceListResult(
        page: currentPage,
        pageSize: currentPageSize,
        total: total,
        invoices: invoices,
      );
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static Future<String> reserveNextInvoiceNumber({
    int? year,
    int? month,
  }) async {
    final params = <String, String>{};
    if (year != null) params['year'] = year.toString();
    if (month != null) params['month'] = month.toString();
    final uri = Uri.parse(
      "${_baseUrl}reserve_client_invoice_number.php",
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de proposer un numéro de facture (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map &&
        decoded['success'] == true &&
        decoded['invoice_number'] is String) {
      return decoded['invoice_number'] as String;
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static Future<void> logClientBilling({
    required String clientName,
    required String invoiceNumber,
    required String statusCode,
    required String statusLabel,
    required DateTime billedAt,
    required double amountTotal,
    required List<Map<String, dynamic>> missions,
    required List<InvoiceLine> invoiceLines,
    required int userId,
    required String userName,
    Uint8List? pdfBytes,
    String? pdfFilename,
    DateTime? periodMonth,
    String? draftKey,
    String? notes,
  }) async {
    final payload = {
      'client_name': clientName,
      'invoice_number': invoiceNumber,
      'status': statusCode,
      'status_label': statusLabel,
      'billed_at': billedAt.toIso8601String(),
      'amount_total': amountTotal,
      'missions': missions,
      'invoice_lines': invoiceLines.map((line) => line.toJson()).toList(),
      'user_id': userId,
      'user_name': userName,
      if (periodMonth != null)
        'period_month': DateTime(
          periodMonth.year,
          periodMonth.month,
        ).toIso8601String(),
      if (pdfFilename != null && pdfFilename.trim().isNotEmpty)
        'pdf_filename': pdfFilename.trim(),
      if (pdfBytes != null) 'pdf_base64': base64Encode(pdfBytes),
      if (draftKey != null && draftKey.isNotEmpty) 'draft_key': draftKey,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final response = await http.post(
      Uri.parse("${_baseUrl}log_client_billing.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode != 200) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Échec de l\'enregistrement de la facturation client (${response.statusCode}).';
      throw Exception(message);
    }
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Réponse inattendue du serveur.';
      throw Exception(message);
    }
  }

  static Future<void> updateInvoiceStatus({
    required String invoiceNumber,
    required String statusCode,
    required String statusLabel,
    int? userId,
    String? userName,
  }) async {
    final payload = <String, dynamic>{
      'invoice_number': invoiceNumber.trim(),
      'status_code': statusCode,
      'status_label': statusLabel,
    };
    if (userId != null) {
      payload['user_id'] = userId;
    }
    if (userName != null && userName.trim().isNotEmpty) {
      payload['user_name'] = userName.trim();
    }

    final response = await http.post(
      Uri.parse("${_baseUrl}update_client_invoice_status.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Impossible de mettre à jour le statut de la facture (${response.statusCode}).",
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Réponse inattendue du serveur.';
      throw Exception(message);
    }
  }

  static Future<Map<String, String>> updateInvoiceBankAccount({
    required String invoiceNumber,
    required int bankAccountId,
  }) async {
    final payload = <String, dynamic>{
      'invoice_number': invoiceNumber.trim(),
      'bank_account_id': bankAccountId,
    };

    final response = await http.post(
      Uri.parse("${_baseUrl}update_invoice_bank_account.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Impossible de mettre à jour le compte bancaire (${response.statusCode}).",
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Réponse inattendue du serveur.';
      throw Exception(message);
    }
    return {
      'notes': (decoded['notes'] as String? ?? ''),
      'bank_label': (decoded['bank_label'] as String? ?? ''),
    };
  }

  static Future<Map<String, String>> updateInvoicePaymentTerm({
    required String invoiceNumber,
    required String termLabel,
  }) async {
    final payload = <String, dynamic>{
      'invoice_number': invoiceNumber.trim(),
      'term_label': termLabel.trim(),
    };

    final response = await http.post(
      Uri.parse("${_baseUrl}update_invoice_payment_term.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Impossible de mettre à jour la condition de règlement (${response.statusCode}).",
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Réponse inattendue du serveur.';
      throw Exception(message);
    }
    return {
      'notes': (decoded['notes'] as String? ?? ''),
      'term_label': (decoded['term_label'] as String? ?? ''),
    };
  }

  static Future<DateTime> updateInvoiceDate({
    required String invoiceNumber,
    required DateTime newDate,
  }) async {
    final payload = <String, dynamic>{
      'invoice_number': invoiceNumber.trim(),
      'new_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(newDate),
    };

    final response = await http.post(
      Uri.parse("${_baseUrl}update_invoice_date.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Impossible de mettre à jour la date (${response.statusCode}).",
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Réponse inattendue du serveur.';
      throw Exception(message);
    }
    return newDate;
  }

  static Future<ClientPaymentTermsResult> getAllPaymentTerms() async {
    final uri = Uri.parse('${_baseUrl}get_client_payment_terms.php');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les conditions de règlement (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawTerms = decoded['paymentTerms'] as List? ?? const [];
      final terms = rawTerms
          .whereType<Map>()
          .map(
            (row) => ClientPaymentTerm.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((term) => term.id > 0)
          .toList(growable: false);
      return ClientPaymentTermsResult(paymentTerms: terms, defaultTermId: null);
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static Future<ClientInvoiceLinesResult> fetchInvoiceLines(
    String invoiceNumber, {
    String? missionRef,
  }) async {
    final payload = {
      'invoice_number': invoiceNumber.trim(),
      if (missionRef != null && missionRef.trim().isNotEmpty)
        'mission_ref': missionRef.trim(),
    };
    final response = await http.post(
      Uri.parse("${_baseUrl}get_client_invoice_lines.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de recuperer les lignes (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawLines = decoded['lines'] as List? ?? const [];
      final lines = rawLines
          .whereType<Map>()
          .map((line) => InvoiceLine.fromJson(Map<String, dynamic>.from(line)))
          .toList();
      final totalHt = decoded['total_ht'] is num
          ? (decoded['total_ht'] as num).toDouble()
          : null;
      return ClientInvoiceLinesResult(
        invoiceNumber: invoiceNumber,
        missionRef: missionRef,
        totalHt: totalHt,
        lines: lines,
      );
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Reponse inattendue du serveur.';
    throw Exception(message);
  }

  static Future<ClientInvoiceLinesResult> updateInvoiceLines({
    required String invoiceNumber,
    required String missionRef,
    required List<InvoiceLine> lines,
    int? userId,
    String? userName,
  }) async {
    final payload = {
      'invoice_number': invoiceNumber.trim(),
      'mission_ref': missionRef.trim(),
      'lines': lines
          .asMap()
          .entries
          .map((entry) => {...entry.value.toJson(), 'sort_order': entry.key})
          .toList(),
      if (userId != null && userId > 0) 'user_id': userId,
      if (userName != null && userName.trim().isNotEmpty)
        'user_name': userName.trim(),
    };

    final response = await http.post(
      Uri.parse('${_baseUrl}update_client_invoice_lines.php'),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de mettre à jour les lignes (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawLines = decoded['lines'] as List? ?? const [];
      final updatedLines = rawLines
          .whereType<Map>()
          .map((line) => InvoiceLine.fromJson(Map<String, dynamic>.from(line)))
          .toList();
      final totalHt = decoded['total_ht'] is num
          ? (decoded['total_ht'] as num).toDouble()
          : null;
      return ClientInvoiceLinesResult(
        invoiceNumber: invoiceNumber,
        missionRef: missionRef,
        totalHt: totalHt,
        lines: updatedLines,
      );
    }

    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static Future<ClientPaymentTermsResult> getClientPaymentTerms({
    required int clientId,
  }) async {
    final uri = Uri.parse(
      '${_baseUrl}get_client_payment_terms.php',
    ).replace(queryParameters: {'client_id': clientId.toString()});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les conditions de règlement (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawTerms = decoded['paymentTerms'] as List? ?? const [];
      final terms = rawTerms
          .whereType<Map>()
          .map(
            (row) => ClientPaymentTerm.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((term) => term.id > 0)
          .toList(growable: false);
      final defaultTermId = decoded['defaultTermId'] is num
          ? (decoded['defaultTermId'] as num).toInt()
          : int.tryParse((decoded['defaultTermId'] ?? '').toString());
      return ClientPaymentTermsResult(
        paymentTerms: terms,
        defaultTermId: defaultTermId,
      );
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static String buildDraftKey(String clientName, DateTime periodMonth) {
    final normalized = clientName.trim().toLowerCase();
    final monthKey = _periodMonthKey(periodMonth);
    final hash = sha1
        .convert(utf8.encode('$normalized|$monthKey'))
        .toString()
        .substring(0, 16);
    return '${monthKey}_$hash';
  }

  static Future<String> saveInvoiceDraftLines({
    required String clientName,
    required DateTime periodMonth,
    required List<InvoiceLine> lines,
    int? userId,
    String? userName,
    String? draftKey,
    int? draftId,
  }) async {
    if (lines.isEmpty) {
      throw Exception('Aucune ligne à enregistrer.');
    }
    final effectiveDraftKey = (draftKey != null && draftKey.isNotEmpty)
        ? draftKey
        : buildDraftKey(clientName, periodMonth);
    final payload = {
      'client_name': clientName,
      'period_month': _periodMonthKey(periodMonth),
      'draft_key': effectiveDraftKey,
      'lines': lines.map((line) => line.toJson()).toList(),
      if (userId != null && userId > 0) 'user_id': userId,
      if (userName != null && userName.trim().isNotEmpty)
        'user_name': userName.trim(),
      if (draftId != null && draftId > 0) 'draft_id': draftId,
    };

    final response = await http.post(
      Uri.parse('${_baseUrl}save_invoice_draft_lines.php'),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible d\'enregistrer le brouillon (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      return effectiveDraftKey;
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static Future<List<InvoiceLine>> fetchInvoiceDraftLines({
    required String clientName,
    required DateTime periodMonth,
    String? draftKey,
  }) async {
    final payload = {
      'client_name': clientName,
      'period_month': _periodMonthKey(periodMonth),
      if (draftKey != null && draftKey.isNotEmpty) 'draft_key': draftKey,
    };

    final response = await http.post(
      Uri.parse('${_baseUrl}get_invoice_draft_lines.php'),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de récupérer le brouillon (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawLines = decoded['lines'] as List? ?? const [];
      return rawLines
          .whereType<Map>()
          .map((line) => InvoiceLine.fromJson(Map<String, dynamic>.from(line)))
          .toList();
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  static String _periodMonthKey(DateTime date) {
    final month = DateTime(date.year, date.month);
    return _periodFormatter.format(month);
  }

  static final DateFormat _periodFormatter = DateFormat('yyyy-MM-01');

  // ---------------------------------------------------------------
  // AMI v1.3 — Draft de préparation
  // ---------------------------------------------------------------

  /// Crée ou met à jour un draft de préparation.
  /// Retourne le draft_id persisté.
  static Future<int> saveInvoiceDraft({
    int? draftId,
    int? clientId,
    required String clientName,
    required DateTime periodMonth,
    int? paymentConditionId,
    int? bankAccountId,
    double totalHt = 0.0,
    int? userId,
  }) async {
    final payload = <String, dynamic>{
      'month': DateFormat('yyyy-MM').format(periodMonth),
      'client_name': clientName.trim(),
      'total_ht': totalHt,
      if (draftId != null && draftId > 0) 'draft_id': draftId,
      if (clientId != null && clientId > 0) 'client_id': clientId,
      'payment_condition_id': ?paymentConditionId,
      'bank_account_id': ?bankAccountId,
      if (userId != null && userId > 0) 'user_id': userId,
    };
    final response = await http.post(
      Uri.parse('${_baseUrl}save_invoice_draft.php'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de sauvegarder la préparation (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true && decoded['draft_id'] is num) {
      return (decoded['draft_id'] as num).toInt();
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  /// Retourne la liste des préparations en cours (status='draft' par défaut).
  static Future<List<InvoiceDraftSummary>> getInvoiceDrafts({
    int? clientId,
    String? clientName,
    String? month,
    String status = 'draft',
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (clientId != null && clientId > 0) payload['client_id'] = clientId;
    if (clientName != null && clientName.trim().isNotEmpty) {
      payload['client_name'] = clientName.trim();
    }
    if (month != null && month.trim().isNotEmpty) payload['month'] = month.trim();

    final response = await http.post(
      Uri.parse('${_baseUrl}get_invoice_drafts.php'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les préparations (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final raw = decoded['drafts'] as List? ?? const [];
      return raw
          .whereType<Map>()
          .map((d) => InvoiceDraftSummary.fromJson(Map<String, dynamic>.from(d)))
          .toList();
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }

  /// Supprime un draft non finalisé.
  static Future<void> deleteInvoiceDraft({required int draftId}) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}delete_invoice_draft.php'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'draft_id': draftId}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de supprimer la préparation (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) return;
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Réponse inattendue du serveur.';
    throw Exception(message);
  }
}

// ---------------------------------------------------------------------------
// AMI v1.3 — Modèles draft
// ---------------------------------------------------------------------------

/// Résumé d'une préparation de facture (header).
class InvoiceDraftSummary {
  const InvoiceDraftSummary({
    required this.draftId,
    this.clientId,
    this.clientName,
    required this.month,
    this.paymentConditionId,
    this.bankAccountId,
    required this.totalHt,
    this.createdBy,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final int draftId;
  final int? clientId;
  final String? clientName;
  final String month;
  final int? paymentConditionId;
  final int? bankAccountId;
  final double totalHt;
  final int? createdBy;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  bool get isFinalized => status == 'finalized';

  factory InvoiceDraftSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceDraftSummary(
      draftId: (json['draft_id'] as num).toInt(),
      clientId: json['client_id'] is num ? (json['client_id'] as num).toInt() : null,
      clientName: json['client_name'] as String?,
      month: (json['month'] as String? ?? ''),
      paymentConditionId: json['payment_condition_id'] is num
          ? (json['payment_condition_id'] as num).toInt()
          : null,
      bankAccountId: json['bank_account_id'] is num
          ? (json['bank_account_id'] as num).toInt()
          : null,
      totalHt: json['total_ht'] is num ? (json['total_ht'] as num).toDouble() : 0.0,
      createdBy: json['created_by'] is num ? (json['created_by'] as num).toInt() : null,
      status: (json['status'] as String? ?? 'draft'),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class ClientInvoiceListResult {
  ClientInvoiceListResult({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.invoices,
  });

  final int page;
  final int pageSize;
  final int total;
  final List<ClientInvoiceSummary> invoices;
}

class ClientInvoiceSummary {
  ClientInvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.statusCode,
    required this.statusLabel,
    required this.amountHt,
    required this.invoiceTotalHt,
    required this.billedAt,
    this.periodMonth,
    this.missionRef,
    this.pdfFilename,
    this.pdfPath,
    this.pdfSize,
    this.createdBy,
    this.createdByName,
    this.category,
    this.notes,
    this.missionLabel,
    this.createdAt,
    this.updatedAt,
  });

  ClientInvoiceSummary copyWith({
    String? statusCode,
    String? statusLabel,
    double? invoiceTotalHt,
    double? amountHt,
    String? notes,
    DateTime? createdAt,
    DateTime? billedAt,
  }) {
    return ClientInvoiceSummary(
      id: id,
      invoiceNumber: invoiceNumber,
      clientName: clientName,
      statusCode: statusCode ?? this.statusCode,
      statusLabel: statusLabel ?? this.statusLabel,
      amountHt: amountHt ?? this.amountHt,
      invoiceTotalHt: invoiceTotalHt ?? this.invoiceTotalHt,
      billedAt: billedAt ?? this.billedAt,
      periodMonth: periodMonth,
      missionRef: missionRef,
      pdfFilename: pdfFilename,
      pdfPath: pdfPath,
      pdfSize: pdfSize,
      createdBy: createdBy,
      createdByName: createdByName,
      category: category,
      notes: notes ?? this.notes,
      missionLabel: missionLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ClientInvoiceSummary.fromJson(Map<String, dynamic> json) {
    DateTime? billedAt;
    DateTime? createdAt;
    DateTime? updatedAt;
    DateTime? periodMonth;
    final billedRaw = json['billed_at'];
    if (billedRaw is String && billedRaw.trim().isNotEmpty) {
      billedAt = DateTime.tryParse(billedRaw.trim());
    }
    final periodRaw = json['period_month'];
    if (periodRaw is String && periodRaw.trim().isNotEmpty) {
      periodMonth = DateTime.tryParse(periodRaw.trim());
    }
    final createdRaw = json['created_at'];
    if (createdRaw is String && createdRaw.trim().isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw.trim());
    }
    final updatedRaw = json['updated_at'];
    if (updatedRaw is String && updatedRaw.trim().isNotEmpty) {
      updatedAt = DateTime.tryParse(updatedRaw.trim());
    }
    return ClientInvoiceSummary(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      clientName: (json['client_name'] ?? '').toString(),
      statusCode: (json['status_code'] ?? '').toString(),
      statusLabel: (json['status_label'] ?? '').toString(),
      missionRef: json['mission_ref']?.toString(),
      amountHt: _parseDecimal(json['amount_ht']),
      invoiceTotalHt: _parseDecimal(json['invoice_total_ht']),
      billedAt: billedAt,
      periodMonth: periodMonth,
      pdfFilename: json['pdf_filename']?.toString(),
      pdfPath: json['pdf_path']?.toString(),
      pdfSize: json['pdf_size'] is num
          ? (json['pdf_size'] as num).toInt()
          : int.tryParse((json['pdf_size'] ?? '').toString()),
      createdBy: json['created_by'] is num
          ? (json['created_by'] as num).toInt()
          : null,
      createdByName: json['created_by_name']?.toString(),
      category: json['category']?.toString(),
      notes: json['notes']?.toString(),
      missionLabel: json['mission_label']?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final int id;
  final String invoiceNumber;
  final String clientName;
  final String statusCode;
  final String statusLabel;
  final double amountHt;
  final double invoiceTotalHt;
  final DateTime? billedAt;
  final DateTime? periodMonth;
  final String? missionRef;
  final String? missionLabel;
  final String? pdfFilename;
  final String? pdfPath;
  final int? pdfSize;
  final int? createdBy;
  final String? createdByName;
  final String? category;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static double _parseDecimal(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final normalized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }
}

class ClientInvoiceLinesResult {
  ClientInvoiceLinesResult({
    required this.invoiceNumber,
    required this.lines,
    this.missionRef,
    this.totalHt,
  });

  final String invoiceNumber;
  final String? missionRef;
  final List<InvoiceLine> lines;
  final double? totalHt;
}

class ClientPaymentTermsResult {
  ClientPaymentTermsResult({
    required this.paymentTerms,
    required this.defaultTermId,
  });

  final List<ClientPaymentTerm> paymentTerms;
  final int? defaultTermId;
}

class ClientPaymentTerm {
  ClientPaymentTerm({
    required this.id,
    required this.code,
    required this.label,
    required this.days,
    required this.shift,
    required this.isDefault,
  });

  factory ClientPaymentTerm.fromJson(Map<String, dynamic> json) {
    return ClientPaymentTerm(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      days: json['days'] is num ? (json['days'] as num).toInt() : 0,
      shift: json['shift'] is num ? (json['shift'] as num).toInt() : 0,
      isDefault:
          json['isDefault'] == true ||
          (json['isDefault'] ?? '').toString() == '1',
    );
  }

  final int id;
  final String code;
  final String label;
  final int days;
  final int shift;
  final bool isDefault;

  String get displayLabel {
    final translatedLabel = _translatePaymentTerm(label);
    if (translatedLabel.isNotEmpty) {
      return translatedLabel;
    }
    return _translatePaymentTerm(code);
  }

  String get dropdownLabel {
    final trimmedLabel = displayLabel.trim();
    final trimmedCode = code.trim();
    if (trimmedLabel.isEmpty) {
      final translatedCode = _translatePaymentTerm(trimmedCode);
      return translatedCode.isEmpty ? 'Condition $id' : translatedCode;
    }
    if (trimmedCode.isEmpty) {
      return trimmedLabel;
    }
    return '$trimmedLabel ($trimmedCode)';
  }

  static String translateLabel(String value) {
    return _translatePaymentTerm(value);
  }

  static String _translatePaymentTerm(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final suffixMatch = RegExp(r'\s*\(([A-Z0-9_]+)\)\s*$').firstMatch(trimmed);
    final suffix = suffixMatch?.group(1);
    final baseValue = suffixMatch == null
        ? trimmed
        : trimmed.substring(0, suffixMatch.start).trim();

    final normalized = baseValue.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const directMap = <String, String>{
      'immediate payment': 'Paiement immédiat',
      'payment in advance': 'Paiement d\'avance',
      'advance payment': 'Paiement d\'avance',
      'cash on delivery': 'Paiement à la livraison',
      'due on delivery': 'Paiement à la livraison',
      'delivery': 'Paiement à la livraison',
      'payable on receipt': 'Paiement à réception',
      'upon receipt': 'Paiement à réception',
      'on receipt': 'Paiement à réception',
      'receipt': 'Paiement à réception',
      'due on receipt': 'Paiement à réception',
      'due upon receipt': 'Paiement à réception',
      'due on order': 'Paiement à la commande',
      'on order': 'Paiement à la commande',
      'order': 'Paiement à la commande',
      '50% on order, 50% on delivery':
          '50 % à la commande, 50 % à la livraison',
      '50% on order 50% on delivery': '50 % à la commande, 50 % à la livraison',
      '50% à la commande, 50% à la livraison':
          '50 % à la commande, 50 % à la livraison',
      'pt_delivery': 'Paiement à la livraison',
      'pt_order': 'Paiement à la commande',
      'pt_5050': '50 % à la commande, 50 % à la livraison',
      'recep': 'Paiement à réception',
      'comptant': 'Comptant',
    };
    final direct = directMap[normalized];
    if (direct != null) {
      return suffix == null ? direct : '$direct ($suffix)';
    }

    final endOfMonthMatch = RegExp(
      r'^(?:net\s*)?(\d+)\s*(?:day|days|jours?)\s*(?:end of month|eom|fin de mois)$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (endOfMonthMatch != null) {
      final translated = '${endOfMonthMatch.group(1)} jours fin de mois';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    final dueEndOfMonthMatch = RegExp(
      r'^due in\s*(\d+)\s*days?,?\s*end of month$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (dueEndOfMonthMatch != null) {
      final translated = '${dueEndOfMonthMatch.group(1)} jours fin de mois';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    final netMatch = RegExp(
      r'^(?:net\s*)?(\d+)\s*(?:day|days|jours?)\s*(?:net)?$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (netMatch != null) {
      final translated = '${netMatch.group(1)} jours';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    final dueInDaysMatch = RegExp(
      r'^due in\s*(\d+)\s*days?$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (dueInDaysMatch != null) {
      final translated = '${dueInDaysMatch.group(1)} jours';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    final simpleDaysMatch = RegExp(
      r'^(\d+)\s*(?:day|days)$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (simpleDaysMatch != null) {
      final translated = '${simpleDaysMatch.group(1)} jours';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    final compactEndOfMonthCode = RegExp(
      r'^(\d+)d(?:endmonth|endofmonth)$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (compactEndOfMonthCode != null) {
      final translated = '${compactEndOfMonthCode.group(1)} jours fin de mois';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    final compactDaysCode = RegExp(
      r'^(\d+)d$',
      caseSensitive: false,
    ).firstMatch(baseValue);
    if (compactDaysCode != null) {
      final translated = '${compactDaysCode.group(1)} jours';
      return suffix == null ? translated : '$translated ($suffix)';
    }

    return trimmed;
  }
}
