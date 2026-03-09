import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/country.dart';

class CountryService {
  static String get baseUrl => AppConfig.instance.apiBaseUrl;

  static Future<List<Country>> getCountries() async {
    final response = await http.get(Uri.parse("${baseUrl}get_countries.php"));
    if (response.statusCode != 200) {
      throw Exception('Erreur lors du chargement des pays (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Format de réponse pays inattendu');
    }
    return decoded.map<Country>((e) => Country.fromJson(e as Map<String, dynamic>)).toList();
  }
}
