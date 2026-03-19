import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

class ClientSummary {
  final int id;
  final String name;

  const ClientSummary({required this.id, required this.name});
}

class ClientService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<List<ClientSummary>> getClientSummaries({String? query, int limit = 500}) async {
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
      final rawList = (decoded['clients'] as List<dynamic>? ?? []);
      return rawList.map((item) {
        if (item is Map<String, dynamic>) {
          final id = item['id'];
          final name = (item['name'] ?? '').toString();
          return ClientSummary(
            id: id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0,
            name: name,
          );
        }
        final name = item?.toString() ?? '';
        return ClientSummary(id: 0, name: name);
      }).toList();
    }
    throw Exception('Réponse inattendue du serveur');
  }

  static Future<List<String>> getClients({String? query, int limit = 500}) async {
    final summaries = await getClientSummaries(query: query, limit: limit);
    return summaries.map((summary) => summary.name).toList();
  }
}
