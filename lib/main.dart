import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';

import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/admin_mockup_preview.dart';
import 'screens/admin_page.dart';
import 'screens/export_page.dart';
import 'pages/interpreters_page.dart';
import 'pages/billing_page.dart';
import 'pages/missions_table_page.dart';
import 'pages/company_info_page.dart';
import 'pages/requesters_management_page.dart';
import 'core/auth_manager.dart';

// ── Thème actif — changer ici pour basculer : bleuOfficiel / ardoise / nuit
const AmiThemeId kActiveTheme = AmiThemeId.nuit;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await AuthManager.restoreSession();
  runApp(MyApp(startOnHome: AuthManager.isLogged));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.startOnHome});

  final bool startOnHome;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AMI - Assistance missions interprètes',
      theme: AmiTheme.of(kActiveTheme),
      home: startOnHome ? const HomePage() : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin-mockup': (context) => const AdminMockupPreview(),
        '/interpreters': (context) =>
            InterpretersPage(userRights: AuthManager.userRights),
        '/missions-table': (context) =>
            MissionsTablePage(userRights: AuthManager.userRights),
        '/billing': (context) =>
            BillingPage(userRights: AuthManager.userRights),
        '/admin': (context) => AdminPage(userRights: AuthManager.userRights),
        '/export': (context) => const ExportPage(),
        '/company-info': (context) =>
            CompanyInfoPage(userRights: AuthManager.userRights),
        '/requesters': (context) =>
            RequestersManagementPage(userRights: AuthManager.userRights),
      },
    );
  }
}
