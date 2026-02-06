import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Allows selecting an alternative config at build time:
// flutter build web --dart-define=APP_CONFIG_ASSET=assets/config/app_config.prod.json
const String _configAsset = String.fromEnvironment(
  'APP_CONFIG_ASSET',
  defaultValue: 'assets/config/app_config.json',
);

class AppConfig {
  final String apiBaseUrl;

  AppConfig._({required this.apiBaseUrl});

  static AppConfig? _instance;

  static AppConfig get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError('AppConfig not initialized. Call AppConfig.load() before using it.');
    }
    return inst;
  }

  static Future<void> load({String assetPath = _configAsset}) async {
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final base = map['apiBaseUrl'] as String?;
    if (base == null || base.isEmpty) {
      throw StateError('Missing "apiBaseUrl" in $assetPath');
    }
    _instance = AppConfig._(apiBaseUrl: base.endsWith('/') ? base : '$base/');
  }
}
