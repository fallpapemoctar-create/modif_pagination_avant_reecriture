import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../core/auth_manager.dart';
import 'admin_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }

            final summary = (snapshot.data?['summary'] as Map<String, dynamic>?) ?? {};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _statCard('Total utilisateurs', summary['total_users']?.toString() ?? '0'),
                    const SizedBox(width: 12),
                    _statCard('Utilisateurs actifs', summary['active_users']?.toString() ?? '0'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statCard('Gestionnaires interprètes', summary['interpreters_count']?.toString() ?? '0'),
                    const SizedBox(width: 12),
                    _statCard('Gestionnaires missions', summary['missions_count']?.toString() ?? '0'),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminPage(userRights: AuthManager.userRights)),
                  ),
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Gérer les utilisateurs'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
