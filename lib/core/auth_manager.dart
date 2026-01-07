import '../core/user_rights.dart';

class AuthManager {
  static Map<String, dynamic>? _user;
  static UserRights? _rights;

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

  static UserRights get userRights => _rights ?? UserRights([]);

  // -------------------------
  // LOGOUT
  // -------------------------
  static void logout() {
    _user = null;
    _rights = null;
  }

  // -------------------------
  // CHECK IF LOGGED
  // -------------------------
  static bool get isLogged => _user != null;
}