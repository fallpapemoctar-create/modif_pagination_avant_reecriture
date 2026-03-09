import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/user_rights.dart';

class AuthManager {
  static const _userKey = 'auth_user';
  static const _rightsKey = 'auth_rights';
  static const _rememberKey = 'auth_remember';
  static Map<String, dynamic>? _user;
  static UserRights? _rights;
  static bool _remember = false;

  // -------------------------
  // USER
  // -------------------------
  static void setUser(Map<String, dynamic> user) {
    _user = user;
  }

  static Map<String, dynamic>? get user => _user;

  static int get userId => _user?["id"] ?? 0;

  static String get userFullName {
    if (_user == null) return "";
    return "${_user!["prenom"]} ${_user!["nom"]}";
  }

  // -------------------------
  // RIGHTS
  // -------------------------
  static void setRights(UserRights rights) {
    _rights = rights;
  }

  static bool get rememberMe => _remember;

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _remember = prefs.getBool(_rememberKey) ?? false;
    if (!_remember) {
      await prefs.remove(_userKey);
      await prefs.remove(_rightsKey);
      return;
    }
    final userJson = prefs.getString(_userKey);
    final rightsCodes = prefs.getStringList(_rightsKey);
    if (userJson != null) {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        _user = decoded;
      }
    }
    if (rightsCodes != null) {
      _rights = UserRights(rightsCodes);
    }
  }

  static Future<void> persistSession({required bool rememberMe}) async {
    final prefs = await SharedPreferences.getInstance();
    _remember = rememberMe;
    await prefs.setBool(_rememberKey, rememberMe);
    if (!rememberMe || _user == null || _rights == null) {
      await prefs.remove(_userKey);
      await prefs.remove(_rightsKey);
      return;
    }
    await prefs.setString(_userKey, jsonEncode(_user));
    await prefs.setStringList(_rightsKey, _rights!.codes);
  }

  static UserRights get userRights => _rights ?? UserRights([]);

  // -------------------------
  // LOGOUT
  // -------------------------
  static Future<void> logout() async {
    _user = null;
    _rights = null;
    _remember = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_rightsKey);
    await prefs.remove(_rememberKey);
  }

  // -------------------------
  // CHECK IF LOGGED
  // -------------------------
  static bool get isLogged => _user != null;
}