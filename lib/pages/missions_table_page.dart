import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/brand_footer.dart';
import '../core/file_downloader.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../services/mission_service.dart';
import 'billing_page.dart';

class MissionsTablePage extends StatefulWidget {
  final UserRights userRights;
  const MissionsTablePage({super.key, required this.userRights});

  @override
  State<MissionsTablePage> createState() => _MissionsTablePageState();
}

class _MissionsTablePageState extends State<MissionsTablePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _hScrollCtrl = ScrollController();
  final ScrollController _vScrollCtrl = ScrollController();
  static const Color _primaryBlue = Color(0xFF000091);

  List<Map<String, dynamic>> _missions = [];
  int _total = 0;
  int _page = 1;
  int _pageSize = 25;
  bool _busy = false;

  String _statusFilter = 'Tous';
  final List<String> _statusOptions = const [
    'Tous',
    'À facturer',
    'Facturé',
    'Payé',
  ];

  // Workflow (mission_status) filter
  String _workflowFilter = 'Tous';
  List<String> _workflowOptions = ['Tous'];
  // Human-readable labels for workflow status
  final Map<String, String> _workflowLabels = const {
    '0': 'Brouillon',
    '1': 'Planifiée',
    '2': 'En cours',
    '3': 'Terminée',
    '4': 'Annulée',
  };
  String _labelForStatus(String code) {
    final c = code.trim();
    if (c.isEmpty || c == 'Tous') return 'Tous';
    return _workflowLabels[c] ?? code;
  }

  String _labelForBillingFilter(String value) {
    return value == 'Tous' ? 'Statut facture: Tous' : value;
  }

  final Map<String, bool> _visibleColumns = {
    // Show only the first 10 table columns by default
    // Order: ref, refmission, langue, datemission, heuredebut, duree,
    //        societe, demandeur, interprete, label
    'ref': true,
    'refmission': true,
    'langue': true,
    'datemission': true,
    'heuredebut': true,
    'duree': true,
    'societe': true,
    'demandeur': true,
    'interprete': true,
    'label': true,
    // Remaining columns are hidden by default and can be enabled in the picker
    'telephone': false,
    'mobile': false,
    'devis': false,
    'facture': false,
    'montant': false,
    'statut': false,
    'createur': false,
    'datecrea': false,
    'dateModif': false,
    'modifiePar': false,
    // Keep actions visible by default for edit/delete
    'actions': true,
  };

  final Set<int> _selectedRowIds = <int>{};
  // Global selection across all filtered pages
  bool _selectAllAcrossFilters = false;
  // Exceptions when global select-all is active
  final Set<int> _deselectedRowIds = <int>{};
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // Date mission filters
  String _dateFilter = 'Tous';
  final List<String> _dateFilterOptions = const [
    'Tous',
    'Aujourd\'hui',
    'Cette semaine',
    'Ce mois',
  ];
  DateTime? _dateStart;
  DateTime? _dateEnd;

  @override
  void initState() {
    super.initState();
    _load(resetPage: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    setState(() {
      if (resetPage) _page = 1;
      _busy = true;
    });
    final resp = await MissionService.getMissionsDatatable(
      page: _page,
      pageSize: _pageSize,
      q: _searchCtrl.text,
    );
    final data = (resp['missions'] as List<Map<String, dynamic>>);
    // Build workflow options from loaded data
    final wfSet = <String>{};
    for (final m in data) {
      final v = (m['mission_status'] ?? '').toString().trim();
      if (v.isNotEmpty) wfSet.add(v);
    }
    final wfList = wfSet.toList()..sort((a, b) {
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.compareTo(b);
    });
    setState(() {
      _missions = data;
      _total = (resp['total'] as int?) ?? data.length;
      _page = (resp['page'] as int?) ?? _page;
      _pageSize = (resp['pageSize'] as int?) ?? _pageSize;
      _busy = false;
      _workflowOptions = ['Tous', ...wfList];
    });
    // Apply default sort: Date mission DESC, then Heure début mission DESC
    _applyDefaultSortByDateHeure();
  }

  List<Map<String, dynamic>> _filtered() {
    final base = _missions;
    List<Map<String, dynamic>> list = base;
    if (_statusFilter != 'Tous') {
      list = list.where((m) {
        final st = (m['billed_status'] ?? '').toString().toLowerCase().trim();
        switch (_statusFilter) {
          case 'À facturer':
            return st.isEmpty ||
                st.contains('a facturer') ||
                st.contains('à facturer');
          case 'Facturé':
            return st.contains('factur');
          case 'Payé':
            return st.contains('pay');
        }
        return true;
      }).toList();
    }
    if (_workflowFilter != 'Tous') {
      list = list.where((m) {
        final st = (m['mission_status'] ?? '').toString().trim();
        return st == _workflowFilter;
      }).toList();
    }
    if (_dateStart != null && _dateEnd != null) {
      list = list.where(_matchesDateRange).toList();
    } else if (_dateFilter != 'Tous') {
      list = list.where(_matchesDateFilter).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> _selectedMissionsForBilling() {
    final filtered = _filtered();
    if (_selectAllAcrossFilters) {
      if (_deselectedRowIds.isEmpty) return filtered;
      return filtered.where((mission) {
        final id = int.tryParse((mission['rowid'] ?? '0').toString()) ?? -1;
        return !_deselectedRowIds.contains(id);
      }).toList();
    }
    if (_selectedRowIds.isEmpty) return const <Map<String, dynamic>>[];
    return filtered.where((mission) {
      final id = int.tryParse((mission['rowid'] ?? '0').toString()) ?? -1;
      return _selectedRowIds.contains(id);
    }).toList();
  }

  void _sortByString(
    String Function(Map<String, dynamic>) selector,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _missions.sort((a, b) {
        final av = selector(a);
        final bv = selector(b);
        final cmp = av.compareTo(bv);
        return ascending ? cmp : -cmp;
      });
    });
  }

  void _sortByDate(
    String Function(Map<String, dynamic>) selector,
    int columnIndex,
    bool ascending,
  ) {
    DateTime? parse(String s) {
      try {
        return DateTime.tryParse(s);
      } catch (_) {
        return null;
      }
    }

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _missions.sort((a, b) {
        final av = parse(selector(a));
        final bv = parse(selector(b));
        int cmp;
        if (av == null && bv == null) {
          cmp = 0;
        } else if (av == null) {
          cmp = -1;
        } else if (bv == null) {
          cmp = 1;
        } else {
          cmp = av.compareTo(bv);
        }
        return ascending ? cmp : -cmp;
      });
    });
  }

  void _sortByNum(
    num Function(Map<String, dynamic>) selector,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _missions.sort((a, b) {
        final av = selector(a);
        final bv = selector(b);
        final cmp = av.compareTo(bv);
        return ascending ? cmp : -cmp;
      });
    });
  }

  bool _matchesDateFilter(Map<String, dynamic> m) {
    final s = (m['datemission_iso'] ?? m['datemission'] ?? m['debutmission_iso'] ?? m['debutmission'] ?? '').toString();
    DateTime? d;
    try {
      d = DateTime.tryParse(s);
    } catch (_) {}
    if (d == null) return false;
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'Aujourd\'hui':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'Cette semaine':
        final int weekday = now.weekday; // 1 Mon .. 7 Sun
        final DateTime weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
        final DateTime weekEnd = weekStart.add(const Duration(days: 7));
        return !d.isBefore(weekStart) && d.isBefore(weekEnd);
      case 'Ce mois':
        final DateTime monthStart = DateTime(now.year, now.month, 1);
        final DateTime monthEnd = DateTime(now.year, now.month + 1, 1);
        return !d.isBefore(monthStart) && d.isBefore(monthEnd);
    }
    return true;
  }

  bool _matchesDateRange(Map<String, dynamic> m) {
    if (_dateStart == null || _dateEnd == null) return true;
    final s = (m['datemission_iso'] ?? m['datemission'] ?? m['debutmission_iso'] ?? m['debutmission'] ?? '').toString();
    DateTime? d;
    try {
      d = DateTime.tryParse(s);
    } catch (_) {}
    if (d == null) return false;
    final DateTime start = DateTime(_dateStart!.year, _dateStart!.month, _dateStart!.day);
    final DateTime endNext = DateTime(_dateEnd!.year, _dateEnd!.month, _dateEnd!.day).add(const Duration(days: 1));
    return !d.isBefore(start) && d.isBefore(endNext);
  }

  Future<void> _pickDateRange() async {
    final initialRange = (_dateStart != null && _dateEnd != null)
        ? DateTimeRange(start: _dateStart!, end: _dateEnd!)
        : null;
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year - 5, 1, 1);
    final DateTime last = DateTime(now.year + 5, 12, 31);
    final DateTimeRange? rng = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: initialRange,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Filtrer par période (Date mission)',
    );
    if (rng == null) return;
    if (!mounted) return;
    setState(() {
      _dateStart = rng.start;
      _dateEnd = rng.end;
      _dateFilter = 'Tous'; // Clear quick chip when a custom range is set
    });
  }

  int? _getColumnIndexByKey(String key) {
    // Accounts for the first selection column at index 0
    int idx = 1;
    bool check(String k) {
      final v = _visibleColumns[k] ?? (k == 'ref' || k == 'refmission' || k == 'langue' || k == 'datemission' || k == 'heuredebut' || k == 'duree' || k == 'societe' || k == 'demandeur' || k == 'interprete' || k == 'label' || k == 'telephone' || k == 'mobile' || k == 'devis' || k == 'facture' || k == 'montant' || k == 'statut' || k == 'createur' || k == 'datecrea' || k == 'actions');
      return v;
    }

    if (check('ref')) {
      if (key == 'ref') return idx; idx++;
    }
    if (check('refmission')) {
      if (key == 'refmission') return idx; idx++;
    }
    if (check('langue')) {
      if (key == 'langue') return idx; idx++;
    }
    if (check('datemission')) {
      if (key == 'datemission') return idx; idx++;
    }
    if (check('heuredebut')) {
      if (key == 'heuredebut') return idx; idx++;
    }
    if (check('duree')) {
      if (key == 'duree') return idx; idx++;
    }
    if (check('societe')) {
      if (key == 'societe') return idx; idx++;
    }
    if (check('demandeur')) {
      if (key == 'demandeur') return idx; idx++;
    }
    if (check('interprete')) {
      if (key == 'interprete') return idx; idx++;
    }
    if (check('label')) {
      if (key == 'label') return idx; idx++;
    }
    if (check('telephone')) {
      if (key == 'telephone') return idx; idx++;
    }
    if (check('mobile')) {
      if (key == 'mobile') return idx; idx++;
    }
    if (check('devis')) {
      if (key == 'devis') return idx; idx++;
    }
    if (check('facture')) {
      if (key == 'facture') return idx; idx++;
    }
    if (check('montant')) {
      if (key == 'montant') return idx; idx++;
    }
    if (check('statut')) {
      if (key == 'statut') return idx; idx++;
    }
    if (check('interprete')) {
      // already handled above
    }
    if (check('createur')) {
      if (key == 'createur') return idx; idx++;
    }
    if (check('datecrea')) {
      if (key == 'datecrea') return idx; idx++;
    }
    if (check('dateModif')) {
      if (key == 'dateModif') return idx; idx++;
    }
    if (check('modifiePar')) {
      if (key == 'modifiePar') return idx; idx++;
    }
    if (check('actions')) {
      if (key == 'actions') return idx; idx++;
    }
    return null;
  }

  void _applyDefaultSortByDateHeure() {
    // Sort by datemission DESC, then heuredebutmission DESC, and show indicator
    DateTime? parseDate(String s) {
      try {
        return DateTime.tryParse(s);
      } catch (_) {
        return null;
      }
    }
    final dateIdx = _getColumnIndexByKey('datemission');
    final heureIdx = _getColumnIndexByKey('heuredebut');
    setState(() {
      _sortColumnIndex = dateIdx ?? heureIdx; // show indicator where possible
      _sortAscending = false;
      _missions.sort((a, b) {
        final ad = parseDate(
            (a['datemission_iso'] ?? a['datemission'] ?? '').toString());
        final bd = parseDate(
            (b['datemission_iso'] ?? b['datemission'] ?? '').toString());
        int cmpDate;
        if (ad == null && bd == null) {
          cmpDate = 0;
        } else if (ad == null) {
          cmpDate = -1;
        } else if (bd == null) {
          cmpDate = 1;
        } else {
          cmpDate = ad.compareTo(bd);
        }
        if (cmpDate != 0) return -cmpDate; // DESC on date
        // Secondary: heuredebutmission DESC (string compare)
        final ah = (a['heuredebutmission'] ?? '').toString();
        final bh = (b['heuredebutmission'] ?? '').toString();
        final cmpHeure = ah.compareTo(bh);
        return -cmpHeure; // DESC on time string
      });
    });
  }

  String _escapeCsv(dynamic value) {
    final s = value?.toString() ?? '';
    final needsQuote = s.contains(',') || s.contains('\n') || s.contains('"');
    var out = s.replaceAll('"', '""');
    if (needsQuote) out = '"$out"';
    return out;
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _exportFilteredCsv() async {
    // Fetch all missions matching the current search, then apply status filter locally
    final all = await MissionService.getMissionsDatatableAll(
      q: _searchCtrl.text,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final rows = () {
      if (_statusFilter == 'Tous') return all;
      var filtered = all.where((m) {
        final st = (m['billed_status'] ?? '').toString().toLowerCase().trim();
        switch (_statusFilter) {
          case 'À facturer':
            return st.isEmpty ||
                st.contains('a facturer') ||
                st.contains('à facturer');
          case 'Facturé':
            return st.contains('factur');
          case 'Payé':
            return st.contains('pay');
        }
        return true;
      }).toList();
      if (_dateStart != null && _dateEnd != null) {
        filtered = filtered.where(_matchesDateRange).toList();
      } else if (_dateFilter != 'Tous') {
        filtered = filtered.where(_matchesDateFilter).toList();
      }
      return filtered;
    }();
    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Aucune mission à exporter')),
      );
      return;
    }
    final headers = [
      'Id. mission',
      'Ref. mission',
      'Libellé',
      'Langue',
      'Date mission',
      'Heure de début',
      'Durée',
      'Montant mission (€)',
      'Société Demandeur',
      'Demandeur',
      'Tel. Demandeur',
      'Mobile Demandeur',
      'Statut (workflow)',
      'Statut facturation',
      'Interprète',
      'Date création',
      'Créé par',
      'Date modification',
      'Mis à jour par',
    ];
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final m in rows) {
          final dateMission = (m['datemission'] ?? '').toString();
          final heureDebut = (m['heuredebutmission'] ?? '').toString();
      final duree = (m['dureemission'] ?? '').toString();
      final values = [
        m['rowid'],
        m['reference_devis'],
        m['label'],
        m['produit_ref'],
        dateMission,
        heureDebut,
        duree,
        m['montant_mission'],
        m['client_name'],
        ('${((m['prenom_demandeur'] ?? '') as String).trim()} ${((m['nom_demandeur'] ?? '') as String).trim()}')
            .trim(),
        m['phone'],
        m['phone_mobile'],
        m['mission_status'],
        m['billed_status'],
        m['interpreter_name'],
        (m['date_creation_iso'] ?? m['date_creation'] ?? ''),
        m['creator_name'],
        (m['date_modification_iso'] ?? m['date_modification'] ?? ''),
        (m['updated_by'] ?? ''),
      ].map(_escapeCsv).join(',');
      buffer.writeln(values);
    }
    final content = buffer.toString();
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      await downloadBytes(
        bytes: bytes,
        filename: 'missions_filtrees.csv',
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('CSV exporté (${rows.length} lignes)')),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('CSV généré'),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showEditMissionDialog(Map<String, dynamic> m) async {
    // Prepare controllers for raw fields
    final TextEditingController langueCtrl =
      TextEditingController(text: (m['produit_ref'] ?? '').toString());
    final TextEditingController dateCtrl =
      TextEditingController(text: (m['datemission'] ?? '').toString());
    final TextEditingController heureCtrl =
      TextEditingController(text: (m['heuredebutmission'] ?? '').toString());
    final TextEditingController dureeCtrl =
      TextEditingController(text: (m['dureemission'] ?? '').toString());

    // Fetch interpreters list (id + display_name)
    final interpretes = await MissionService.getInterpretes();
    if (!mounted) return;
    int? selectedInterpreterId = int.tryParse((m['nominterprete'] ?? '').toString());
    final currentInterpreterName = (m['interpreter_name'] ?? '').toString().trim();
    // Workflow status options: union between known labels, loaded filters, and the mission value
    final rawStatus = (m['mission_status'] ?? '').toString().trim();
    final statusCodeSet = <String>{
      ..._workflowLabels.keys,
      ..._workflowOptions.where((code) => code != 'Tous'),
    }..add(rawStatus);
    int compareStatus(String a, String b) {
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      if (ai != null) return -1;
      if (bi != null) return 1;
      return a.compareTo(b);
    }
    final List<String> statusCodes = statusCodeSet
        .where((code) => code.trim().isNotEmpty)
        .toList()
      ..sort(compareStatus);
    String selectedStatusCode = rawStatus;
    if (selectedStatusCode.isEmpty && statusCodes.isNotEmpty) {
      selectedStatusCode = statusCodes.first;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Modifier la mission'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Interpreter select box
                    DropdownButtonFormField<int>(
                      initialValue: selectedInterpreterId,
                      items: () {
                        final items = interpretes.map((e) {
                          final id = int.tryParse((e['id'] ?? '').toString());
                          final name = (e['display_name'] ?? '').toString();
                          if (id == null) return null;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(name.isEmpty ? 'Interprète #$id' : name),
                          );
                        }).whereType<DropdownMenuItem<int>>().toList();
                        if (selectedInterpreterId != null &&
                            !items.any((item) => item.value == selectedInterpreterId)) {
                          final fallbackLabel = currentInterpreterName.isEmpty
                              ? 'Interprète #${selectedInterpreterId!}'
                              : '$currentInterpreterName (hors liste)';
                          items.insert(
                            0,
                            DropdownMenuItem<int>(
                              value: selectedInterpreterId,
                              child: Text(fallbackLabel),
                            ),
                          );
                        }
                        return items;
                      }(),
                      onChanged: (v) => setLocal(() => selectedInterpreterId = v),
                      decoration: const InputDecoration(
                        labelText: 'Interprète',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Workflow status select box
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatusCode.isEmpty ? null : selectedStatusCode,
                      items: statusCodes.map((code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(_labelForStatus(code)),
                      )).toList(),
                      onChanged: (v) => setLocal(() => selectedStatusCode = v ?? selectedStatusCode),
                      decoration: const InputDecoration(
                        labelText: 'Statut (workflow)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: langueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Langue (ref produit)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date mission (YYYY-MM-DD)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: heureCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Heure de début (HH:MM)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dureeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Durée (minutes)',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    if (!mounted) return;

    final payload = <String, dynamic>{
      'id': int.tryParse((m['rowid'] ?? '0').toString()) ?? 0,
    };
    final langue = langueCtrl.text.trim();
    final date = dateCtrl.text.trim();
    final heure = heureCtrl.text.trim();
    final dureeStr = dureeCtrl.text.trim();
    final statusStr = selectedStatusCode.trim();
    if (langue.isNotEmpty) payload['produit_ref'] = langue;
    if (date.isNotEmpty) payload['datemission'] = date;
    if (heure.isNotEmpty) payload['heuredebutmission'] = heure;
    if (dureeStr.isNotEmpty) payload['dureemission'] = int.tryParse(dureeStr) ?? 0;
    if (statusStr.isNotEmpty) payload['mission_status'] = int.tryParse(statusStr) ?? statusStr;
    if (selectedInterpreterId != null && selectedInterpreterId! > 0) {
      payload['interpreter_id'] = selectedInterpreterId;
    }

    if ((payload['id'] as int) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifiant de mission manquant')),
      );
      return;
    }

    final ok = await MissionService.updateMissionMap(payload);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mission mise à jour')),
      );
      // Reload current page to reflect changes
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de la mise à jour')),
      );
    }
  }

  void _showColumnPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              Widget buildSwitch(String key, String label) {
                return SwitchListTile(
                  title: Text(label),
                  value: _visibleColumns[key] ?? true,
                  onChanged: (v) {
                    setLocal(() {
                      _visibleColumns[key] = v;
                    });
                  },
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Colonnes visibles',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  buildSwitch('ref', 'Ref. mission'),
                  buildSwitch('refmission', 'Id. mission'),
                  buildSwitch('langue', 'Langue'),
                  buildSwitch('datemission', 'Date mission'),
                  buildSwitch('heuredebut', 'Heure de début'),
                  buildSwitch('duree', 'Durée'),
                  buildSwitch('societe', 'Société Demandeur'),
                  buildSwitch('demandeur', 'Demandeur'),
                  buildSwitch('interprete', 'Interprète'),
                  buildSwitch('label', 'Libellé'),
                  buildSwitch('telephone', 'Tel. Demandeur'),
                  buildSwitch('mobile', 'Mobile Demandeur'),
                  buildSwitch('devis', 'Devis'),
                  buildSwitch('facture', 'Facture'),
                  buildSwitch('montant', 'Montant mission (€)'),
                  buildSwitch('statut', 'Statut (workflow)'),
                  buildSwitch('createur', 'Créé par'),
                  buildSwitch('datecrea', 'Date création'),
                  buildSwitch('dateModif', 'Date modification'),
                  buildSwitch('modifiePar', 'Mis à jour par'),
                  buildSwitch('actions', 'Actions'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setLocal(() {
                            _visibleColumns.updateAll((key, value) => true);
                          });
                        },
                        child: const Text('Tout afficher'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          // Do not clear sort state; just trigger rebuild to reflect column visibility changes
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('Appliquer'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool get _canCreateInvoice =>
      _selectAllAcrossFilters || _selectedRowIds.isNotEmpty;

  void _goToBilling() {
    final selected = _selectedMissionsForBilling();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins une mission visible sur cette page.')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/billing',
      arguments: BillingPageArguments(missions: selected),
    );
  }


  Widget _sortableHeader(String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more, size: 16, color: _primaryBlue),
      ],
    );
  }

  DataCell _cell(String text, {required String keyWidth}) {
    const Map<String, double> widths = {
      'ref': 120,
      'refmission': 100,
      'langue': 120,
      'datemission': 120,
      'heuredebut': 110,
      'duree': 90,
      'societe': 180,
      'demandeur': 160,
      'interprete': 160,
      'label': 220,
      'telephone': 140,
      'mobile': 140,
      'devis': 120,
      'facture': 140,
      'montant': 120,
      'statut': 120,
      'createur': 160,
      'datecrea': 140,
      'dateModif': 150,
      'modifiePar': 160,
      'actions': 120,
    };
    final double w = widths[keyWidth] ?? 140;
    return DataCell(
      SizedBox(
        width: w,
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTableArea() {
    if (_busy) {
      return const Center(child: CircularProgressIndicator());
    }
    final rowsData = _filtered();
    final Set<int> visibleIds = rowsData
        .map((m) => int.tryParse((m['rowid'] ?? '0').toString()) ?? 0)
        .toSet();
    final bool anySelected = _selectAllAcrossFilters
        ? true
        : visibleIds.any((id) => _selectedRowIds.contains(id));
    final bool allSelected = _selectAllAcrossFilters
        ? (visibleIds.isNotEmpty &&
              visibleIds.every((id) => !_deselectedRowIds.contains(id)))
        : (visibleIds.isNotEmpty &&
              visibleIds.every((id) => _selectedRowIds.contains(id)));
    final bool? headerValue = allSelected ? true : (anySelected ? null : false);
    if (rowsData.isEmpty) {
      return const Center(child: Text('Aucune mission trouvée'));
    }
    return Scrollbar(
      thumbVisibility: true,
      controller: _hScrollCtrl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _hScrollCtrl,
        child: Scrollbar(
          thumbVisibility: true,
          controller: _vScrollCtrl,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            controller: _vScrollCtrl,
            child: IconTheme(
              data: IconThemeData(color: _primaryBlue),
              child: DataTable(
                columnSpacing: 12,
                headingRowHeight: 44,
                horizontalMargin: 12,
                checkboxHorizontalMargin: 8,
                showCheckboxColumn: false,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: Row(
                      children: [
                        Checkbox(
                          tristate: true,
                          value: headerValue,
                          onChanged: (v) {
                            setState(() {
                              if ((v ?? false)) {
                                // Enable global select-all across all filtered pages
                                _selectAllAcrossFilters = true;
                                _selectedRowIds.clear();
                                _deselectedRowIds.clear();
                              } else {
                                // Clear all selections
                                _selectAllAcrossFilters = false;
                                _selectedRowIds.clear();
                                _deselectedRowIds.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        const Text('Sélection'),
                      ],
                    ),
                  ),
                  if (_visibleColumns['ref'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Ref. mission'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['reference_devis'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['refmission'] ?? false)
                    DataColumn(
                      label: _sortableHeader('Id. mission'),
                      onSort: (i, asc) => _sortByNum(
                        (m) =>
                            (int.tryParse((m['rowid'] ?? '0').toString()) ?? 0),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['langue'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Langue'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['produit_ref'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['datemission'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Date mission'),
                      onSort: (i, asc) => _sortByDate(
                        (m) => (m['datemission_iso'] ?? m['datemission'] ?? '')
                            .toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['heuredebut'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Heure de début'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['heuredebutmission'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  // Due mission column removed
                  if (_visibleColumns['duree'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Durée'),
                      onSort: (i, asc) => _sortByNum(
                        (m) {
                          final s =
                              (m['debutmission_iso'] ?? m['debutmission'] ?? '')
                                  .toString();
                          final e =
                              (m['finmission_iso'] ?? m['finmission'] ?? '')
                                  .toString();
                          DateTime? sd;
                          DateTime? ed;
                          try {
                            sd = DateTime.tryParse(s);
                          } catch (_) {}
                          try {
                            ed = DateTime.tryParse(e);
                          } catch (_) {}
                          if (sd == null || ed == null) return 0;
                          return ed.difference(sd).inMinutes;
                        },
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['societe'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Société Demandeur'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['client_name'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['demandeur'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Demandeur'),
                      onSort: (i, asc) => _sortByString(
                        (m) =>
                            ('${((m['prenom_demandeur'] ?? '') as String).trim()} ${((m['nom_demandeur'] ?? '') as String)
                                        .trim()}')
                                .trim(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['interprete'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Interprète'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['interpreter_name'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['label'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Libellé'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['label'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['telephone'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Tel. Demandeur'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['phone'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['mobile'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Mobile Demandeur'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['phone_mobile'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['devis'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Devis'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['reference_devis'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['facture'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Facture'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['billed_status'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['montant'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Montant (€)'),
                      onSort: (i, asc) => _sortByNum(
                        (m) {
                          final v = (m['montant_mission']);
                          if (v is num) return v;
                          return num.tryParse(v?.toString() ?? '0') ?? 0;
                        },
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['statut'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Statut'),
                      onSort: (i, asc) => _sortByNum(
                        (m) {
                          final v = m['mission_status'];
                          if (v is num) return v;
                          return num.tryParse(v?.toString() ?? '0') ?? 0;
                        },
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['createur'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Créé par'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['creator_name'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['datecrea'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Date création'),
                      onSort: (i, asc) => _sortByDate(
                        (m) =>
                            (m['date_creation_iso'] ?? m['date_creation'] ?? '')
                                .toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['dateModif'] ?? false)
                    DataColumn(
                      label: _sortableHeader('Date modification'),
                      onSort: (i, asc) => _sortByDate(
                        (m) => (m['date_modification_iso'] ?? m['date_modification'] ?? '')
                            .toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['modifiePar'] ?? false)
                    DataColumn(
                      label: _sortableHeader('Mis à jour par'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['updated_by'] ?? '').toString(),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['actions'] ?? true)
                    const DataColumn(label: Text('Actions')),
                ],
                rows: rowsData.map<DataRow>((m) {
                  final rowId =
                      int.tryParse((m['rowid'] ?? '0').toString()) ?? 0;
                  final selected = _selectAllAcrossFilters
                      ? !_deselectedRowIds.contains(rowId)
                      : _selectedRowIds.contains(rowId);
                  final ref = (m['reference_devis'] ?? '').toString();
                  final libelle = (m['label'] ?? '').toString();
                  final langue = (m['produit_ref'] ?? '').toString();
                      final dateMission = (m['datemission'] ?? '').toString();
                      final heureDebut = (m['heuredebutmission'] ?? '').toString();
                      final duree = (m['dureemission'] ?? '').toString();
                  final client = (m['client_name'] ?? '').toString();
                  final prenomDemandeur = (m['prenom_demandeur'] ?? '')
                      .toString();
                  final nomDemandeur = (m['nom_demandeur'] ?? '').toString();
                  final demandeurFull =
                      (('${prenomDemandeur.trim()} ${nomDemandeur.trim()}')
                          .trim());
                  final phone = (m['phone'] ?? '').toString();
                  final mobile = (m['phone_mobile'] ?? '').toString();
                  final devis = ref;
                  final facture = (m['billed_status'] ?? '').toString();
                  final interp = (((m['interpreter_name'] ?? '').toString())
                      .trim());
                  final createur = ((m['creator_name'] ?? '').toString())
                      .trim();
                  final dateCrea =
                      (m['date_creation_iso'] ?? m['date_creation'] ?? '')
                          .toString();
                    final dateModif =
                      (m['date_modification_iso'] ?? m['date_modification'] ?? '')
                        .toString();
                    final updatedBy = (m['updated_by'] ?? '').toString();
                  final montant = () {
                    final v = m['montant_mission'];
                    num n;
                    if (v is num) {
                      n = v;
                    } else {
                      n = num.tryParse(v?.toString() ?? '0') ?? 0;
                    }
                    return '€ ${n.toStringAsFixed(2)}';
                  }();
                  final statutTxt = (m['mission_status'] ?? '').toString();
                  final cells = <DataCell>[
                    DataCell(
                      Checkbox(
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (_selectAllAcrossFilters) {
                              if ((v ?? false)) {
                                _deselectedRowIds.remove(rowId);
                              } else {
                                _deselectedRowIds.add(rowId);
                              }
                            } else {
                              if ((v ?? false)) {
                                _selectedRowIds.add(rowId);
                              } else {
                                _selectedRowIds.remove(rowId);
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ];
                  if (_visibleColumns['ref'] ?? true) {
                    cells.add(_cell(ref, keyWidth: 'ref'));
                  }
                  if (_visibleColumns['refmission'] ?? false) {
                    cells.add(_cell(rowId.toString(), keyWidth: 'refmission'));
                  }
                  if (_visibleColumns['langue'] ?? true) {
                    cells.add(_cell(langue, keyWidth: 'langue'));
                  }
                  if (_visibleColumns['datemission'] ?? true) {
                    cells.add(_cell(dateMission, keyWidth: 'datemission'));
                  }
                  if (_visibleColumns['heuredebut'] ?? true) {
                    cells.add(_cell(heureDebut, keyWidth: 'heuredebut'));
                  }
                  // Début/Fin columns removed from display
                  // Due mission column removed
                  if (_visibleColumns['duree'] ?? true) {
                    cells.add(_cell(duree, keyWidth: 'duree'));
                  }
                  if (_visibleColumns['societe'] ?? true) {
                    cells.add(_cell(client, keyWidth: 'societe'));
                  }
                  if (_visibleColumns['demandeur'] ?? true) {
                    cells.add(
                      _cell(
                        demandeurFull.isEmpty ? '—' : demandeurFull,
                        keyWidth: 'demandeur',
                      ),
                    );
                  }
                  if (_visibleColumns['interprete'] ?? true) {
                    cells.add(_cell(interp, keyWidth: 'interprete'));
                  }
                  if (_visibleColumns['label'] ?? true) {
                    cells.add(_cell(libelle, keyWidth: 'label'));
                  }
                  if (_visibleColumns['telephone'] ?? true) {
                    cells.add(
                      _cell(phone.isEmpty ? '—' : phone, keyWidth: 'telephone'),
                    );
                  }
                  if (_visibleColumns['mobile'] ?? true) {
                    cells.add(
                      _cell(mobile.isEmpty ? '—' : mobile, keyWidth: 'mobile'),
                    );
                  }
                  if (_visibleColumns['devis'] ?? true) {
                    cells.add(_cell(devis, keyWidth: 'devis'));
                  }
                  if (_visibleColumns['facture'] ?? true) {
                    cells.add(
                      _cell(
                        facture.isEmpty ? 'À facturer' : facture,
                        keyWidth: 'facture',
                      ),
                    );
                  }
                  if (_visibleColumns['montant'] ?? true) {
                    cells.add(_cell(montant, keyWidth: 'montant'));
                  }
                  if (_visibleColumns['statut'] ?? true) {
                    final displayStatus = statutTxt.isEmpty ? '—' : _labelForStatus(statutTxt);
                    cells.add(
                      _cell(
                        displayStatus,
                        keyWidth: 'statut',
                      ),
                    );
                  }
                  if (_visibleColumns['createur'] ?? true) {
                    cells.add(
                      _cell(
                        createur.isEmpty ? '—' : createur,
                        keyWidth: 'createur',
                      ),
                    );
                  }
                  if (_visibleColumns['datecrea'] ?? true) {
                    cells.add(
                      _cell(
                        dateCrea.isEmpty ? '—' : dateCrea,
                        keyWidth: 'datecrea',
                      ),
                    );
                  }
                  if (_visibleColumns['dateModif'] ?? false) {
                    cells.add(
                      _cell(
                        dateModif.isEmpty ? '—' : dateModif,
                        keyWidth: 'dateModif',
                      ),
                    );
                  }
                  if (_visibleColumns['modifiePar'] ?? false) {
                    cells.add(
                      _cell(
                        updatedBy.isEmpty ? '—' : updatedBy,
                        keyWidth: 'modifiePar',
                      ),
                    );
                  }
                  if (_visibleColumns['actions'] ?? true) {
                    cells.add(
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF000091),
                                  size: 20,
                                ),
                                tooltip: 'Modifier',
                                onPressed: () => _showEditMissionDialog(m),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Color(0xFFCE0500),
                                  size: 20,
                                ),
                                tooltip: 'Supprimer',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Supprimer la mission ?'),
                                      content: const Text('Cette action est irréversible.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final ok = await MissionService.deleteMission(rowId);
                                    if (!mounted) return;
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Mission supprimée')),
                                      );
                                      _load();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Échec de la suppression')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return DataRow(
                    selected: selected,
                    onSelectChanged: (v) {
                      setState(() {
                        if (_selectAllAcrossFilters) {
                          if ((v ?? false)) {
                            _deselectedRowIds.remove(rowId);
                          } else {
                            _deselectedRowIds.add(rowId);
                          }
                        } else {
                          if ((v ?? false)) {
                            _selectedRowIds.add(rowId);
                          } else {
                            _selectedRowIds.remove(rowId);
                          }
                        }
                      });
                    },
                    cells: cells,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveHelper.getSpacing(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: const Color(0xFF000091),
        elevation: 1,
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: 0,
          left: spacing / 2,
          right: spacing / 2,
          bottom: spacing / 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top controls: left filters + right actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            items: _statusOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(_labelForBillingFilter(s)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _statusFilter = v ?? 'Tous'),
                            isDense: true,
                            icon: const Icon(
                              Icons.expand_more,
                              color: Color(0xFF000091),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF161616),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: spacing),
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            value: _workflowFilter,
                            items: _workflowOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Statut mission: ${_labelForStatus(s)}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _workflowFilter = v ?? 'Tous'),
                            isDense: true,
                            icon: const Icon(
                              Icons.expand_more,
                              color: Color(0xFF000091),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF161616),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            labelText:
                                'Rechercher (Ref. mission, client, interprète, produit)',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _load(resetPage: true),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _exportFilteredCsv,
                      icon: const Icon(Icons.table_view),
                      label: const Text('Exporter filtré (CSV)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _showColumnPicker,
                      icon: const Icon(Icons.view_column),
                      label: const Text('Colonnes à afficher'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : () => _load(resetPage: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _canCreateInvoice ? _goToBilling : null,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text(
                        'Créer facture à partir de la sélection',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Debug summary to help understand empty results
            Builder(builder: (context) {
              final loaded = _missions.length;
              final filtered = _filtered().length;
              final hasRange = _dateStart != null && _dateEnd != null;
              final dateLabel = hasRange
                  ? '${_fmtDate(_dateStart!)} → ${_fmtDate(_dateEnd!)}'
                  : _dateFilter;
              final query = _searchCtrl.text.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Chargées: $loaded, Après filtres: $filtered • Statut: $_statusFilter • Workflow: $_workflowFilter • Date: $dateLabel${query.isNotEmpty ? ' • Recherche: $query' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              );
            }),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._dateFilterOptions.map((opt) {
                  final bool selected = _dateFilter == opt;
                  return ChoiceChip(
                    label: Text(opt),
                    selected: selected,
                    onSelected: (v) => setState(() => _dateFilter = opt),
                    selectedColor: _primaryBlue,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _primaryBlue,
                    ),
                    backgroundColor: Colors.white,
                    shape:
                        StadiumBorder(side: BorderSide(color: _primaryBlue)),
                  );
                }),
                ElevatedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Choisir période'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (_dateStart != null && _dateEnd != null)
                  Text(
                    '${_fmtDate(_dateStart!)} → ${_fmtDate(_dateEnd!)}',
                    style: const TextStyle(color: Color(0xFF161616)),
                  ),
                const Spacer(),
                if (_dateStart != null || _dateEnd != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _dateStart = null;
                      _dateEnd = null;
                    }),
                    child: const Text('Effacer'),
                  ),
                if (_dateStart != null || _dateEnd != null)
                  const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _statusFilter = 'Tous';
                    _workflowFilter = 'Tous';
                    _dateFilter = 'Tous';
                    _dateStart = null;
                    _dateEnd = null;
                  }),
                  child: const Text('Réinitialiser les filtres'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Card with caption, table, and pagination
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
                child: Column(
                  children: [
                    // Caption
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing / 2,
                        vertical: spacing / 6,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.table_rows, color: Color(0xFF000091)),
                          SizedBox(width: 8),
                          Text(
                            'Tableau des missions',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Spacer(),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                    // Table area
                    Expanded(child: _buildTableArea()),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                    // Pagination
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing,
                        vertical: spacing / 1.2,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        children: [
                          DropdownButton<int>(
                            value: _pageSize,
                            items: const [25, 50, 100]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('Page: $v'),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (v) {
                                    if (v != null) {
                                      setState(() {
                                        _pageSize = v;
                                      });
                                      _load(resetPage: true);
                                    }
                                  },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _busy || _page <= 1
                                ? null
                                : () {
                                    setState(() {
                                      _page -= 1;
                                    });
                                    _load();
                                  },
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Préc.'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _busy || (_page * _pageSize >= _total)
                                ? null
                                : () {
                                    setState(() {
                                      _page += 1;
                                    });
                                    _load();
                                  },
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Suiv.'),
                          ),
                          const SizedBox(width: 12),
                          Text('Page $_page • Total $_total'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const BrandFooter(),
          ],
        ),
      ),
    );
  }
}
