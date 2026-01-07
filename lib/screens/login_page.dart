// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/auth_manager.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final loginCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ResponsiveHelper.isMobile(context) ? 60 : 68,
        title: Row(
          children: [
            // Logo in circular layout (falls back to an Icon if asset missing)
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: ResponsiveHelper.isMobile(context) ? 36 : 40,
                height: ResponsiveHelper.isMobile(context) ? 36 : 40,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: ResponsiveHelper.isMobile(context) ? 36 : 40,
                  height: ResponsiveHelper.isMobile(context) ? 36 : 40,
                  color: Colors.transparent,
                  child: Icon(Icons.language, 
                    size: ResponsiveHelper.isMobile(context) ? 24 : 28),
                ),
              ),
            ),
            SizedBox(width: ResponsiveHelper.getSpacing(context)),
            Text('Gesplanet', 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveHelper.getFontSize(context, base: 18),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ResponsiveContainer(
          maxWidth: ResponsiveHelper.isMobile(context) ? double.infinity : 500,
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getPagePadding(context),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Connexion",
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, base: 24),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context) * 2),

                  // login
                  TextFormField(
                    controller: loginCtrl,
                    decoration: const InputDecoration(
                      labelText: "login",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "login obligatoire" : null,
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context)),

                  // Mot de passe
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Mot de passe",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Mot de passe obligatoire" : null,
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context) * 2),

                  // Bouton
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.isMobile(context) ? 48 : 52,
                    child: ElevatedButton(
                      onPressed: loading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setState(() => loading = true);

                              final data = await AuthService.login(loginCtrl.text, passCtrl.text);

                              if (!mounted) return;

                              setState(() => loading = false);

                              if (data["success"] == true) {
                                // Charger l'utilisateur
                                AuthManager.setUser(data["user"]);

                                // Charger les droits
                                AuthManager.setRights(
                                  UserRights(List<String>.from(data["rights"])),
                                );

                                // Aller à la HomePage
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const HomePage()),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        data["message"] ?? "Erreur de connexion"),
                                  ),
                                );
                              }
                            },
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Se connecter"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}