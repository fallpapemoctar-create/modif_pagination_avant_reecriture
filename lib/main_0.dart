import 'package:flutter/material.dart';
import '/pages/interpreters_page.dart';
import '/core/user_rights.dart';





void main() {
  // Exemple : l’utilisateur a les droits admin_annuaire
  final rights = UserRights(["agent_admin_annuaire"]);

  runApp(MyApp(rights: rights));
}

class MyApp extends StatelessWidget {
  final UserRights rights;

  const MyApp({super.key, required this.rights});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gesplanet',
      home: InterpretersPage(userRights: rights),
    );
  }
}