// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/auth_manager.dart';
import '../core/user_rights.dart';
import '../core/app_theme.dart';
import '../main.dart' show kActiveTheme;
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool _loading      = false;
  bool _rememberMe   = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _rememberMe = AuthManager.rememberMe;
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final data = await AuthService.login(_loginCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (data['success'] == true) {
      AuthManager.setUser(data['user']);
      AuthManager.setRights(UserRights(List<String>.from(data['rights'])));
      await AuthManager.persistSession(rememberMe: _rememberMe);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Erreur de connexion')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: AmiTheme.bgLight,
      body: isDesktop ? _desktopLayout() : _mobileLayout(),
    );
  }

  // ── DESKTOP : deux colonnes ───────────────────────────────────────────────
  Widget _desktopLayout() {
    return Row(
      children: [
        // ── Panneau gauche — hero gradient ──
        Expanded(
          flex: 38,
          child: Container(
            decoration: BoxDecoration(
              gradient: AmiTheme.heroGradient(kActiveTheme),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stk) => const Icon(
                      Icons.translate,
                      size: 40,
                      color: Color(0xFF1B3A8C),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AMI',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Assistance Missions Interprètes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xCCFFFFFF),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 48),
                // Badges fonctionnalités
                _heroBadge(Icons.people_outline,       'Gestion des interprètes'),
                const SizedBox(height: 12),
                _heroBadge(Icons.table_chart_outlined,  'Suivi des missions'),
                const SizedBox(height: 12),
                _heroBadge(Icons.receipt_long_outlined, 'Facturation et devis'),
              ],
            ),
          ),
        ),

        // ── Panneau droit — formulaire ──
        Expanded(
          flex: 62,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _formCard(compact: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MOBILE : centré, plein écran ─────────────────────────────────────────
  Widget _mobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mini hero mobile
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              gradient: AmiTheme.heroGradient(kActiveTheme),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stk) => const Icon(
                      Icons.translate, size: 32, color: Color(0xFF1B3A8C)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('AMI',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                const Text('Assistance Missions Interprètes',
                    style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _formCard(compact: true),
          ),
        ],
      ),
    );
  }

  // ── Formulaire commun ─────────────────────────────────────────────────────
  Widget _formCard({required bool compact}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connexion',
            style: TextStyle(
              fontSize: compact ? 20 : 22,   // 28 → 20/22
              fontWeight: FontWeight.w700,
              color: const Color(0xFF161616),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Accédez à votre espace personnel',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 28),

          // ── Identifiant ──
          const Text('Identifiant',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginCtrl,
            autofocus: !compact,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Votre identifiant',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Identifiant obligatoire' : null,
          ),
          const SizedBox(height: 16),

          // ── Mot de passe ──
          const Text('Mot de passe',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _loading ? null : _submit(),
            decoration: InputDecoration(
              hintText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF6A6A6A),
                ),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe obligatoire' : null,
          ),
          const SizedBox(height: 12),

          // ── Rester connecté ──
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Rester connecté',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ],
          ),
          const SizedBox(height: 20),

          // ── Bouton ──
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                elevation: 0,
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Se connecter',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge hero (panneau gauche desktop) ──────────────────────────────────
  Widget _heroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.90)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.90),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
