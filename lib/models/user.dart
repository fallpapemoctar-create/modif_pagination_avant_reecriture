class UserModel {
  final int id;
  final String username;
  final String fullname;
  final String email;

  final bool canManageInterpreters;
  final bool canManageMissions;
  final bool isAdmin;
  final bool isInterpreter;
  final List<dynamic> rightsDisplay;

  UserModel({
    required this.id,
    required this.username,
    required this.fullname,
    required this.email,
    required this.canManageInterpreters,
    required this.canManageMissions,
    required this.isAdmin,
    required this.isInterpreter,
    this.rightsDisplay = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      username: json['username'] ?? '',
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      canManageInterpreters: json['can_manage_interpreters'] == true || json['can_manage_interpreters'] == "1" || json['can_manage_interpreters'] == 1,
      canManageMissions: json['can_manage_missions'] == true || json['can_manage_missions'] == "1" || json['can_manage_missions'] == 1,
      isAdmin: json['is_admin'] == true || json['is_admin'] == "1" || json['is_admin'] == 1,
      isInterpreter: json['is_interpreter'] == true || json['is_interpreter'] == "1" || json['is_interpreter'] == 1,
      rightsDisplay: (json['rights_display'] as List<dynamic>?) ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "fullname": fullname,
      "email": email,
      "can_manage_interpreters": canManageInterpreters ? 1 : 0,
      "can_manage_missions": canManageMissions ? 1 : 0,
      "is_admin": isAdmin ? 1 : 0,
      "is_interpreter": isInterpreter ? 1 : 0,
      "rights_display": rightsDisplay,
    };
  }
}