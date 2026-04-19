import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/interpreter.dart';
import '../core/app_config.dart';

class InterpreterService {
  static String get baseUrl => AppConfig.instance.apiBaseUrl;


  // -----------------------------
  // GET : Liste des interprètes
  // -----------------------------
  static Future<List<Interpreter>> getInterpreters({int limit = 10000}) async {
    try {
      final normalizedLimit = limit.clamp(1, 10000);
      final uri = Uri.parse("${baseUrl}get_interpretes.php").replace(
        queryParameters: {'limit': normalizedLimit.toString()},
      );
      final response = await http.get(uri);

      // Debug logs removed for production cleanliness

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          data = decoded['data'] as List<dynamic>;
        } else if (decoded is Map && decoded.containsKey('interpretes')) {
          data = decoded['interpretes'] as List<dynamic>;
        } else {
          throw Exception("Format de réponse inattendu");
        }
        
        return data.map((e) => Interpreter.fromJson(e)).toList();
      } else {
        throw Exception("Erreur lors du chargement des interprètes: ${response.statusCode}");
      }
    } catch (e) {
      // Swallow noisy logs in production
      throw Exception("Erreur lors du chargement des interprètes: $e");
    }
  }
  // -----------------------------
  // POST : Ajouter un interprète
  // -----------------------------
  static Future<bool> addInterpreter(Interpreter i) async {
    final response = await http.post(
      Uri.parse("${baseUrl}add_interprete.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(i.toJson()),
    );

    if (response.statusCode == 200) {
      return true;
    }
    throw Exception(_responseError(response.body, 'Impossible d\'ajouter l\'interprète.'));
  }


  // -----------------------------
  // PUT : Modifier un interprète
  // -----------------------------
  static Future<bool> updateInterpreter(Interpreter i) async {
    final response = await http.put(
      Uri.parse("${baseUrl}update_interprete.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(i.toJson()),
    );

    if (response.statusCode == 200) {
      return true;
    }
    throw Exception(_responseError(response.body, 'Impossible de mettre à jour l\'interprète.'));
  }

  // -----------------------------
  // DELETE : Supprimer un interprète
  // -----------------------------
  static Future<bool> deleteInterpreter(int id) async {
    final response = await http.delete(
      Uri.parse("${baseUrl}delete_interprete.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );

    return response.statusCode == 200;
  }
}

String _responseError(String body, String fallback) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
  } catch (_) {
    return fallback;
  }
  return fallback;
}