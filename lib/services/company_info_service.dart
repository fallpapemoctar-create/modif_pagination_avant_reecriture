import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/company_bank_account.dart';
import '../models/company_info.dart';

class CompanyInfoService {
  static Uri _endpoint(String path) {
    return Uri.parse('${AppConfig.instance.apiBaseUrl}$path');
  }

  static Future<CompanyInfo> fetch() async {
    final response = await http.get(_endpoint('get_company_info.php'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les informations entreprise');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    if (map['success'] != true || map['company'] == null) {
      throw Exception(map['error'] ?? 'Réponse invalide');
    }
    return CompanyInfo.fromJson(map['company'] as Map<String, dynamic>);
  }

  static Future<List<CompanyBankAccount>> fetchBankAccounts() async {
    final response = await http.get(_endpoint('get_company_bank_accounts.php'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les comptes bancaires');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    if (map['success'] != true || map['bankAccounts'] is! List) {
      throw Exception(map['error'] ?? 'Réponse invalide');
    }
    final items = map['bankAccounts'] as List<dynamic>;
    return items
        .whereType<Map<String, dynamic>>()
        .map(CompanyBankAccount.fromJson)
        .where((account) => account.id > 0)
        .toList(growable: false);
  }

  static Future<CompanyInfo> update(CompanyInfo info) async {
    final response = await http.post(
      _endpoint('update_company_info.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(info.toJson()),
    );
    Map<String, dynamic>? map;
    try {
      map = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      map = null;
    }

    if (response.statusCode != 200) {
      final message =
          _extractError(map) ??
          'Impossible d\'enregistrer les informations (code ${response.statusCode})';
      throw Exception(message);
    }

    if (map == null) {
      throw Exception('Réponse invalide');
    }

    if (map['success'] != true || map['company'] == null) {
      throw Exception(map['error'] ?? 'Réponse invalide');
    }
    try {
      return await fetch();
    } catch (_) {
      return CompanyInfo.fromJson(map['company'] as Map<String, dynamic>);
    }
  }

  static String? _extractError(Map<String, dynamic>? map) {
    final raw = map?['error'];
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
