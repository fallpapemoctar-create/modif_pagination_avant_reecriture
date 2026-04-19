import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

class LanguageOption {
  final int? id;
  final String ref;
  final String label;
  final double? price;
  final double? priceTtc;
  final double? tvaTx;

  const LanguageOption({
    required this.id,
    required this.ref,
    required this.label,
    this.price,
    this.priceTtc,
    this.tvaTx,
  });

  String get displayName {
    if (label.trim().isNotEmpty) return label.trim();
    return ref.trim();
  }

  factory LanguageOption.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return LanguageOption(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse((json['id'] ?? '').toString()),
        ref: (json['ref'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        price: json['price'] == null ? null : double.tryParse(json['price'].toString()),
        priceTtc: json['price_ttc'] == null ? null : double.tryParse(json['price_ttc'].toString()),
        tvaTx: json['tva_tx'] == null ? null : double.tryParse(json['tva_tx'].toString()),
      );
    }
    final value = json?.toString() ?? '';
    return LanguageOption(id: null, ref: value, label: value);
  }
}

class LanguageService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<List<LanguageOption>> getLanguages({String? query, int limit = 250, int? type}) async {
    final trimmedQuery = query?.trim();
    final Map<String, String> params = {
      'limit': limit.clamp(1, 10000).toString(),
    };
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      params['q'] = trimmedQuery;
    }
    if (type != null) {
      params['type'] = type.toString();
    }

    final uri = Uri.parse('${_baseUrl}get_languages.php').replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['success'] == true) {
      final List<dynamic> rows = decoded['languages'] as List<dynamic>? ?? const [];
      return rows.map(LanguageOption.fromJson).toList();
    }
    throw Exception('Réponse inattendue du serveur');
  }

  static Future<List<String>> getLanguageDisplayNames({String? query, int limit = 250, int? type}) async {
    final options = await getLanguages(query: query, limit: limit, type: type);
    final seen = <String>{};
    final result = <String>[];
    for (final option in options) {
      final name = option.displayName;
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (seen.add(lower)) {
        result.add(name);
      }
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }
}
