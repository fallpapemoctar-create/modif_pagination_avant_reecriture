import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/interpreter.dart';

class InterpreterService {
  //static const String baseUrl = "http://ami.yourbizapps.com/api/";
    static const String baseUrl = "http://localhost/gesplanet_01/ami/api/";


  // -----------------------------
  // GET : Liste des interprètes
  // -----------------------------
  static Future<List<Interpreter>> getInterpreters() async {
    try {
      final response = await http.get(Uri.parse("${baseUrl}get_interpretes.php"));

      print('Interpreters response status: ${response.statusCode}');
      print('Interpreters response body: ${response.body}');

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
      print('Error loading interpreters: $e');
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

    return response.statusCode == 200;
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

    return response.statusCode == 200;
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