import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/auth_manager.dart';
import '../core/brand_footer.dart';
import '../core/file_downloader.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../services/client_service.dart';
import '../services/contact_service.dart';
import '../services/language_service.dart';
import '../services/mission_service.dart';
import 'billing_page.dart';

class _AutocompleteEntry<T> {
  final T value;
  final String label;
  const _AutocompleteEntry({required this.value, required this.label});
}

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

  static const List<String> _missionTypeChoices = <String>[
    'Tribunal judiciaire',
    'Traduction',
    'Interprétariat',
  ];

  final DateFormat _dateDisplayFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateApiFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeDisplayFormat = DateFormat('HH:mm');

  // Workflow (mission_status) filter
  String _workflowFilter = 'Tous';
  List<String> _workflowOptions = ['Tous'];
  List<String> _languageOptions = <String>[];
  List<_AutocompleteEntry<String>> _languageEntries = <_AutocompleteEntry<String>>[];
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
    return value == 'Tous' ? 'Statut facture interprète: Tous' : value;
  }

  final Map<String, bool> _visibleColumns = {
    // Show only the first 10 table columns by default
    // Order: ref, refmission, langue, datemission, heuredebut, duree,
    //        societe, demandeur, interprete, label
    'ref': true,
    'refmission': false,
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
  bool _filtersCollapsed = false;

  @override
  void initState() {
    super.initState();
    _load(resetPage: true);
    _loadLanguages();
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
    final newLanguageOptions = _mergeLanguageOptions(data);
    final bool shouldUpdateLanguagesFromMissions =
      _languageOptions.isEmpty && newLanguageOptions.isNotEmpty;
    // Build workflow options from loaded data
    final wfSet = <String>{};
    for (final m in data) {
      final v = (m['mission_status'] ?? '').toString().trim();
      if (v.isNotEmpty) wfSet.add(v);
    }
    final wfList = wfSet.toList()
      ..sort((a, b) {
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
      if (shouldUpdateLanguagesFromMissions) {
        _languageOptions = newLanguageOptions;
        if (_languageEntries.isEmpty) {
          _languageEntries = newLanguageOptions
              .map((label) => _AutocompleteEntry<String>(value: label, label: label))
              .toList();
        }
      }
    });
    // Apply default sort: Date mission DESC, then Heure début mission DESC
    _applyDefaultSortByDateHeure();
  }

  Future<void> _loadLanguages() async {
    try {
      final options = await LanguageService.getLanguages(limit: 500,
          type: 1); // Dolibarr interprets languages/products as services (type 1)
      if (!mounted || options.isEmpty) return;
      final seen = <String>{};
      final entries = <_AutocompleteEntry<String>>[];
      final labels = <String>[];
      for (final option in options) {
        final ref = option.ref.trim();
        final label = option.displayName.trim();
        final display = label.isNotEmpty ? label : ref;
        if (display.isEmpty) continue;
        final key = display.toLowerCase();
        if (!seen.add(key)) continue;
        final value = ref.isNotEmpty ? ref : display;
        entries.add(_AutocompleteEntry<String>(value: value, label: display));
        labels.add(display);
      }
      entries.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      labels.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _languageEntries = entries;
        _languageOptions = labels;
      });
    } catch (_) {
      // Ignore errors and fall back to mission-derived languages.
    }
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
        final DateTime weekStart =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
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
      final v = _visibleColumns[k] ??
          (k == 'ref' ||
              k == 'refmission' ||
              k == 'langue' ||
              k == 'datemission' ||
              k == 'heuredebut' ||
              k == 'duree' ||
              k == 'societe' ||
              k == 'demandeur' ||
              k == 'interprete' ||
              k == 'label' ||
              k == 'telephone' ||
              k == 'mobile' ||
              k == 'facture' ||
              k == 'montant' ||
              k == 'statut' ||
              k == 'createur' ||
              k == 'datecrea' ||
              k == 'actions');
      return v;
    }

    if (check('ref')) {
      if (key == 'ref') return idx;
      idx++;
    }
    if (check('refmission')) {
      if (key == 'refmission') return idx;
      idx++;
    }
    if (check('langue')) {
      if (key == 'langue') return idx;
      idx++;
    }
    if (check('datemission')) {
      if (key == 'datemission') return idx;
      idx++;
    }
    if (check('heuredebut')) {
      if (key == 'heuredebut') return idx;
      idx++;
    }
    if (check('duree')) {
      if (key == 'duree') return idx;
      idx++;
    }
    if (check('societe')) {
      if (key == 'societe') return idx;
      idx++;
    }
    if (check('demandeur')) {
      if (key == 'demandeur') return idx;
      idx++;
    }
    if (check('interprete')) {
      if (key == 'interprete') return idx;
      idx++;
    }
    if (check('label')) {
      if (key == 'label') return idx;
      idx++;
    }
    if (check('telephone')) {
      if (key == 'telephone') return idx;
      idx++;
    }
    if (check('mobile')) {
      if (key == 'mobile') return idx;
      idx++;
    }
    if (check('facture')) {
      if (key == 'facture') return idx;
      idx++;
    }
    if (check('montant')) {
      if (key == 'montant') return idx;
      idx++;
    }
    if (check('statut')) {
      if (key == 'statut') return idx;
      idx++;
    }
    if (check('interprete')) {
      // already handled above
    }
    if (check('createur')) {
      if (key == 'createur') return idx;
      idx++;
    }
    if (check('datecrea')) {
      if (key == 'datecrea') return idx;
      idx++;
    }
    if (check('dateModif')) {
      if (key == 'dateModif') return idx;
      idx++;
    }
    if (check('modifiePar')) {
      if (key == 'modifiePar') return idx;
      idx++;
    }
    if (check('actions')) {
      if (key == 'actions') return idx;
      idx++;
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

  List<String> _decodeMissionTypes(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => (e ?? '').toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => (e ?? '').toString().trim())
              .where((value) => value.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // fall back to comma-separated parsing
      }
      return trimmed
          .split(',')
          .map((segment) => segment.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw == null) return const [];
    final value = raw.toString().trim();
    return value.isEmpty ? const [] : <String>[value];
  }

  List<String> _mergeLanguageOptions(Iterable<Map<String, dynamic>> missions) {
    final set = <String>{..._languageOptions};
    for (final mission in missions) {
      final raw = (mission['produit_ref'] ?? mission['langue_label'] ?? mission['langue'] ?? '').toString().trim();
      if (raw.isNotEmpty) {
        set.add(raw);
      }
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  DateTime? _parseDateTimeInput(String date, String time) {
    final sanitizedDate = date.trim();
    if (sanitizedDate.isEmpty) return null;
    String sanitizedTime = time.trim();
    if (sanitizedTime.isEmpty) {
      sanitizedTime = '00:00';
    }
    if (!sanitizedTime.contains(':')) {
      sanitizedTime = '$sanitizedTime:00';
    } else if (sanitizedTime.split(':').length == 2) {
      // ensure seconds are present for ISO parsing
      final parts = sanitizedTime.split(':');
      if (parts[1].length == 1) {
        sanitizedTime = '${parts[0]}:${parts[1].padLeft(2, '0')}';
      }
      if (sanitizedTime.length == 5) {
        sanitizedTime = '$sanitizedTime:00';
      }
    }
    final candidates = <String>[
      '${sanitizedDate}T$sanitizedTime',
      '$sanitizedDate $sanitizedTime',
      sanitizedDate,
    ];
    for (final candidate in candidates) {
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  String _formatDateTimeForApi(DateTime dt) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  DateTime? _parseMissionDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    try {
      return _dateDisplayFormat.parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseMissionTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final dt = DateTime(1970, 1, 1, time.hour, time.minute);
    return _timeDisplayFormat.format(dt);
  }

  int? _parseDurationMinutes(String input) {
    final value = input.trim().toLowerCase();
    if (value.isEmpty) return 0;

    final hoursPattern = RegExp(r'^(\d+)h(?:\s*(\d{1,2}))?$');
    final colonPattern = RegExp(r'^(\d{1,2}):(\d{1,2})$');
    final minutesPattern = RegExp(r'^\d+$');

    final hoursMatch = hoursPattern.firstMatch(value);
    if (hoursMatch != null) {
      final hours = int.parse(hoursMatch.group(1)!);
      final minutes = hoursMatch.group(2) != null ? int.parse(hoursMatch.group(2)!) : 0;
      if (minutes >= 60) return null;
      return hours * 60 + minutes;
    }

    final colonMatch = colonPattern.firstMatch(value);
    if (colonMatch != null) {
      final hours = int.parse(colonMatch.group(1)!);
      final minutes = int.parse(colonMatch.group(2)!);
      if (minutes >= 60) return null;
      return hours * 60 + minutes;
    }

    if (minutesPattern.hasMatch(value)) {
      return int.parse(value);
    }

    return null;
  }

  String _friendlyMissionError(String? message, {required bool isCreation}) {
    final fallback = isCreation
        ? 'Échec de la création de la mission.'
        : 'Échec de la mise à jour de la mission.';
    if (message == null || message.trim().isEmpty) {
      return fallback;
    }
    final lower = message.toLowerCase();
    final action = isCreation ? 'créer' : 'mettre à jour';
    if (lower.contains('langue') && (lower.contains('vide') || lower.contains('null'))) {
      return 'Sélectionnez une langue (référence produit) avant de $action la mission.';
    }
    if (lower.contains('interpreter') && lower.contains('requis')) {
      return 'Choisissez un interprète avant de $action la mission.';
    }
    if (lower.contains('fk_soc') || lower.contains('client')) {
      return 'Associez un client valide à la mission.';
    }
    if (lower.contains('fk_user_creat') || lower.contains('fk_user_creator')) {
      return 'Impossible d’identifier l’utilisateur connecté. Veuillez vous reconnecter puis réessayer.';
    }
    return message;
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

  Future<void> _showMissionFormDialog({Map<String, dynamic>? mission}) async {
    final bool isCreation = mission == null;
    final TextEditingController langueCtrl =
        TextEditingController(text: (mission?['produit_ref'] ?? '').toString());
    final TextEditingController dateCtrl =
      TextEditingController(text: (mission?['datemission'] ?? '').toString());
    final TextEditingController heureCtrl =
      TextEditingController(text: (mission?['heuredebutmission'] ?? '').toString());
    final TextEditingController dureeCtrl =
      TextEditingController(text: (mission?['dureemission'] ?? '').toString());
    final TextEditingController labelCtrl =
        TextEditingController(text: (mission?['label'] ?? '').toString());
    final TextEditingController commentaireCtrl =
        TextEditingController(
          text: (mission?['commentaires'] ?? mission?['description'] ?? '').toString(),
        );
    String? selectedLanguageRef = () {
      final raw = (mission?['produit_ref'] ?? '').toString().trim();
      return raw.isEmpty ? null : raw;
    }();
    DateTime? selectedMissionDate = _parseMissionDate(dateCtrl.text);
    if (selectedMissionDate != null) {
      dateCtrl.text = _dateDisplayFormat.format(selectedMissionDate);
    }
    TimeOfDay? selectedMissionTime = _parseMissionTime(heureCtrl.text);
    if (selectedMissionTime != null) {
      heureCtrl.text = _formatTimeOfDay(selectedMissionTime);
    }

    final int? initialClientId = mission != null
        ? int.tryParse((mission['client_id'] ?? mission['fk_soc'] ?? '').toString())
        : null;
    final int? initialContactId = mission != null
        ? int.tryParse((mission['contact_id'] ?? mission['contactdemandeur'] ?? '').toString())
        : null;
    final String initialClientName = (mission?['client_name'] ?? '').toString().trim();
    final String initialContactName = () {
      final prenom = (mission?['prenom_demandeur'] ?? '').toString().trim();
      final nom = (mission?['nom_demandeur'] ?? '').toString().trim();
      final combined = [prenom, nom].where((part) => part.isNotEmpty).join(' ').trim();
      if (combined.isNotEmpty) return combined;
      return (mission?['contactdemandeur_name'] ?? '').toString().trim();
    }();

    final futures = await Future.wait([
      MissionService.getInterpretes(),
      ClientService.getClientSummaries(limit: 500),
    ]);
    if (!mounted) return;
    final List<Map<String, dynamic>> interpretes =
        futures[0] as List<Map<String, dynamic>>;
    final List<ClientSummary> clientSummaries = futures[1] as List<ClientSummary>;

    final Map<int, List<ContactInfo>> contactsCache = {};
    List<ContactInfo> initialContacts = <ContactInfo>[];
    if (initialClientId != null && initialClientId > 0) {
      try {
        initialContacts = await ContactService.getContactsForClient(
          clientId: initialClientId,
        );
        contactsCache[initialClientId] = initialContacts;
      } catch (_) {
        // ignore contact preload errors
      }
    }
    if (!mounted) return;

    int? selectedInterpreterId = mission != null
      ? int.tryParse((mission['nominterprete'] ?? mission['interpreter_id'] ?? '').toString())
      : null;
    final currentInterpreterName = (mission?['interpreter_name'] ?? '').toString().trim();
    int? selectedClientId = initialClientId;
    int? selectedContactId = initialContactId;
    List<ContactInfo> contactOptions = initialContacts;
    bool contactsLoading = false;
    final String initialClientLabel = (selectedClientId != null && selectedClientId > 0)
      ? (initialClientName.isEmpty ? 'Client #$selectedClientId' : initialClientName)
      : '';
    final String initialContactLabel = (selectedContactId != null && selectedContactId > 0)
      ? (initialContactName.isEmpty ? 'Contact #$selectedContactId' : initialContactName)
      : '';
    final String initialInterpreterLabel = (selectedInterpreterId != null && selectedInterpreterId > 0)
      ? (currentInterpreterName.isEmpty ? 'Interprète #$selectedInterpreterId' : currentInterpreterName)
      : '';
    final TextEditingController clientCtrl = TextEditingController(text: initialClientLabel);
    final TextEditingController contactCtrl = TextEditingController(text: initialContactLabel);
    final TextEditingController interpreterCtrl =
      TextEditingController(text: initialInterpreterLabel);
    bool langueFieldListenerAttached = false;
    bool clientFieldListenerAttached = false;
    bool contactFieldListenerAttached = false;
    bool interpreterFieldListenerAttached = false;
    bool statusFieldListenerAttached = false;

    final rawStatus = (mission?['mission_status'] ?? '').toString().trim();
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
    if (statusCodes.isEmpty) {
      statusCodes.add('1');
    }
    String selectedStatusCode = rawStatus.isEmpty && statusCodes.isNotEmpty
        ? statusCodes.first
        : rawStatus;
    if (selectedStatusCode.isEmpty && statusCodes.isEmpty) {
      selectedStatusCode = '1';
    }
    final TextEditingController statusCtrl = TextEditingController(
      text: selectedStatusCode.isEmpty ? '' : _labelForStatus(selectedStatusCode),
    );

    final Set<String> selectedMissionTypes =
      Set<String>.from(_decodeMissionTypes(mission?['mission_types']));
    if (selectedMissionTypes.isEmpty &&
      _missionTypeChoices.contains('Interprétariat')) {
      selectedMissionTypes.add('Interprétariat');
    }
    void syncContactController() {
      if (selectedContactId == null) {
        contactCtrl.text = '';
        return;
      }
      ContactInfo? match;
      for (final contact in contactOptions) {
        if (contact.id == selectedContactId) {
          match = contact;
          break;
        }
      }
      if (match != null) {
        contactCtrl.text = match.displayName;
      } else {
        selectedContactId = null;
        contactCtrl.text = '';
      }
    }
    String? validationMessage;
    void Function(void Function())? refreshDialogState;

    Future<void> loadContactsForClient(int? clientId, void Function(void Function()) setLocal) async {
      if (clientId == null || clientId <= 0) {
        setLocal(() {
          contactOptions = <ContactInfo>[];
          contactsLoading = false;
          selectedContactId = null;
          contactCtrl.text = '';
        });
        return;
      }
      if (contactsCache.containsKey(clientId)) {
        setLocal(() {
          contactOptions = contactsCache[clientId]!;
          contactsLoading = false;
          syncContactController();
        });
        return;
      }
      setLocal(() {
        contactsLoading = true;
        contactOptions = <ContactInfo>[];
      });
      try {
        final fetched = await ContactService.getContactsForClient(clientId: clientId);
        contactsCache[clientId] = fetched;
        if (!mounted) return;
        setLocal(() {
          contactOptions = fetched;
          contactsLoading = false;
          syncContactController();
        });
      } catch (_) {
        if (!mounted) return;
        setLocal(() {
          contactsLoading = false;
        });
      }
    }

    final bool? dialogConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          title: Text(isCreation ? 'Créer une mission' : 'Modifier la mission'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) {
              refreshDialogState = setLocal;
              final Size screenSize = MediaQuery.of(ctx).size;
              final double dialogWidth = screenSize.width.clamp(520.0, 1020.0);
              final double dialogHeight = (screenSize.height * 0.9).clamp(560.0, screenSize.height);
              List<_AutocompleteEntry<int>> buildClientEntries() {
                final entries = clientSummaries
                    .map(
                      (client) => _AutocompleteEntry<int>(
                        value: client.id,
                        label: client.name.isEmpty ? 'Client #${client.id}' : client.name,
                      ),
                    )
                    .toList()
                  ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
                if (selectedClientId != null &&
                    selectedClientId! > 0 &&
                    !entries.any((entry) => entry.value == selectedClientId)) {
                  final fallback = initialClientName.isEmpty
                      ? 'Client #${selectedClientId!}'
                      : '$initialClientName (hors liste)';
                  entries.insert(
                    0,
                    _AutocompleteEntry<int>(value: selectedClientId!, label: fallback),
                  );
                }
                return entries;
              }

              List<_AutocompleteEntry<int>> buildContactEntries() {
                final entries = contactOptions
                    .map((contact) => _AutocompleteEntry<int>(
                          value: contact.id,
                          label: contact.displayName,
                        ))
                    .toList();
                if (selectedContactId != null &&
                    selectedContactId! > 0 &&
                    !entries.any((entry) => entry.value == selectedContactId)) {
                  final fallback = initialContactName.isEmpty
                      ? 'Contact #${selectedContactId!}'
                      : '$initialContactName (hors liste)';
                  entries.insert(
                    0,
                    _AutocompleteEntry<int>(value: selectedContactId!, label: fallback),
                  );
                }
                return entries;
              }

              List<_AutocompleteEntry<int>> buildInterpreterEntries() {
                final entries = interpretes
                    .map((entry) {
                      final id = int.tryParse((entry['id'] ?? '').toString());
                      if (id == null) return null;
                      final rawName = (entry['display_name'] ?? '').toString().trim();
                      final label = rawName.isEmpty ? 'Interprète #$id' : rawName;
                      return _AutocompleteEntry<int>(value: id, label: label);
                    })
                    .whereType<_AutocompleteEntry<int>>()
                    .toList()
                  ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
                if (selectedInterpreterId != null &&
                    selectedInterpreterId! > 0 &&
                    !entries.any((entry) => entry.value == selectedInterpreterId)) {
                  final fallback = currentInterpreterName.isEmpty
                      ? 'Interprète #${selectedInterpreterId!}'
                      : '$currentInterpreterName (hors liste)';
                  entries.insert(
                    0,
                    _AutocompleteEntry<int>(value: selectedInterpreterId!, label: fallback),
                  );
                }
                return entries;
              }

              List<_AutocompleteEntry<String>> buildLanguageEntries() {
                if (_languageEntries.isNotEmpty) {
                  return _languageEntries;
                }
                return _languageOptions
                    .map((label) => _AutocompleteEntry<String>(value: label, label: label))
                    .toList();
              }

              final List<_AutocompleteEntry<String>> statusEntries = statusCodes
                  .where((code) => code.trim().isNotEmpty)
                  .map((code) => _AutocompleteEntry<String>(
                        value: code,
                        label: _labelForStatus(code),
                      ))
                  .toList();

              return SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Type de mission',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _missionTypeChoices.map((choice) {
                                      final bool chipSelected = selectedMissionTypes.contains(choice);
                                      return FilterChip(
                                        label: Text(choice),
                                        selected: chipSelected,
                                        onSelected: (selected) => setLocal(() {
                                          if (selected) {
                                            selectedMissionTypes.add(choice);
                                          } else {
                                            selectedMissionTypes.remove(choice);
                                          }
                                        }),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: labelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Libellé',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Planification',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: dateCtrl,
                                readOnly: true,
                                onTap: () async {
                                  final now = DateTime.now();
                                  final initialDate = selectedMissionDate ?? now;
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime(now.year - 5),
                                    lastDate: DateTime(now.year + 5),
                                  );
                                  if (picked != null) {
                                    setLocal(() {
                                      selectedMissionDate = picked;
                                      dateCtrl.text = _dateDisplayFormat.format(picked);
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Date de la mission (JJ/MM/AAAA)',
                                  isDense: true,
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: heureCtrl,
                                readOnly: true,
                                onTap: () async {
                                  final initialTime = selectedMissionTime ?? TimeOfDay.now();
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: initialTime,
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: true,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setLocal(() {
                                      selectedMissionTime = picked;
                                      heureCtrl.text = _formatTimeOfDay(picked);
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Heure de début (HH:MM)',
                                  isDense: true,
                                  suffixIcon: Icon(Icons.schedule),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: dureeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Durée (minutes)',
                                  hintText: 'Ex: 3h, 2h30, 2:30 ou 150',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Informations demandeur',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final clientOptions = buildClientEntries();
                            final double dropdownWidth = constraints.maxWidth;
                            return Autocomplete<_AutocompleteEntry<int>>(
                              initialValue: clientCtrl.value,
                              displayStringForOption: (option) => option.label,
                              optionsBuilder: (textEditingValue) {
                                final query = textEditingValue.text.trim().toLowerCase();
                                if (query.isEmpty) return clientOptions;
                                return clientOptions.where(
                                  (option) =>
                                      option.label.toLowerCase().contains(query) ||
                                      option.value.toString().contains(query),
                                );
                              },
                              onSelected: (option) {
                                setLocal(() {
                                  selectedClientId = option.value;
                                  clientCtrl.value = TextEditingValue(text: option.label);
                                  selectedContactId = null;
                                  contactCtrl.text = '';
                                  contactOptions = <ContactInfo>[];
                                });
                                loadContactsForClient(option.value, setLocal);
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                if (!clientFieldListenerAttached) {
                                  textEditingController.value = clientCtrl.value;
                                  textEditingController.addListener(() {
                                    if (clientCtrl.value != textEditingController.value) {
                                      clientCtrl.value = textEditingController.value;
                                      refreshDialogState?.call(() {
                                        selectedClientId = null;
                                        selectedContactId = null;
                                        contactOptions = <ContactInfo>[];
                                        contactCtrl.text = '';
                                      });
                                    }
                                  });
                                  clientFieldListenerAttached = true;
                                }
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Société demandeuse',
                                    isDense: true,
                                    suffixIcon: Icon(Icons.arrow_drop_down),
                                  ),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                final opts = options.toList();
                                if (opts.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 240,
                                        minWidth: dropdownWidth,
                                        maxWidth: dropdownWidth,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: opts.length,
                                        itemBuilder: (context, index) {
                                          final option = opts[index];
                                          return ListTile(
                                            title: Text(option.label),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final contactEntries = buildContactEntries();
                            final double dropdownWidth = constraints.maxWidth;
                            return Autocomplete<_AutocompleteEntry<int>>(
                              initialValue: contactCtrl.value,
                              displayStringForOption: (option) => option.label,
                              optionsBuilder: (textEditingValue) {
                                final query = textEditingValue.text.trim().toLowerCase();
                                if (query.isEmpty) return contactEntries;
                                return contactEntries.where(
                                  (option) => option.label.toLowerCase().contains(query),
                                );
                              },
                              onSelected: (option) {
                                setLocal(() {
                                  selectedContactId = option.value;
                                  contactCtrl.value = TextEditingValue(text: option.label);
                                });
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                if (!contactFieldListenerAttached) {
                                  textEditingController.value = contactCtrl.value;
                                  textEditingController.addListener(() {
                                    if (contactCtrl.value != textEditingController.value) {
                                      contactCtrl.value = textEditingController.value;
                                      refreshDialogState?.call(() {
                                        selectedContactId = null;
                                      });
                                    }
                                  });
                                  contactFieldListenerAttached = true;
                                }
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Personne demandeuse',
                                    isDense: true,
                                    suffixIcon: Icon(Icons.arrow_drop_down),
                                  ),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                final opts = options.toList();
                                if (opts.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 240,
                                        minWidth: dropdownWidth,
                                        maxWidth: dropdownWidth,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: opts.length,
                                        itemBuilder: (context, index) {
                                          final option = opts[index];
                                          return ListTile(
                                            title: Text(option.label),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        if (contactsLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Mission',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final interpreterOptions = buildInterpreterEntries();
                                  final double dropdownWidth = constraints.maxWidth;
                                  return Autocomplete<_AutocompleteEntry<int>>(
                                    initialValue: interpreterCtrl.value,
                                    displayStringForOption: (option) => option.label,
                                    optionsBuilder: (textEditingValue) {
                                      final query = textEditingValue.text.trim().toLowerCase();
                                      if (query.isEmpty) return interpreterOptions;
                                      return interpreterOptions.where(
                                        (option) =>
                                            option.label.toLowerCase().contains(query) ||
                                            option.value.toString().contains(query),
                                      );
                                    },
                                    onSelected: (option) {
                                      setLocal(() {
                                        selectedInterpreterId = option.value;
                                        interpreterCtrl.value = TextEditingValue(text: option.label);
                                        validationMessage = null;
                                      });
                                    },
                                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                      if (!interpreterFieldListenerAttached) {
                                        textEditingController.value = interpreterCtrl.value;
                                        textEditingController.addListener(() {
                                          if (interpreterCtrl.value != textEditingController.value) {
                                            interpreterCtrl.value = textEditingController.value;
                                            refreshDialogState?.call(() {
                                              selectedInterpreterId = null;
                                            });
                                          }
                                        });
                                        interpreterFieldListenerAttached = true;
                                      }
                                      return TextField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Interprète',
                                          isDense: true,
                                          suffixIcon: Icon(Icons.arrow_drop_down),
                                        ),
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      final opts = options.toList();
                                      if (opts.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight: 240,
                                              minWidth: dropdownWidth,
                                              maxWidth: dropdownWidth,
                                            ),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: opts.length,
                                              itemBuilder: (context, index) {
                                                final option = opts[index];
                                                return ListTile(
                                                  title: Text(option.label),
                                                  onTap: () => onSelected(option),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final double dropdownWidth = constraints.maxWidth;
                                  final languageEntries = buildLanguageEntries();
                                  return Autocomplete<_AutocompleteEntry<String>>(
                                    initialValue: langueCtrl.value,
                                    displayStringForOption: (option) => option.label,
                                    optionsBuilder: (textEditingValue) {
                                      if (languageEntries.isEmpty) {
                                        return const Iterable<_AutocompleteEntry<String>>.empty();
                                      }
                                      final query = textEditingValue.text.trim().toLowerCase();
                                      if (query.isEmpty) {
                                        return languageEntries;
                                      }
                                      return languageEntries.where(
                                        (option) => option.label.toLowerCase().contains(query) ||
                                            option.value.toLowerCase().contains(query),
                                      );
                                    },
                                    onSelected: (option) {
                                      selectedLanguageRef = option.value.trim();
                                      langueCtrl.text = option.label;
                                    },
                                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                      if (!langueFieldListenerAttached) {
                                        textEditingController.value = langueCtrl.value;
                                        textEditingController.addListener(() {
                                          if (langueCtrl.value != textEditingController.value) {
                                            langueCtrl.value = textEditingController.value;
                                            selectedLanguageRef = null;
                                          }
                                        });
                                        langueFieldListenerAttached = true;
                                      }
                                      return TextField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Langue (ref produit)',
                                          isDense: true,
                                          suffixIcon: Icon(Icons.arrow_drop_down),
                                        ),
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      final opts = options.toList();
                                      if (opts.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight: 240,
                                              minWidth: dropdownWidth,
                                              maxWidth: dropdownWidth,
                                            ),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: opts.length,
                                              itemBuilder: (context, index) {
                                                final option = opts[index];
                                                return ListTile(
                                                  title: Text(option.label),
                                                  subtitle: option.value != option.label
                                                      ? Text(option.value)
                                                      : null,
                                                  onTap: () => onSelected(option),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: commentaireCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Commentaires',
                            alignLabelWithHint: true,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double dropdownWidth = constraints.maxWidth;
                            return Autocomplete<_AutocompleteEntry<String>>(
                              initialValue: statusCtrl.value,
                              displayStringForOption: (option) => option.label,
                              optionsBuilder: (textEditingValue) {
                                final query = textEditingValue.text.trim().toLowerCase();
                                if (query.isEmpty) return statusEntries;
                                return statusEntries.where(
                                  (option) =>
                                      option.label.toLowerCase().contains(query) ||
                                      option.value.toLowerCase().contains(query),
                                );
                              },
                              onSelected: (option) {
                                setLocal(() {
                                  selectedStatusCode = option.value;
                                  statusCtrl.value = TextEditingValue(text: option.label);
                                });
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                if (!statusFieldListenerAttached) {
                                  textEditingController.value = statusCtrl.value;
                                  textEditingController.addListener(() {
                                    if (statusCtrl.value != textEditingController.value) {
                                      statusCtrl.value = textEditingController.value;
                                      refreshDialogState?.call(() {
                                        selectedStatusCode = '';
                                      });
                                    }
                                  });
                                  statusFieldListenerAttached = true;
                                }
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Statut mission',
                                    isDense: true,
                                    suffixIcon: Icon(Icons.arrow_drop_down),
                                  ),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                final opts = options.toList();
                                if (opts.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 240,
                                        minWidth: dropdownWidth,
                                        maxWidth: dropdownWidth,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: opts.length,
                                        itemBuilder: (context, index) {
                                          final option = opts[index];
                                          return ListTile(
                                            title: Text(option.label),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        if (validationMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            validationMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
                  ),
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
              onPressed: () {
                if ((selectedInterpreterId ?? 0) <= 0) {
                  refreshDialogState?.call(() {
                    validationMessage = 'Sélectionnez un interprète';
                  });
                  return;
                }
                refreshDialogState?.call(() {
                  validationMessage = null;
                });
                Navigator.pop(ctx, true);
              },
              child: Text(isCreation ? 'Créer' : 'Enregistrer'),
            ),
          ],
        );
      },
    );

    if (dialogConfirmed != true || !mounted) return;

    final int missionId = int.tryParse((mission?['rowid'] ?? '0').toString()) ?? 0;
    if (!isCreation && missionId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifiant de mission manquant')),
      );
      return;
    }

    final payload = <String, dynamic>{};
    if (!isCreation) {
      payload['id'] = missionId;
    }
    final int? interpreterId = selectedInterpreterId;
    if (interpreterId != null && interpreterId > 0) {
      payload['interpreter_id'] = interpreterId;
    }
    payload['label'] = labelCtrl.text.trim();
    final clientId = selectedClientId;
    if (clientId != null && clientId > 0) {
      payload['client_id'] = clientId;
    }
    final contactId = selectedContactId;
    if (contactId != null && contactId > 0) {
      payload['contact_id'] = contactId;
    }
    payload['commentaires'] = commentaireCtrl.text.trim();
    final langue = langueCtrl.text.trim();
    final langueRef = selectedLanguageRef?.trim() ?? '';
    if (langueRef.isNotEmpty) {
      payload['produit_ref'] = langueRef;
    } else if (langue.isNotEmpty) {
      payload['produit_ref'] = langue;
    }
    final dateText = dateCtrl.text.trim();
    final DateTime? effectiveDate = selectedMissionDate ?? _parseMissionDate(dateText);
    String dateForComputation = '';
    if (effectiveDate != null) {
      dateForComputation = _dateApiFormat.format(effectiveDate);
      payload['datemission'] = dateForComputation;
    } else if (dateText.isNotEmpty) {
      dateForComputation = dateText;
      payload['datemission'] = dateText;
    }

    final heureText = heureCtrl.text.trim();
    final TimeOfDay? effectiveTime = selectedMissionTime ?? _parseMissionTime(heureText);
    String heureForComputation = '';
    if (effectiveTime != null) {
      heureForComputation = _formatTimeOfDay(effectiveTime);
      payload['heuredebutmission'] = heureForComputation;
    } else if (heureText.isNotEmpty) {
      heureForComputation = heureText;
      payload['heuredebutmission'] = heureText;
    }

    final parsedDuration = _parseDurationMinutes(dureeCtrl.text.trim());
    if (parsedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durée invalide. Utilisez 3h, 2h30, 2:30 ou 150.')),
      );
      return;
    }
    if (parsedDuration > 0) {
      payload['dureemission'] = parsedDuration;
    }
    if (selectedStatusCode.isNotEmpty) {
      final parsedStatus = int.tryParse(selectedStatusCode);
      payload['mission_status'] = parsedStatus ?? selectedStatusCode;
    }
    payload['mission_types'] = selectedMissionTypes.toList();

    final start = _parseDateTimeInput(dateForComputation, heureForComputation);
    if (start != null) {
      payload['debutmission'] = _formatDateTimeForApi(start);
      if (parsedDuration > 0) {
        payload['finmission'] = _formatDateTimeForApi(start.add(Duration(minutes: parsedDuration)));
      }
    }

    final int currentUserId = AuthManager.userId;
    if (currentUserId > 0) {
      if (isCreation) {
        payload['creator_id'] = currentUserId;
      } else {
        payload['modifier_id'] = currentUserId;
      }
    }

    final MissionApiResult result = isCreation
        ? await MissionService.addMissionMap(payload)
        : await MissionService.updateMissionMap(payload);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(isCreation ? 'Mission créée' : 'Mission mise à jour')),
      );
      _load(resetPage: isCreation);
    } else {
      final msg = _friendlyMissionError(result.message, isCreation: isCreation);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showColumnPicker() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Colonnes visibles'),
          content: StatefulBuilder(
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

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSwitch('refmission', 'Id. mission'),
                    buildSwitch('telephone', 'Tel. Demandeur'),
                    buildSwitch('mobile', 'Mobile Demandeur'),
                    buildSwitch('facture', 'Facture interprète'),
                    buildSwitch('statut', 'Statut (workflow)'),
                    buildSwitch('createur', 'Créé par'),
                    buildSwitch('datecrea', 'Date création'),
                    buildSwitch('dateModif', 'Date modification'),
                    buildSwitch('modifiePar', 'Mis à jour par'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setLocal(() {
                            _visibleColumns.updateAll((key, value) => true);
                          });
                        },
                        child: const Text('Tout afficher'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Appliquer'),
            ),
          ],
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
      'facture': 140,
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
                  if (_visibleColumns['facture'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Facture interprète'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['billed_status'] ?? '').toString(),
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
                  if (_visibleColumns['facture'] ?? true) {
                    cells.add(
                      _cell(
                        facture.isEmpty ? 'À facturer' : facture,
                        keyWidth: 'facture',
                      ),
                    );
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
                                onPressed: () => _showMissionFormDialog(mission: m),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFF8F9FA),
          foregroundColor: const Color(0xFF000091),
          elevation: 1,
          toolbarHeight: 0,
        ),
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
            if (!_filtersCollapsed) ...[
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
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => setState(() => _filtersCollapsed = true),
                    icon: const Icon(Icons.unfold_less),
                    label: const Text('Masquer les filtres'),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
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
                            shape: StadiumBorder(
                              side: BorderSide(color: _primaryBlue),
                            ),
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
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.userRights.canManageMissions())
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _showMissionFormDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nouvelle mission'),
                            ),
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
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Filtres masqués. Cliquez sur "Afficher les filtres" pour les afficher.',
                      style: TextStyle(color: Color(0xFF4B5563)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.unfold_more),
                    label: const Text('Afficher les filtres'),
                    onPressed: () => setState(() => _filtersCollapsed = false),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
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
