import 'dart:convert';

import 'package:http/http.dart' as http;


  class AuthService {
  static const String baseUrl = "http://localhost/gesplanet_01/ami/api/";

  static Future<Map<String, dynamic>> login(String login, String password) async {
    final response = await http.post(
      Uri.parse("${baseUrl}login.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "login": login,
        "password": password,
      }),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
