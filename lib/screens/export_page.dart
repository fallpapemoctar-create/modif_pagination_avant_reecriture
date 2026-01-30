import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/responsive_helper.dart';
import '../core/brand_footer.dart';
import '../services/interpreter_service.dart';
import '../services/admin_service.dart';
import '../services/mission_service.dart';
import '../models/user.dart';

// Web-only download helpers
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _busy = false;
  String? _message;
  List<Map<String, dynamic>> _missions = [];
  int _page = 1;
  int _pageSize = 50;
  int _total = 0;
  final TextEditingController _searchCtrl = TextEditingController();

  void _setBusy(bool v, {String? msg}) {
    setState(() {
      _busy = v;
      _message = msg;
    });
  }

  Future<void> _exportInterpretersCsv() async {
    _setBusy(true, msg: 'Export des interprètes…');
    try {
      final list = await InterpreterService.getInterpreters();
      final rows = list.map((i) => {
            'id': i.id,
            'numero': i.numero,
            'nom': i.nom,
            'prenom': i.prenom,
            'email': i.email,
            'tel_mobile': i.telMobile,
            'tel_domicile': i.telDomicile,
            'langues_parlees': i.languesParlees,
            'adresse': i.adresse,
            'code_postal': i.codePostal,
            'ville': i.ville,
            'pays': i.pays,
            'commentaires': i.commentaires,
            'status': i.status,
          }).toList();
      final csv = _toCsv(rows);
      _downloadText('interpretes.csv', csv, 'text/csv');
      _setBusy(false, msg: 'Interprètes exportés');
    } catch (e) {
      _setBusy(false, msg: 'Erreur export interprètes: $e');
    }
  }

  Future<void> _exportUsersCsv() async {
    _setBusy(true, msg: 'Export des utilisateurs…');
    try {
      final map = await AdminService.getUsers();
      final users = (map['users'] as List<UserModel>);
      final rows = users.map((u) => {
            'id': u.id,
            'username': u.username,
            'fullname': u.fullname,
            'email': u.email,
            'is_interpreter': u.isInterpreter,
            'can_manage_interpreters': u.canManageInterpreters,
            'can_manage_missions': u.canManageMissions,
            'is_admin': u.isAdmin,
          }).toList();
      final csv = _toCsv(rows);
      _downloadText('utilisateurs.csv', csv, 'text/csv');
      _setBusy(false, msg: 'Utilisateurs exportés');
    } catch (e) {
      _setBusy(false, msg: 'Erreur export utilisateurs: $e');
    }
  }

  Future<void> _exportMissionsJson() async {
    _setBusy(true, msg: 'Export des missions…');
    try {
      final list = await MissionService.getInterpretersWithMissions();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
      _downloadText('missions.json', jsonStr, 'application/json');
      _setBusy(false, msg: 'Missions exportées');
    } catch (e) {
      _setBusy(false, msg: 'Erreur export missions: $e');
    }
  }

  Future<void> _loadMissionsForTable({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    _setBusy(true, msg: 'Chargement des missions…');
    final resp = await MissionService.getMissionsDatatable(page: _page, pageSize: _pageSize, q: _searchCtrl.text);
    final data = (resp['missions'] as List<Map<String, dynamic>>);
    setState(() {
      _missions = data;
      _total = (resp['total'] as int?) ?? data.length;
      _page = (resp['page'] as int?) ?? _page;
      _pageSize = (resp['pageSize'] as int?) ?? _pageSize;
      _busy = false;
      _message = 'Missions: ${data.length} / $_total';
    });
  }

  void _exportMissionsTableCsv() {
    if (_missions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune mission à exporter')));
      return;
    }
    // Select stable headers for CSV
    final headers = [
      'rowid', 'reference_devis', 'client_name', 'interpreter_name', 'debutmission_iso', 'produit_ref', 'id_produit_service'
    ];
    final rows = _missions.map((m) => {
      for (final h in headers) h: m[h]
    }).toList();
    final csv = _toCsv(rows);
    _downloadText('missions_table.csv', csv, 'text/csv');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // CSV helpers
  String _escapeCsv(dynamic value) {
    final s = value?.toString() ?? '';
    final needsQuote = s.contains(',') || s.contains('\n') || s.contains('"');
    var out = s.replaceAll('"', '""');
    if (needsQuote) out = '"$out"';
    return out;
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final headers = rows.first.keys.toList();
    final sb = StringBuffer();
    sb.writeln(headers.map(_escapeCsv).join(','));
    for (final r in rows) {
      sb.writeln(headers.map((h) => _escapeCsv(r[h])).join(','));
    }
    return sb.toString();
  }

  void _downloadText(String filename, String content, String mime) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export disponible sur la version web')),
      );
      return;
    }
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveHelper.getSpacing(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export de données')),
      body: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_message != null)
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportInterpretersCsv,
                  icon: const Icon(Icons.people),
                  label: const Text('Exporter Interprètes (CSV)'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportUsersCsv,
                  icon: const Icon(Icons.person),
                  label: const Text('Exporter Utilisateurs (CSV)'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportMissionsJson,
                  icon: const Icon(Icons.work),
                  label: const Text('Exporter Missions (JSON)'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _loadMissionsForTable,
                  icon: const Icon(Icons.table_rows),
                  label: const Text('Afficher Missions (DataTable)'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportMissionsTableCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('Exporter Tableau (CSV)'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () async {
                    _setBusy(true, msg: 'Export CSV (tout)…');
                    final all = await MissionService.getMissionsDatatableAll(q: _searchCtrl.text);
                    final headers = [
                      'rowid', 'reference_devis', 'client_name', 'interpreter_name', 'debutmission_iso', 'produit_ref', 'id_produit_service'
                    ];
                    final rows = all.map((m) => { for (final h in headers) h: m[h] }).toList();
                    final csv = _toCsv(rows);
                    _downloadText('missions_all.csv', csv, 'text/csv');
                    _setBusy(false, msg: 'CSV exporté (${rows.length} lignes)');
                  },
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('Exporter tout (CSV)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher (réf, client, interprète, produit)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _loadMissionsForTable(resetPage: true),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _pageSize,
                  items: const [10, 25, 50, 100, 200].map((v) => DropdownMenuItem(value: v, child: Text('Page: $v'))).toList(),
                  onChanged: _busy ? null : (v) { if (v != null) { setState(() { _pageSize = v; }); _loadMissionsForTable(resetPage: true); } },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _busy || _page <= 1 ? null : () { setState(() { _page -= 1; }); _loadMissionsForTable(); },
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Préc.'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _busy || (_page * _pageSize >= _total) ? null : () { setState(() { _page += 1; }); _loadMissionsForTable(); },
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Suiv.'),
                ),
                const SizedBox(width: 12),
                Text('Page $_page • Total $_total'),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Conseil: utilisez Chrome sur desktop pour télécharger les fichiers générés.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
              const BrandFooter(),
            if (_missions.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Ref Devis')),
                      DataColumn(label: Text('Client')),
                      DataColumn(label: Text('Interprète')),
                      DataColumn(label: Text('Début')),
                      DataColumn(label: Text('Produit')),
                      DataColumn(label: Text('Id Produit')),
                    ],
                    rows: _missions.map((m) {
                      final ref = (m['reference_devis'] ?? '').toString();
                      final client = (m['client_name'] ?? '').toString();
                      final interp = (m['interpreter_name'] ?? '').toString();
                      final debut = (m['debutmission_iso'] ?? m['debutmission'] ?? '').toString();
                      final prod = (m['produit_ref'] ?? '').toString();
                      final prodId = (m['id_produit_service'] ?? '').toString();
                      return DataRow(cells: [
                        DataCell(Text(ref)),
                        DataCell(Text(client)),
                        DataCell(Text(interp)),
                        DataCell(Text(debut)),
                        DataCell(Text(prod)),
                        DataCell(Text(prodId)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
