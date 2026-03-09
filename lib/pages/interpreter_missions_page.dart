import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/mission_service.dart';

class InterpreterMissionsPage extends StatefulWidget {
  final int interpreterId;
  final String interpreterName;

  const InterpreterMissionsPage({
    super.key,
    required this.interpreterId,
    required this.interpreterName,
  });

  @override
  State<InterpreterMissionsPage> createState() =>
      _InterpreterMissionsPageState();
}

class _InterpreterMissionsPageState extends State<InterpreterMissionsPage> {
  late Future<List<Map<String, dynamic>>> _futureMissions;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    if (value is DateTime) return _dateFormat.format(value);
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return _dateFormat.format(parsed);
    return value.toString();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  int? _filterYear;
  int? _filterMonth;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  void _loadMissions() {
    _futureMissions = MissionService.getMissionsByInterpreter(
      widget.interpreterId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Missions de ${widget.interpreterName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureMissions,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }

            final missions = snapshot.data ?? [];

            if (missions.isEmpty) {
              return const Center(
                child: Text('Aucune mission trouvée pour cet interprète.'),
              );
            }

            // derive available years
            final years = <int>{};
            for (final m in missions) {
              final dt = _parseDate(m['debutmission']);
              if (dt != null) years.add(dt.year);
            }
            final yearList = years.toList()..sort((a, b) => b.compareTo(a));

            final months = List<int>.generate(12, (i) => i + 1);

            final filtered = missions.where((m) {
              final dt = _parseDate(m['debutmission']);
              if (dt == null) return true;
              if (_filterYear != null && dt.year != _filterYear) return false;
              if (_filterMonth != null && dt.month != _filterMonth) {
                return false;
              }
              return true;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    DropdownButton<int?>(
                      value: _filterYear,
                      hint: const Text('Année'),
                        isDense: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Toutes'),
                        ),
                        ...yearList.map(
                          (y) => DropdownMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterYear = v),
                      ),
                      const SizedBox(width: 8),
                    DropdownButton<int?>(
                      value: _filterMonth,
                      hint: const Text('Mois'),
                        isDense: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tous'),
                        ),
                        ...months.map(
                          (m) => DropdownMenuItem<int?>(
                            value: m,
                            child: Text(
                              DateFormat.MMMM('fr_FR').format(DateTime(0, m)),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterMonth = v),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _filterYear = null;
                          _filterMonth = null;
                        }),
                        icon: const Icon(Icons.clear, color: Color(0xFF000091)),
                        label: const Text(
                          'Réinitialiser',
                          style: TextStyle(color: Color(0xFF000091)),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return isWide
                          ? _buildTableView(filtered)
                          : _buildListView(filtered);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> missions) {
    final filtered = missions.where((m) {
      final dt = _parseDate(m['debutmission']);
      if (dt == null) return true;
      if (_filterYear != null && dt.year != _filterYear) return false;
      if (_filterMonth != null && dt.month != _filterMonth) return false;
      return true;
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, index) {
        final mission = filtered[index];

        final ref = (mission['reference_devis'] ?? '')?.toString() ?? '';
        final canCopyRef =
            ref.trim().isNotEmpty && ref != 'Sans référence' && ref != 'N/A';

        return Card(
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(ref.isNotEmpty ? ref : 'Sans référence')),
                if (canCopyRef)
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: Color(0xFF000091),
                    ),
                    tooltip: 'Copier la référence',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(ctx);
                      await Clipboard.setData(ClipboardData(text: ref));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Référence copiée')),
                      );
                    },
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Produit: ${mission['ref'] ?? 'N/A'}'),
                Text('Début: ${_formatDate(mission['debutmission'])}'),
                Text('Fin: ${_formatDate(mission['finmission'])}'),
                Row(
                  children: [
                    Builder(builder: (context) {
                      final billed = mission['billed_status']?.toString();
                      final hasBilled = billed != null && billed.trim().isNotEmpty;
                      return Chip(
                        label: Text(hasBilled ? billed : 'Statut non renseigné'),
                        backgroundColor: Colors.blueGrey.shade100,
                        labelStyle: TextStyle(color: Colors.blueGrey.shade800),
                      );
                    }),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildTableView(List<Map<String, dynamic>> missions) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Référence')),
            DataColumn(label: Text('Produit')),
            DataColumn(label: Text('Début')),
            DataColumn(label: Text('Fin')),
            DataColumn(label: Text('Paiement')),
          ],
          rows: missions.map((mission) {

            final ref = (mission['reference_devis'] ?? '')?.toString() ?? '';
            final canCopyRef =
                ref.trim().isNotEmpty &&
                ref != 'Sans référence' &&
                ref != 'N/A';

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      Expanded(child: Text(ref.isNotEmpty ? ref : 'N/A')),
                      if (canCopyRef)
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            size: 18,
                            color: Color(0xFF000091),
                          ),
                          tooltip: 'Copier',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: ref));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Référence copiée'),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                DataCell(Text(mission['ref'] ?? 'N/A')),
                DataCell(Text(_formatDate(mission['debutmission']))),
                DataCell(Text(_formatDate(mission['finmission']))),
                DataCell(Row(children: [
                  Builder(builder: (context) {
                    final billed = mission['billed_status']?.toString();
                    final hasBilled = billed != null && billed.trim().isNotEmpty;
                    return Chip(
                      label: Text(hasBilled ? billed : 'Statut non renseigné'),
                      backgroundColor: Colors.blueGrey.shade100,
                      labelStyle: TextStyle(color: Colors.blueGrey.shade800),
                    );
                  }),
                ])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
