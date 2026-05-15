import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mission.dart';
import '../core/app_config.dart';

class MissionApiResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const MissionApiResult({required this.success, this.message, this.data});
}

class MissionService {
  static String get baseUrl => AppConfig.instance.apiBaseUrl;

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
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/get_missions_by_interpreter.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({}),
      );

      // Debug logs removed for production cleanliness

      if (response.statusCode != 200) throw Exception("Erreur: ${response.statusCode}");

      final dynamic data = jsonDecode(response.body);
      
      if (data is List) {
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else if (data is Map && data.containsKey('data')) {
        return (data['data'] as List).map((e) => e as Map<String, dynamic>).toList();
      } else if (data is Map && data.containsKey('success') && data['success'] == false) {
        throw Exception(data['message'] ?? 'Erreur API');
      } else {
        throw Exception("Format de réponse inattendu");
      }
    } catch (e) {
      // Swallow noisy logs in production
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMissionsDatatable({
    int page = 1,
    int pageSize = 50,
    String? q,
    String? requestingCompany,
    String? dateStart,
    String? dateEnd,
    String? billedStatus,
    String? missionStatus,
    String? missionType,
  }) async {
    try {
      final uri = Uri.parse("${baseUrl}get_missions_datatable.php").replace(queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (requestingCompany != null && requestingCompany.trim().isNotEmpty)
          'requestingCompany': requestingCompany.trim(),
        if (dateStart != null && dateStart.trim().isNotEmpty) 'dateStart': dateStart.trim(),
        if (dateEnd != null && dateEnd.trim().isNotEmpty) 'dateEnd': dateEnd.trim(),
        if (billedStatus != null && billedStatus.trim().isNotEmpty) 'billedStatus': billedStatus.trim(),
        if (missionStatus != null && missionStatus.trim().isNotEmpty) 'missionStatus': missionStatus.trim(),
        if (missionType != null && missionType.trim().isNotEmpty) 'missionType': missionType.trim(),
      });
      final response = await http.get(uri);
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['success'] == true) {
        final data = (decoded['missions'] as List<dynamic>? ) ?? [];
        return {
          'missions': data.map((e) => (e as Map<String, dynamic>)).toList(),
          'total': decoded['total'] ?? data.length,
          'page': decoded['page'] ?? page,
          'pageSize': decoded['pageSize'] ?? pageSize,
        };
      } else if (decoded is List) {
        final list = decoded.cast<Map<String, dynamic>>();
        return {'missions': list, 'total': list.length, 'page': page, 'pageSize': pageSize};
      } else {
        return {'missions': <Map<String, dynamic>>[], 'total': 0, 'page': page, 'pageSize': pageSize};
      }
    } catch (e) {
      // Suppress console noise in production
      return {'missions': <Map<String, dynamic>>[], 'total': 0, 'page': page, 'pageSize': pageSize};
    }
  }

  static Future<List<Map<String, dynamic>>> getMissionsDatatableAll({
    String? q,
    String? requestingCompany,
    int? clientId,
    String? dateStart,
    String? dateEnd,
    String? billedStatus,
    String? missionStatus,
    String? missionType,
  }) async {
    try {
      final uri = Uri.parse("${baseUrl}get_missions_datatable.php").replace(queryParameters: {
        'exportAll': '1',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (requestingCompany != null && requestingCompany.trim().isNotEmpty)
          'requestingCompany': requestingCompany.trim(),
        if (clientId != null && clientId > 0) 'clientId': clientId.toString(),
        if (dateStart != null && dateStart.trim().isNotEmpty) 'dateStart': dateStart.trim(),
        if (dateEnd != null && dateEnd.trim().isNotEmpty) 'dateEnd': dateEnd.trim(),
        if (billedStatus != null && billedStatus.trim().isNotEmpty) 'billedStatus': billedStatus.trim(),
        if (missionStatus != null && missionStatus.trim().isNotEmpty) 'missionStatus': missionStatus.trim(),
        if (missionType != null && missionType.trim().isNotEmpty) 'missionType': missionType.trim(),
      });
      final response = await http.get(uri);
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['success'] == true) {
        final data = (decoded['missions'] as List<dynamic>? ) ?? [];
        return data.map((e) => (e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      // Suppress console noise in production
      return [];
    }
  }

  // ------------------------------------------------------------
  // GET : Liste des interprètes (annuaire)
  // ------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getInterpretes({
    String? query,
    int limit = 250,
  }) async {
    try {
      final uri = Uri.parse("${baseUrl}get_interpretes.php").replace(
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          'limit': limit.toString(),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
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

  static MissionApiResult _parseMissionResponse(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final bool success = decoded['success'] == true;
        final dynamic rawMessage = decoded['message'] ?? decoded['error'];
        final String? message = rawMessage == null
            ? null
            : rawMessage.toString().trim().isEmpty
                ? null
                : rawMessage.toString().trim();
        return MissionApiResult(success: success, message: message, data: decoded);
      }
      if (decoded is bool) {
        return MissionApiResult(success: decoded, data: {'success': decoded});
      }
    } catch (_) {
      // ignore JSON parsing errors, fall back to status code message
    }
    final bool ok = response.statusCode >= 200 && response.statusCode < 300;
    final body = response.body.trim();
    final fallback = body.isNotEmpty ? body : 'Erreur serveur (${response.statusCode})';
    return MissionApiResult(success: ok, message: ok ? null : fallback, data: null);
  }

  // Convenience methods that accept a raw Map payload (useful when server expects flexible keys)
  static Future<MissionApiResult> addMissionMap(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_mission_interpreter.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      return _parseMissionResponse(response);
    } catch (e) {
      return MissionApiResult(success: false, message: 'Erreur réseau: $e');
    }
  }

  static Future<MissionApiResult> updateMissionMap(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_mission_interpreter.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      return _parseMissionResponse(response);
    } catch (e) {
      return MissionApiResult(success: false, message: 'Erreur réseau: $e');
    }
  }

}