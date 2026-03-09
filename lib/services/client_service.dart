import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

class ClientService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<List<String>> getClients({String? query, int limit = 500}) async {
    final uri = Uri.parse("${_baseUrl}get_clients.php").replace(queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'limit': limit.toString(),
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final list = (decoded['clients'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList();
      return list;
    }
    throw Exception('Réponse inattendue du serveur');
  }
}
