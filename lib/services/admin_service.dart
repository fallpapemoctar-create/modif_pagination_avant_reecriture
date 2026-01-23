import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class AdminService {
 // static const String baseUrl = "http://ami.yourbizapps.com/api/admin/";
    static const String baseUrl = "http://localhost/gesplanet_01/ami/api/admin/";


  /// Returns a map with keys: 'users' => list of users, 'summary' => map of summary values.
  static Future<Map<String, dynamic>> getUsers() async {
    final resp = await http.get(Uri.parse('${baseUrl}get_users.php'));
    final body = jsonDecode(resp.body);

    List<dynamic> rawUsers = [];
    Map<String, dynamic> summary = {};

    if (body is Map<String, dynamic>) {
      if (body['success'] != true && !body.containsKey('users')) {
        throw Exception(body['error'] ?? 'API error');
      }
      rawUsers = (body['users'] as List<dynamic>?) ?? [];
      summary = (body['summary'] as Map<String, dynamic>?) ?? {};
    } else if (body is List<dynamic>) {
      rawUsers = body;
      summary = {};
    } else {
      throw Exception('Unexpected API response');
    }

    final users = rawUsers.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    return {'users': users, 'summary': summary};
  }

  static Future<bool> addUser(UserModel user, String password) async {
    final payload = user.toJson();
    payload['password'] = password;

    final resp = await http.post(Uri.parse('${baseUrl}add_user.php'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    final body = jsonDecode(resp.body);
    return body is Map && (body['success'] == true || body['success'] == '1');
  }

  static Future<bool> updateUser(UserModel user, {String? password}) async {
    final payload = user.toJson();
    payload['id'] = user.id;
    if (password != null && password.isNotEmpty) payload['password'] = password;

    final resp = await http.post(Uri.parse('${baseUrl}update_user.php'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    final body = jsonDecode(resp.body);
    return body is Map && (body['success'] == true || body['success'] == '1');
  }

  static Future<bool> deleteUser(int id) async {
    final resp = await http.post(Uri.parse('${baseUrl}delete_user.php'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id': id}));
    final body = jsonDecode(resp.body);
    return body is Map && (body['success'] == true || body['success'] == '1');
  }
}

