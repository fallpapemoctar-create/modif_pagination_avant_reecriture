import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mission_service.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import 'interpreter_missions_page.dart';

class MissionsPage extends StatefulWidget {
  final UserRights userRights;
  const MissionsPage({super.key, required this.userRights});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  late Future<List<Map<String, dynamic>>> _interpretersFuture;
  Future<List<Map<String, dynamic>>>? _detailFuture;

  final List<Map<String, dynamic>> _interpreters = [];
  final List<Map<String, dynamic>> _filtered = [];
  String _search = '';
  int? _selectedId;
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _interpretersFuture = MissionService.getInterpretersWithMissions();
    _interpretersFuture.then((list) {
      if (!mounted) return;
      setState(() {
        _interpreters
          ..clear()
          ..addAll(list);
        _applyFilter();
      });
    }).catchError((_) {});
  }

  void _applyFilter() {
    final q = _search.trim().toLowerCase();
    _filtered
      ..clear()
      ..addAll(q.isEmpty ? _interpreters : _interpreters.where((m) {
        final lastname = (m['lastname'] ?? '').toString().toLowerCase();
        final firstname = (m['firstname'] ?? '').toString().toLowerCase();
        final phone = (m['tel_mobile'] ?? m['telMobile'] ?? '').toString().toLowerCase();
        final combined = '$lastname $firstname';
        return combined.contains(q) || phone.contains(q);
      }).toList());
  }

  void _showMissionsFor(Map<String, dynamic> interp, BuildContext context) {
    final id = int.tryParse(interp['id']?.toString() ?? '') ?? 0;
    final name = '${interp['lastname'] ?? ''} ${interp['firstname'] ?? ''}'.trim();
    if (ResponsiveHelper.isDesktop(context)) {
      setState(() {
        _selectedId = id;
        _selectedName = name.isEmpty ? 'INCONNU' : name;
        _detailFuture = MissionService.getMissionsByInterpreter(id);
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InterpreterMissionsPage(
            interpreterId: id,
            interpreterName: name.isEmpty ? 'INCONNU' : name,
          ),
        ),
      );
    }
  }

  Future<void> _showMissionForm({Map<String, dynamic>? mission, required int interpreterId}) async {
    final isEdit = mission != null;
    final refCtrl = TextEditingController(text: mission?['reference_devis']?.toString() ?? '');
    final prodCtrl = TextEditingController(text: mission?['produit_ref']?.toString() ?? '');
    final debutCtrl = TextEditingController(text: mission?['debutmission']?.toString() ?? '');
    final finCtrl = TextEditingController(text: mission?['finmission']?.toString() ?? '');
    final montantCtrl = TextEditingController(text: mission?['montant_mission']?.toString() ?? '');
    bool paid = (mission?['status_payment']?.toString() == '1');

    final localContext = context;
    final ok = await showDialog<bool>(
      context: localContext,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Modifier la mission' : 'Ajouter une mission'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Référence')),
            TextField(controller: prodCtrl, decoration: const InputDecoration(labelText: 'Produit')),
            TextField(controller: debutCtrl, decoration: const InputDecoration(labelText: 'Début (YYYY-MM-DD)')),
            TextField(controller: finCtrl, decoration: const InputDecoration(labelText: 'Fin (YYYY-MM-DD)')),
            TextField(controller: montantCtrl, decoration: const InputDecoration(labelText: 'Montant')),
            StatefulBuilder(builder: (c, setSt) => CheckboxListTile(title: const Text('Payé'), value: paid, onChanged: (v) => setSt(() => paid = v ?? false))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'interpreter_id': interpreterId,
      'reference_devis': refCtrl.text.trim(),
      'produit_ref': prodCtrl.text.trim(),
      'debutmission': debutCtrl.text.trim(),
      'finmission': finCtrl.text.trim(),
      'montant_mission': montantCtrl.text.trim(),
      'status_payment': paid ? 1 : 0,
    };
    if (isEdit) payload['id'] = mission['id'];

    try {
      final success = isEdit ? await MissionService.updateMissionMap(payload) : await MissionService.addMissionMap(payload);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (success) {
        messenger.showSnackBar(const SnackBar(content: Text('Mission enregistrée')));
        if (_selectedId != null) setState(() => _detailFuture = MissionService.getMissionsByInterpreter(_selectedId!));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Erreur lors de l\'enregistrement')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.userRights.canManageMissions() || widget.userRights.isAdmin();
    final isWide = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Missions par interprètes')),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () {
                if (_selectedId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sélectionnez un interprète pour ajouter une mission')),
                  );
                  return;
                }
                _showMissionForm(interpreterId: _selectedId!);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: ResponsiveContainer(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _interpretersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _interpreters.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }

            final leftPanel = Container(
              width: isWide ? 360 : double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: isWide ? ResponsiveHelper.getBorderRadius(context) : null,
              ),
              child: Column(children: [
                Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      hintText: 'Rechercher...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: UnderlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() {
                      _search = v;
                      _applyFilter();
                    }),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: theme.colorScheme.primary),
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveHelper.getSpacing(context),
                    horizontal: ResponsiveHelper.getSpacing(context, mobile: 8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        'Nom Prenom',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.getFontSize(context, base: 13),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Center(
                        child: Text(
                          'Actions',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveHelper.getFontSize(context, base: 13),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, mobile: 4)),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('Aucun interprète avec mission'))
                      : ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 1,
                            color: theme.dividerColor,
                          ),
                          itemBuilder: (ctx, i) => _buildInterpreterRow(_filtered[i]),
                        ),
                ),
              ]),
            );

            final rightPanel = Expanded(child: _buildRightPane());

            return isWide
                ? Row(children: [
                    leftPanel,
                    SizedBox(width: ResponsiveHelper.getSpacing(context)),
                    rightPanel,
                  ])
                : Column(children: [Expanded(child: leftPanel)]);
          },
        ),
      ),
    );
  }

  Widget _buildInterpreterRow(Map<String, dynamic> interp) {
    final lastname = (interp['lastname'] ?? '').toString().trim();
    final firstname = (interp['firstname'] ?? '').toString().trim();
    final display = '${lastname.isEmpty ? 'INCONNU' : lastname} ${firstname.isEmpty ? '' : firstname}'.trim();
    final id = int.tryParse(interp['id']?.toString() ?? '') ?? -1;
    final selected = _selectedId == id;
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        hoverColor: theme.hoverColor,
        onTap: () => _showMissionsFor(interp, context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveHelper.getSpacing(context, mobile: 8),
            horizontal: ResponsiveHelper.getSpacing(context, mobile: 8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                display.toUpperCase(),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, base: 14),
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Container(width: 1, height: 28, color: theme.dividerColor),
            SizedBox(width: ResponsiveHelper.getSpacing(context)),
            SizedBox(
              width: 130,
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _showMissionsFor(interp, context),
                  icon: Icon(Icons.remove_red_eye, color: theme.colorScheme.primary),
                  label: Text('Consulter', style: TextStyle(color: theme.colorScheme.primary)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.getSpacing(context, mobile: 6),
                      vertical: ResponsiveHelper.getSpacing(context, mobile: 4),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRightPane() {
    if (_selectedId == null) {
      return const Center(
        child: Text('Sélectionnez un interprète (Consulter) pour voir ses missions'),
      );
    }

    final canManage = widget.userRights.canManageMissions() || widget.userRights.isAdmin();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        final missions = snapshot.data ?? [];
        if (missions.isEmpty) return const Center(child: Text('Aucune mission trouvée'));

        final currency = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
        final dateFmt = DateFormat('dd/MM/yyyy');

        Widget buildCard(Map<String, dynamic> m) {
          final montant = m['montant_mission'];
          final montantText = montant != null ? currency.format(num.tryParse(montant.toString()) ?? 0) : 'N/A';
          final paid = m['status_payment'] == 1 || m['status_payment']?.toString() == '1';
          final debut = DateTime.tryParse(m['debutmission']?.toString() ?? '');
          final fin = DateTime.tryParse(m['finmission']?.toString() ?? '');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(m['reference_devis'] ?? 'Sans référence', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (canManage)
                    Row(children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showMissionForm(mission: m, interpreterId: int.tryParse(m['nominterprete']?.toString() ?? '') ?? _selectedId ?? 0)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmer'),
                              content: const Text('Supprimer cette mission ?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                              ],
                            ),
                          );
                          if (!mounted) return;
                          if (confirm != true) return;
                          try {
                            final ok = await MissionService.deleteMission(int.tryParse(m['id']?.toString() ?? '') ?? 0);
                            if (!mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mission supprimée')));
                              setState(() => _detailFuture = MissionService.getMissionsByInterpreter(_selectedId!));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression')));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                          }
                        },
                      ),
                    ])
                ]),
                const SizedBox(height: 8),
                Text('Produit: ${m['produit_ref'] ?? m['ref'] ?? 'N/A'}'),
                Text('Début: ${debut != null ? dateFmt.format(debut) : (m['debutmission'] ?? 'N/A')}'),
                Text('Fin: ${fin != null ? dateFmt.format(fin) : (m['finmission'] ?? 'N/A')}'),
                const SizedBox(height: 6),
                Row(children: [Text('Montant: $montantText'), const SizedBox(width: 12), Chip(label: Text(paid ? 'Payé' : 'Non payé'), backgroundColor: paid ? Colors.green.shade100 : Colors.red.shade100)])
              ]),
            ),
          );
        }

        Widget buildTable() {
          final rows = missions.map((m) {
            final montant = m['montant_mission'];
            final montantText = montant != null ? currency.format(num.tryParse(montant.toString()) ?? 0) : 'N/A';
            final paid = m['status_payment'] == 1 || m['status_payment']?.toString() == '1';
            final debut = DateTime.tryParse(m['debutmission']?.toString() ?? '');
            final fin = DateTime.tryParse(m['finmission']?.toString() ?? '');

            final cells = <DataCell>[
              DataCell(Text(m['reference_devis'] ?? 'Sans référence')),
              DataCell(Text(m['produit_ref'] ?? m['ref'] ?? 'N/A')),
              DataCell(Text(debut != null ? dateFmt.format(debut) : (m['debutmission'] ?? 'N/A'))),
              DataCell(Text(fin != null ? dateFmt.format(fin) : (m['finmission'] ?? 'N/A'))),
              DataCell(Text(montantText)),
              DataCell(Chip(label: Text(paid ? 'Payé' : 'Non payé'), backgroundColor: paid ? Colors.green.shade100 : Colors.red.shade100)),
            ];

            if (canManage) {
              cells.add(DataCell(Row(children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showMissionForm(mission: m, interpreterId: int.tryParse(m['nominterprete']?.toString() ?? '') ?? _selectedId ?? 0)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirmer'),
                      content: const Text('Supprimer cette mission ?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (confirm != true) return;
                  try {
                    final ok = await MissionService.deleteMission(int.tryParse(m['id']?.toString() ?? '') ?? 0);
                    if (!mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mission supprimée')));
                      setState(() => _detailFuture = MissionService.getMissionsByInterpreter(_selectedId!));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }),
              ])));
            }

            return DataRow(cells: cells);
          }).toList();

          final columns = <DataColumn>[
            const DataColumn(label: Text('Référence')),
            const DataColumn(label: Text('Produit')),
            const DataColumn(label: Text('Début')),
            const DataColumn(label: Text('Fin')),
            const DataColumn(label: Text('Montant')),
            const DataColumn(label: Text('Paiement')),
          ];
          if (canManage) columns.add(const DataColumn(label: Text('Actions')));

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: columns, rows: rows),
            ),
          );
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Missions de $_selectedName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Expanded(child: LayoutBuilder(builder: (c, box) => box.maxWidth > 800 ? buildTable() : ListView.builder(itemCount: missions.length, itemBuilder: (ctx, i) => buildCard(missions[i])))),
        ]);
      },
    );
  }

}
