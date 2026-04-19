import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

class ContactInfo {
  final int id;
  final int clientId;
  final String civility;
  final String firstname;
  final String lastname;
  final String email;
  final String phone;
  final String personalPhone;
  final String mobile;
  final String position;
  final String address;
  final String zip;
  final String town;
  final String fax;
  final String birthday;
  final String notePublic;
  final String notePrivate;
  final int countryId;
  final String countryLabel;
  final int departmentId;
  final String departmentLabel;
  final int status;

  const ContactInfo({
    required this.id,
    this.clientId = 0,
    this.civility = '',
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.phone,
    this.personalPhone = '',
    required this.mobile,
    this.position = '',
    this.address = '',
    this.zip = '',
    this.town = '',
    this.fax = '',
    this.birthday = '',
    this.notePublic = '',
    this.notePrivate = '',
    this.countryId = 0,
    this.countryLabel = '',
    this.departmentId = 0,
    this.departmentLabel = '',
    this.status = 1,
  });

  String get displayName {
    final String fullName = [
      firstname,
      lastname,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty) return fullName;
    return 'Contact #$id';
  }

  bool get isActive => status != 0;

  factory ContactInfo.fromJson(Map<String, dynamic> item) {
    final id = item['id'];
    final clientId = item['client_id'];
    return ContactInfo(
      id: id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0,
      clientId: clientId is int
          ? clientId
          : int.tryParse(clientId?.toString() ?? '') ?? 0,
      civility: (item['civility'] ?? '').toString(),
      firstname: (item['firstname'] ?? '').toString(),
      lastname: (item['lastname'] ?? '').toString(),
      email: (item['email'] ?? '').toString(),
      phone: (item['phone'] ?? '').toString(),
      personalPhone: (item['phone_perso'] ?? item['personal_phone'] ?? '')
          .toString(),
      mobile: (item['phone_mobile'] ?? item['mobile'] ?? '').toString(),
      position: (item['position'] ?? item['poste'] ?? '').toString(),
      address: (item['address'] ?? '').toString(),
      zip: (item['zip'] ?? '').toString(),
      town: (item['town'] ?? '').toString(),
      fax: (item['fax'] ?? '').toString(),
      birthday: (item['birthday'] ?? '').toString(),
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
    );
  }
}

class ContactService {
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

  static Future<List<ContactInfo>> getContactsForClient({
    required int clientId,
    String? query,
    int limit = 500,
    bool activeOnly = false,
  }) async {
    final uri = Uri.parse("${_baseUrl}get_contacts.php").replace(
      queryParameters: {
        'client_id': clientId.toString(),
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
    if (decoded is Map && decoded['success'] == true) {
      final rawList = (decoded['contacts'] as List<dynamic>? ?? []);
      return rawList.map((item) {
        if (item is Map<String, dynamic>) {
          return ContactInfo.fromJson(item);
        }
        return ContactInfo(
          id: 0,
          firstname: item?.toString() ?? '',
          lastname: '',
          email: '',
          phone: '',
          mobile: '',
        );
      }).toList();
    }
    throw Exception('Réponse inattendue du serveur');
  }

  static Future<ContactInfo> addContact({
    required int clientId,
    required String firstname,
    required String lastname,
    String civility = '',
    String email = '',
    String phone = '',
    String personalPhone = '',
    String mobile = '',
    String position = '',
    String address = '',
    String zip = '',
    String town = '',
    String fax = '',
    String birthday = '',
    String notePublic = '',
    String notePrivate = '',
    String country = '',
    String department = '',
    int? userId,
  }) async {
    final decoded = await _postJson('add_contact.php', {
      'client_id': clientId,
      'firstname': firstname,
      'lastname': lastname,
      'civility': civility,
      'email': email,
      'phone': phone,
      'personal_phone': personalPhone,
      'mobile': mobile,
      'position': position,
      'address': address,
      'zip': zip,
      'town': town,
      'fax': fax,
      'birthday': birthday,
      'note_public': notePublic,
      'note_private': notePrivate,
      'country': country,
      'department': department,
      ...userId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'user_id': userId},
    });
    return ContactInfo.fromJson(
      Map<String, dynamic>.from(decoded['contact'] as Map),
    );
  }

  static Future<ContactInfo> updateContact({
    required int id,
    required int clientId,
    required String firstname,
    required String lastname,
    String civility = '',
    String email = '',
    String phone = '',
    String personalPhone = '',
    String mobile = '',
    String position = '',
    String address = '',
    String zip = '',
    String town = '',
    String fax = '',
    String birthday = '',
    String notePublic = '',
    String notePrivate = '',
    String country = '',
    String department = '',
    bool isActive = true,
    int? userId,
  }) async {
    final decoded = await _postJson('update_contact.php', {
      'id': id,
      'client_id': clientId,
      'firstname': firstname,
      'lastname': lastname,
      'civility': civility,
      'email': email,
      'phone': phone,
      'personal_phone': personalPhone,
      'mobile': mobile,
      'position': position,
      'address': address,
      'zip': zip,
      'town': town,
      'fax': fax,
      'birthday': birthday,
      'note_public': notePublic,
      'note_private': notePrivate,
      'country': country,
      'department': department,
      'is_active': isActive ? 1 : 0,
      ...userId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'user_id': userId},
    });
    return ContactInfo.fromJson(
      Map<String, dynamic>.from(decoded['contact'] as Map),
    );
  }

  static Future<void> deleteContact({required int id, int? userId}) async {
    await _postJson('delete_contact.php', {
      'id': id,
      ...userId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'user_id': userId},
    });
  }
}
