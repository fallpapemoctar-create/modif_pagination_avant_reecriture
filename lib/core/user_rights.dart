class UserRights {
  final List<String> rights;

  UserRights(this.rights);

    List<String> get codes => List.unmodifiable(rights);

  bool isAdmin() =>
      rights.contains('admin') || rights.contains('agent_admin');

  bool canManageInterpreters() =>
      isAdmin() || rights.contains('agent_admin_annuaire');

  bool canManageMissions() =>
      isAdmin() || rights.contains('agent_admin_mission');

  bool isInterpreter() =>
      rights.contains('interprete');
}