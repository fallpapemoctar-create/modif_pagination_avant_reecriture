import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/interpreter.dart';

class InterpreterService {
  static const String baseUrl = "http://ami.yourbizapps.com/api/";

  // -----------------------------
  // GET : Liste des interprètes
  // -----------------------------
  static Future<List<Interpreter>> getInterpreters() async {
    final response = await http.get(Uri.parse("${baseUrl}get_interpretes.php"));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Interpreter.fromJson(e)).toList();
    } else {
      throw Exception("Erreur lors du chargement des interprètes");
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