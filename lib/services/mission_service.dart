import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mission.dart';

class MissionService {
  static const String baseUrl = "http://ami.yourbizapps.com/api/";

  // ------------------------------------------------------------
  // GET : Liste des interprètes des missions
  // ------------------------------------------------------------
  static Future<List<Mission>> getMissions() async {
    // default: fetch first page with large pageSize
    return getMissionsPaged(page: 1, pageSize: 1000);
  }

  static Future<List<Mission>> getMissionsPaged({int page = 1, int pageSize = 100, String? search}) async {
    final Map<String, dynamic> body = {"page": page, "pageSize": pageSize};
    if (search != null && search.isNotEmpty) body['search'] = search;

    final response = await http.post(
      Uri.parse("$baseUrl/get_tab_mission_par_interpreters.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) throw Exception("Erreur");

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('data')) {
      return (decoded['data'] as List).map((e) => Mission.fromJson(e)).toList();
    }

    return (decoded as List).map((e) => Mission.fromJson(e)).toList();
  }

  // Returns both total and data for paginated requests
  static Future<Map<String, dynamic>> getMissionsPage({int page = 1, int pageSize = 100, String? search}) async {
    final Map<String, dynamic> body = {"page": page, "pageSize": pageSize};
    if (search != null && search.isNotEmpty) body['search'] = search;

    final response = await http.post(
      Uri.parse("$baseUrl/get_tab_mission_par_interpreters.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) throw Exception("Erreur");

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('data')) {
      final total = decoded['total'] ?? 0;
      final list = (decoded['data'] as List).map((e) => Mission.fromJson(e)).toList();
      return {'total': total, 'data': list};
    }

    final list = (decoded as List).map((e) => Mission.fromJson(e)).toList();
    return {'total': list.length, 'data': list};
  }

  // ------------------------------------------------------------
  // GET : Missions par interprète
  // ------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getMissionsByInterpreter(int interpreterId, {int page = 1, int pageSize = 100, int? year, int? month}) async {
    final Map<String, dynamic> body = {"interpreter_id": interpreterId, "page": page, "pageSize": pageSize};
    if (year != null) body['year'] = year;
    if (month != null) body['month'] = month;

    final response = await http.post(
      Uri.parse("$baseUrl/get_missions_by_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) throw Exception("Erreur");

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).map((e) => e as Map<String, dynamic>).toList();
    }

    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  // ------------------------------------------------------------
  // GET : Liste des interprètes ayant au moins une mission (for master list)
  // ------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getInterpretersWithMissions() async {
    final response = await http.post(
      Uri.parse("$baseUrl/get_missions_by_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({}),
    );

    if (response.statusCode != 200) throw Exception("Erreur");

    final data = jsonDecode(response.body);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }
  // ------------------------------------------------------------
  // POST : Ajouter un interprète de mission
  // ------------------------------------------------------------
  static Future<bool> addMission(Mission mission) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_mission_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(mission.toJson()),
    );

    if (response.statusCode != 200) return false;

    return jsonDecode(response.body)["success"] == true;
  }

  // ------------------------------------------------------------
  // PUT : Modifier un interprète de mission
  // ------------------------------------------------------------
  static Future<bool> updateMission(Mission mission) async {
    final response = await http.post(
      Uri.parse("$baseUrl/update_mission_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(mission.toJson()),
    );

    if (response.statusCode != 200) return false;

    return jsonDecode(response.body)["success"] == true;
  }

  // ------------------------------------------------------------
  // DELETE : Supprimer un interprète de mission
  // ------------------------------------------------------------
  static Future<bool> deleteMission(int id) async {
    final response = await http.post(
      Uri.parse("$baseUrl/delete_mission_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );

    if (response.statusCode != 200) return false;

    return jsonDecode(response.body)["success"] == true;
  }

  // Convenience methods that accept a raw Map payload (useful when server expects flexible keys)
  static Future<bool> addMissionMap(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_mission_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) return false;
    return jsonDecode(response.body)["success"] == true;
  }

  static Future<bool> updateMissionMap(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/update_mission_interpreter.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) return false;
    return jsonDecode(response.body)["success"] == true;
  }

}