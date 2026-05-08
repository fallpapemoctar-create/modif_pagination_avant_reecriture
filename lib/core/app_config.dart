import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;

// Config asset selection priority:
// 1. --dart-define=APP_CONFIG_ASSET=<path>  (explicit override)
// 2. Release build  → assets/config/app_config.prod.json
// 3. Debug/profile  → assets/config/app_config.json  (localhost)
const String _configAssetOverride = String.fromEnvironment('APP_CONFIG_ASSET');

String get _configAsset {
  if (_configAssetOverride.isNotEmpty) return _configAssetOverride;
  return kReleaseMode
      ? 'assets/config/app_config.prod.json'
      : 'assets/config/app_config.json';
}

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

  static Future<void> load({String? assetPath}) async {
    final raw = await rootBundle.loadString(assetPath ?? _configAsset);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final base = map['apiBaseUrl'] as String?;
    if (base == null || base.isEmpty) {
      throw StateError('Missing "apiBaseUrl" in $assetPath');
    }
    _instance = AppConfig._(apiBaseUrl: base.endsWith('/') ? base : '$base/');
  }
}
