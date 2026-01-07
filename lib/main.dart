import 'package:flutter/material.dart';

import 'screens/login_page.dart';
import 'screens/admin_mockup_preview.dart';
import 'screens/admin_page.dart';
import 'pages/interpreters_page.dart';
import 'pages/missions_page.dart';
import 'core/auth_manager.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin-mockup': (context) => const AdminMockupPreview(),
        '/interpreters': (context) => InterpretersPage(userRights: AuthManager.userRights),
        '/missions': (context) => MissionsPage(userRights: AuthManager.userRights),
        '/admin': (context) => AdminPage(userRights: AuthManager.userRights),
      },
    );
  }
}