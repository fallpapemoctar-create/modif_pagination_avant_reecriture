// lib/services/quote_service.dart
// AMI v1.4 — Module Devis

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/models/quote.dart';

class QuoteService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  // ----------------------------------------------------------------
  // Créer un devis depuis une mission (RM-01, RM-02)
  // ----------------------------------------------------------------
  static Future<Quote> createFromMission({
    required int missionId,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}create_quote_from_mission.php'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'mission_id': missionId, 'user_id': userId}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201 || decoded['success'] == true) {
      final quoteId = decoded['quote_id'] as int;
      return getQuote(quoteId);
    }
    // Devis actif déjà existant → ouvrir le devis existant
    if (response.statusCode == 409 &&
        decoded['code'] == 'QUOTE_ALREADY_EXISTS') {
      final quoteId = decoded['quote_id'] as int;
      return getQuote(quoteId);
    }
    throw Exception(decoded['error'] ?? 'Erreur lors de la création du devis');
  }

  // ----------------------------------------------------------------
  // Récupérer un devis complet (entête + lignes)
  // ----------------------------------------------------------------
  static Future<Quote> getQuote(int quoteId) async {
    final uri = Uri.parse('${_baseUrl}get_quote.php')
        .replace(queryParameters: {'quote_id': quoteId.toString()});
    final response = await http.get(uri);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      return Quote.fromJson(decoded['quote'] as Map<String, dynamic>);
    }
    throw Exception(decoded['error'] ?? 'Devis introuvable');
  }

  // ----------------------------------------------------------------
  // Liste des devis (paginée, filtrable)
  // ----------------------------------------------------------------
  static Future<({List<Quote> quotes, int total})> getQuotes({
    String? status,
    int? clientId,
    int page = 1,
    int pageSize = 25,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (clientId != null) 'client_id': clientId.toString(),
    };
    final uri = Uri.parse('${_baseUrl}get_quotes.php')
        .replace(queryParameters: params);
    final response = await http.get(uri);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      final list = (decoded['quotes'] as List? ?? [])
          .whereType<Map>()
          .map((q) => Quote.fromJson(Map<String, dynamic>.from(q)))
          .toList();
      final total = decoded['total'] is num
          ? (decoded['total'] as num).toInt()
          : list.length;
      return (quotes: list, total: total);
    }
    throw Exception(decoded['error'] ?? 'Erreur lors du chargement des devis');
  }

  // ----------------------------------------------------------------
  // Mettre à jour un devis (RM-04)
  // ----------------------------------------------------------------
  static Future<Quote> updateQuote({
    required int quoteId,
    String? notes,
    String? dateValidUntil,
    String? status,
    List<QuoteLine>? lines,
  }) async {
    final payload = <String, dynamic>{'quote_id': quoteId};
    if (notes != null) payload['notes'] = notes;
    if (dateValidUntil != null) payload['date_valid_until'] = dateValidUntil;
    if (status != null) payload['status'] = status;
    if (lines != null) {
      payload['lines'] = lines
          .asMap()
          .entries
          .map((e) => {...e.value.toJson(), 'sort_order': e.key})
          .toList();
    }
    final response = await http.post(
      Uri.parse('${_baseUrl}update_quote.php'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      return getQuote(quoteId);
    }
    throw Exception(
        decoded['error'] ?? 'Erreur lors de la mise à jour du devis');
  }

  // ----------------------------------------------------------------
  // Convertir un devis accepté en facture (RM-07)
  // ----------------------------------------------------------------
  static Future<({String invoiceNumber, int invoiceId})> convertToInvoice({
    required int quoteId,
    int? userId,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}convert_quote_to_invoice.php'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'quote_id': quoteId,
        'user_id': ?userId,
      }),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        decoded['success'] == true) {
      return (
        invoiceNumber: decoded['invoice_number'] as String,
        invoiceId: decoded['invoice_id'] as int,
      );
    }
    throw Exception(
        decoded['error'] ?? 'Erreur lors de la conversion en facture');
  }
}
