import 'package:flutter/material.dart';
import 'core/app_config.dart';

import 'screens/login_page.dart';
import 'screens/admin_mockup_preview.dart';
import 'screens/admin_page.dart';
import 'screens/export_page.dart';
import 'pages/interpreters_page.dart';
import 'pages/missions_page.dart';
import 'core/auth_manager.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AMI - Assistance missions interprètes',
      theme: ThemeData(
        primaryColor: const Color(0xFF000091), // Bleu France
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF000091),
          primary: const Color(0xFF000091),
          secondary: const Color(0xFFE1000F), // Rouge Marianne
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF000091),
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF000091)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000091),
            foregroundColor: Colors.white,
          ),
        ),
        fontFamily: 'Marianne', // Utilise Marianne si disponible
      ),
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin-mockup': (context) => const AdminMockupPreview(),
        '/interpreters': (context) => InterpretersPage(userRights: AuthManager.userRights),
        '/missions': (context) => MissionsPage(userRights: AuthManager.userRights),
        '/admin': (context) => AdminPage(userRights: AuthManager.userRights),
        '/export': (context) => const ExportPage(),
      },
    );
  }
}