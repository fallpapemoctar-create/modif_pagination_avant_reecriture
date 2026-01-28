import 'dart:convert';

import 'package:http/http.dart' as http;
import '../core/app_config.dart';


  class AuthService {
    static String get baseUrl => AppConfig.instance.apiBaseUrl;


  static Future<Map<String, dynamic>> login(String login, String password) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}login.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "login": login,
          "password": password,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          "success": false,
          "message": "Erreur serveur: ${response.statusCode}"
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        "success": false,
        "message": "Erreur de connexion: $e"
      };
    }
  }
}
