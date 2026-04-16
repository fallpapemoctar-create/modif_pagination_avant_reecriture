import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/department.dart';

class DepartmentService {
  static String get baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<List<Department>> getDepartments() async {
    final response = await http.get(Uri.parse('${baseUrl}get_departments.php'));
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur lors du chargement des departements (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Format de reponse departements inattendu');
    }
    return decoded
        .map<Department>((e) => Department.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
