import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

class ClientSummary {
  final int id;
  final String name;
  final String alias;
  final String address;
  final String zip;
  final String town;
  final String phone;
  final String fax;
  final String email;
  final String website;
  final String siren;
  final String siret;
  final String notePublic;
  final String notePrivate;
  final int countryId;
  final String countryLabel;
  final int departmentId;
  final String departmentLabel;
  final int status;
  final int statut;

  const ClientSummary({
    required this.id,
    required this.name,
    this.alias = '',
    this.address = '',
    this.zip = '',
    this.town = '',
    this.phone = '',
    this.fax = '',
    this.email = '',
    this.website = '',
    this.siren = '',
    this.siret = '',
    this.notePublic = '',
    this.notePrivate = '',
    this.countryId = 0,
    this.countryLabel = '',
    this.departmentId = 0,
    this.departmentLabel = '',
    this.status = 1,
    this.statut = 1,
  });

  bool get isActive => status != 0;

  factory ClientSummary.fromJson(Map<String, dynamic> item) {
    final id = item['id'];
    return ClientSummary(
      id: id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0,
      name: (item['name'] ?? '').toString(),
      alias: (item['alias'] ?? item['name_alias'] ?? '').toString(),
      address: (item['address'] ?? '').toString(),
      zip: (item['zip'] ?? '').toString(),
      town: (item['town'] ?? '').toString(),
      phone: (item['phone'] ?? '').toString(),
      fax: (item['fax'] ?? '').toString(),
      email: (item['email'] ?? '').toString(),
      website: (item['website'] ?? '').toString(),
      siren: (item['siren'] ?? '').toString(),
      siret: (item['siret'] ?? '').toString(),
      notePublic: (item['note_public'] ?? '').toString(),
      notePrivate: (item['note_private'] ?? '').toString(),
      countryId: item['fk_pays'] is int
          ? item['fk_pays'] as int
          : int.tryParse(item['fk_pays']?.toString() ?? '') ?? 0,
      countryLabel: (item['country_label'] ?? '').toString(),
      departmentId: item['fk_departement'] is int
          ? item['fk_departement'] as int
          : int.tryParse(item['fk_departement']?.toString() ?? '') ?? 0,
      departmentLabel: (item['department_label'] ?? '').toString(),
      status: item['status'] is int
          ? item['status'] as int
          : int.tryParse(item['status']?.toString() ?? '') ?? 1,
      statut: item['statut'] is int
          ? item['statut'] as int
          : int.tryParse(item['statut']?.toString() ?? '') ?? 1,
    );
  }
}

class ClientService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['error'] ?? decoded['message'] ?? 'Erreur serveur')
                .toString()
          : 'Erreur serveur (${response.statusCode})';
      throw Exception(message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse inattendue du serveur');
    }
    if (decoded['success'] != true) {
      throw Exception(
        (decoded['error'] ?? decoded['message'] ?? 'Erreur serveur').toString(),
      );
    }
    return decoded;
  }

  static Future<List<ClientSummary>> getClientSummaries({
    String? query,
    int limit = 500,
  }) async {
    final uri = Uri.parse("${_baseUrl}get_clients.php").replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit.toString(),
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawList = (decoded['clients'] as List<dynamic>? ?? []);
      return rawList.map((item) {
        if (item is Map<String, dynamic>) {
          return ClientSummary.fromJson(item);
        }
        final name = item?.toString() ?? '';
        return ClientSummary(id: 0, name: name);
      }).toList();
    }
    throw Exception('Réponse inattendue du serveur');
  }

  static Future<List<String>> getClients({
    String? query,
    int limit = 500,
  }) async {
    final summaries = await getClientSummaries(query: query, limit: limit);
    return summaries.map((summary) => summary.name).toList();
  }

  static Future<List<ClientSummary>> getRequestingCompanies({
    String? query,
    int limit = 500,
    bool activeOnly = true,
  }) async {
    final uri = Uri.parse('${_baseUrl}get_clients.php').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit.toString(),
        'active_only': activeOnly ? '1' : '0',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw Exception('Réponse inattendue du serveur');
    }

    final rawList = decoded['clients'] as List<dynamic>? ?? const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ClientSummary.fromJson)
        .toList();
  }

  static Future<ClientSummary> addRequestingCompany({
    required String name,
    String alias = '',
    String address = '',
    String zip = '',
    String town = '',
    String phone = '',
    String fax = '',
    String email = '',
    String website = '',
    String siren = '',
    String siret = '',
    String notePublic = '',
    String notePrivate = '',
    String country = '',
    String department = '',
    int? userId,
  }) async {
    final decoded = await _postJson('add_client.php', {
      'name': name,
      'alias': alias,
      'address': address,
      'zip': zip,
      'town': town,
      'phone': phone,
      'fax': fax,
      'email': email,
      'website': website,
      'siren': siren,
      'siret': siret,
      'note_public': notePublic,
      'note_private': notePrivate,
      'country': country,
      'department': department,
      ...userId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'user_id': userId},
    });
    return ClientSummary.fromJson(
      Map<String, dynamic>.from(decoded['company'] as Map),
    );
  }

  static Future<ClientSummary> updateRequestingCompany({
    required int id,
    required String name,
    String alias = '',
    String address = '',
    String zip = '',
    String town = '',
    String phone = '',
    String fax = '',
    String email = '',
    String website = '',
    String siren = '',
    String siret = '',
    String notePublic = '',
    String notePrivate = '',
    String country = '',
    String department = '',
    bool isActive = true,
    int? userId,
  }) async {
    final decoded = await _postJson('update_client.php', {
      'id': id,
      'name': name,
      'alias': alias,
      'address': address,
      'zip': zip,
      'town': town,
      'phone': phone,
      'fax': fax,
      'email': email,
      'website': website,
      'siren': siren,
      'siret': siret,
      'note_public': notePublic,
      'note_private': notePrivate,
      'country': country,
      'department': department,
      'is_active': isActive ? 1 : 0,
      ...userId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'user_id': userId},
    });
    return ClientSummary.fromJson(
      Map<String, dynamic>.from(decoded['company'] as Map),
    );
  }

  static Future<void> deleteRequestingCompany({
    required int id,
    int? userId,
  }) async {
    await _postJson('delete_client.php', {
      'id': id,
      ...userId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'user_id': userId},
    });
  }
}
