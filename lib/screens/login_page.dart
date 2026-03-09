// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/auth_manager.dart';
import '../core/user_rights.dart';
import 'home_page.dart';
import '../core/brand_footer.dart';

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
  bool rememberMe = false;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    rememberMe = AuthManager.rememberMe;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF6F6F6)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cadre de connexion
                Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'Se connecter',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: Color(0xFF161616),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Accédez à votre espace personnel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6A6A6A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      const Text(
                        'Identifiant',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF161616),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: loginCtrl,
                        decoration: InputDecoration(
                          hintText: 'Votre identifiant',
                          filled: true,
                          fillColor: const Color(0xFFF2F2F2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCFCFD3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF000091), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Identifiant obligatoire' : null,
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Mot de passe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF161616),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: !showPassword,
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          filled: true,
                          fillColor: const Color(0xFFF2F2F2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCFCFD3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF000091), width: 2),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => showPassword = !showPassword),
                            icon: Icon(
                              showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF6A6A6A),
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            onChanged: (val) => setState(() => rememberMe = val ?? false),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: const BorderSide(color: Color(0xFFCFCFD3)),
                            checkColor: Colors.white,
                            activeColor: const Color(0xFF000091),
                          ),
                          const Text(
                            'Rester connecté',
                            style: TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000091),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setState(() => loading = true);
                                  final data = await AuthService.login(loginCtrl.text, passCtrl.text);
                                  if (!mounted) return;
                                  setState(() => loading = false);

                                  if (data['success'] == true) {
                                    AuthManager.setUser(data['user']);
                                    AuthManager.setRights(UserRights(List<String>.from(data['rights'])));
                                    await AuthManager.persistSession(rememberMe: rememberMe);
                                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(data['message'] ?? 'Erreur de connexion')),
                                    );
                                  }
                                },
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE5E5EA)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF000091)),
                            child: const Text('Mot de passe oublié ?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // (Info band removed from inside the card per request)
                      ],
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const BrandFooter(),
        ],
      ),
    );
  }
}