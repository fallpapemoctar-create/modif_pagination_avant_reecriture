import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

class ContactInfo {
  final int id;
  final String firstname;
  final String lastname;
  final String email;
  final String phone;
  final String mobile;

  const ContactInfo({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.phone,
    required this.mobile,
  });

  String get displayName {
    final String fullName = [firstname, lastname]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (fullName.isNotEmpty) return fullName;
    return 'Contact #$id';
  }
}

class ContactService {
  static String get _baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<List<ContactInfo>> getContactsForClient({
    required int clientId,
    String? query,
    int limit = 500,
  }) async {
    final uri = Uri.parse("${_baseUrl}get_contacts.php").replace(queryParameters: {
      'client_id': clientId.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'limit': limit.toString(),
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['success'] == true) {
      final rawList = (decoded['contacts'] as List<dynamic>? ?? []);
      return rawList.map((item) {
        if (item is Map<String, dynamic>) {
          final id = item['id'];
          return ContactInfo(
            id: id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0,
            firstname: (item['firstname'] ?? '').toString(),
            lastname: (item['lastname'] ?? '').toString(),
            email: (item['email'] ?? '').toString(),
            phone: (item['phone'] ?? '').toString(),
            mobile: (item['phone_mobile'] ?? '').toString(),
          );
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
}
