import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/app_config.dart';
import '../core/models/invoice_line.dart';

class BillingService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<ClientInvoiceListResult> getClientInvoices({
    int page = 1,
    int pageSize = 50,
    String? clientName,
    String? status,
    String? invoiceNumber,
    String? missionRef,
    String? search,
  }) async {
    final payload = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
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
      throw Exception('Impossible de récupérer les factures clients (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final invoicesJson = decoded['invoices'] as List? ?? const [];
      final invoices = invoicesJson
          .whereType<Map>()
          .map((row) => ClientInvoiceSummary.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      final total = decoded['total'] is num ? (decoded['total'] as num).toInt() : invoices.length;
      final currentPage = decoded['page'] is num ? (decoded['page'] as num).toInt() : page;
      final currentPageSize = decoded['pageSize'] is num ? (decoded['pageSize'] as num).toInt() : pageSize;
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

  static Future<String> reserveNextInvoiceNumber({int? year, int? month}) async {
    final params = <String, String>{};
    if (year != null) params['year'] = year.toString();
    if (month != null) params['month'] = month.toString();
    final uri = Uri.parse("${_baseUrl}reserve_client_invoice_number.php").replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Impossible de proposer un numéro de facture (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true && decoded['invoice_number'] is String) {
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
    required Uint8List pdfBytes,
    required String pdfFilename,
    required int userId,
    required String userName,
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
      'pdf_filename': pdfFilename,
      'pdf_base64': base64Encode(pdfBytes),
      if (periodMonth != null) 'period_month': DateTime(periodMonth.year, periodMonth.month).toIso8601String(),
      if (draftKey != null && draftKey.isNotEmpty) 'draft_key': draftKey,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final response = await http.post(
      Uri.parse("${_baseUrl}log_client_billing.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Échec de l\'enregistrement de la facturation client (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Réponse inattendue du serveur.';
      throw Exception(message);
    }
  }

  static Future<ClientInvoiceLinesResult> fetchInvoiceLines(String invoiceNumber) async {
    final payload = {'invoice_number': invoiceNumber.trim()};
    final response = await http.post(
      Uri.parse("${_baseUrl}get_client_invoice_lines.php"),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Impossible de recuperer les lignes (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawLines = decoded['lines'] as List? ?? const [];
      final lines = rawLines
          .whereType<Map>()
          .map((line) => InvoiceLine.fromJson(Map<String, dynamic>.from(line)))
          .toList();
      final totalHt = decoded['total_ht'] is num ? (decoded['total_ht'] as num).toDouble() : null;
      return ClientInvoiceLinesResult(
        invoiceNumber: invoiceNumber,
        totalHt: totalHt,
        lines: lines,
      );
    }
    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Reponse inattendue du serveur.';
    throw Exception(message);
  }

  static String buildDraftKey(String clientName, DateTime periodMonth) {
    final normalized = clientName.trim().toLowerCase();
    final monthKey = _periodMonthKey(periodMonth);
    final hash = sha1.convert(utf8.encode('$normalized|$monthKey')).toString().substring(0, 16);
    return '${monthKey}_$hash';
  }

  static Future<String> saveInvoiceDraftLines({
    required String clientName,
    required DateTime periodMonth,
    required List<InvoiceLine> lines,
    int? userId,
    String? userName,
    String? draftKey,
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
      if (userName != null && userName.trim().isNotEmpty) 'user_name': userName.trim(),
    };

    final response = await http.post(
      Uri.parse('${_baseUrl}save_invoice_draft_lines.php'),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Impossible d\'enregistrer le brouillon (${response.statusCode}).');
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
      throw Exception('Impossible de récupérer le brouillon (${response.statusCode}).');
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
    this.missionRef,
    this.pdfFilename,
    this.pdfPath,
    this.createdBy,
    this.createdByName,
  });

  factory ClientInvoiceSummary.fromJson(Map<String, dynamic> json) {
    DateTime? billedAt;
    final billedRaw = json['billed_at'];
    if (billedRaw is String && billedRaw.trim().isNotEmpty) {
      billedAt = DateTime.tryParse(billedRaw.trim());
    }
    return ClientInvoiceSummary(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      clientName: (json['client_name'] ?? '').toString(),
      statusCode: (json['status_code'] ?? '').toString(),
      statusLabel: (json['status_label'] ?? '').toString(),
      missionRef: json['mission_ref']?.toString(),
      amountHt: json['amount_ht'] is num ? (json['amount_ht'] as num).toDouble() : 0,
      invoiceTotalHt: json['invoice_total_ht'] is num ? (json['invoice_total_ht'] as num).toDouble() : 0,
      billedAt: billedAt,
      pdfFilename: json['pdf_filename']?.toString(),
      pdfPath: json['pdf_path']?.toString(),
      createdBy: json['created_by'] is num ? (json['created_by'] as num).toInt() : null,
      createdByName: json['created_by_name']?.toString(),
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
  final String? missionRef;
  final String? pdfFilename;
  final String? pdfPath;
  final int? createdBy;
  final String? createdByName;
}

class ClientInvoiceLinesResult {
  ClientInvoiceLinesResult({
    required this.invoiceNumber,
    required this.lines,
    this.totalHt,
  });

  final String invoiceNumber;
  final List<InvoiceLine> lines;
  final double? totalHt;
}
