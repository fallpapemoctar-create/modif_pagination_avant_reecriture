// ignore_for_file: unnecessary_underscores, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

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
import '../core/models/quote.dart';
import '../services/quote_service.dart';
import 'missions_table_page_arguments.dart';
import 'billing_page.dart';
import 'quote_edit_page.dart';

class _AutocompleteEntry<T> {
  final T value;
  final String label;
  const _AutocompleteEntry({required this.value, required this.label});
}

enum _MissionWorkspaceView { newMission, table, devis }

class MissionsTablePage extends StatefulWidget {
  final UserRights userRights;
  final bool startInCreationMode;
  const MissionsTablePage({
    super.key,
    required this.userRights,
    this.startInCreationMode = false,
  });

  @override
  State<MissionsTablePage> createState() => _MissionsTablePageState();
}

class _MissionsTablePageState extends State<MissionsTablePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _requestingCompanyCtrl = TextEditingController();
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
    'Brouillon',
    'Validée',
    'Envoyée',
    'Renvoyée au collaborateur',
    'Payée',
  ];

  static const List<String> _missionTypeChoices = <String>[
    'Tribunal judiciaire',
    'Traduction',
    'Interprétariat',
  ];
  static const List<String> _missionTypeFilterOptions = <String>[
    'Tous',
    'Tribunal judiciaire',
    'Traduction',
    'Interprétariat',
  ];

  final DateFormat _dateDisplayFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateApiFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _dateTimeDisplayFormat = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat _timeDisplayFormat = DateFormat('HH:mm');

  // Mission status filter
  String _workflowFilter = 'Tous';
  String _missionTypeFilter = 'Tous';
  String _requestingCompanyFilter = '';
  final List<String> _workflowOptions = const ['Tous', '0', '1', '9'];
  List<String> _languageOptions = <String>[];
  List<_AutocompleteEntry<String>> _languageEntries =
      <_AutocompleteEntry<String>>[];
  _MissionWorkspaceView _activeView = _MissionWorkspaceView.table;
  bool _sidebarCollapsed = true;
  bool _filtersCollapsed = true;
  final Set<int> _selectedRowIds = <int>{};
  final Set<int> _deselectedRowIds = <int>{};
  bool _selectAllAcrossFilters = false;
  final Map<String, bool> _visibleColumns = <String, bool>{
    'ref': true,
    'refmission': false,
    'langue': true,
    'typeMission': true,
    'datemission': true,
    'heuredebut': true,
    'duree': true,
    'societe': true,
    'demandeur': true,
    'interprete': true,
    'label': true,
    'telephone': true,
    'mobile': true,
    'facture': true,
    'statut': true,
    'factureClient': true,
    'createur': true,
    'datecrea': true,
    'dateModif': false,
    'modifiePar': false,
    'actions': true,
  };
  final List<String> _dateFilterOptions = const [
    'Tous',
    'Aujourd\'hui',
    '7 derniers jours',
    '30 derniers jours',
    'Ce mois',
  ];
  String _dateFilter = 'Tous';
  DateTime? _dateStart;
  DateTime? _dateEnd;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  Timer? _requestingCompanySearchDebounce;
  int _requestingCompanySearchRequestId = 0;
  bool _requestingCompanySearchLoading = false;
  String _lastRequestingCompanySearchQuery = '';
  List<ClientSummary> _requestingCompanySuggestions = <ClientSummary>[];
  bool _requestingCompanyFieldListenerAttached = false;
  final Map<String, String> _workflowLabels = const {
    'Tous': 'Tous',
    '0': 'Brouillon',
    '1': 'Validé',
    '9': 'Annulé',
  };
  bool _routeArgsHandled = false;

  // ── Devis view state ──
  List<Quote> _devisQuotes = [];
  int _devisQuotesTotal = 0;
  bool _devisLoading = false;
  String? _devisError;
  String _devisStatusFilter = 'draft';
  int _devisPage = 1;
  static const int _devisPageSize = 25;

  @override
  void dispose() {
    _requestingCompanySearchDebounce?.cancel();
    _searchCtrl.dispose();
    _requestingCompanyCtrl.dispose();
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _activeView = _MissionWorkspaceView.newMission;
    _loadLanguageOptions();
    _loadRequestingCompanySuggestions();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsHandled) return;
    _routeArgsHandled = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is MissionsTablePageArguments && args.showNewMissionForm) {
      setState(() => _activeView = _MissionWorkspaceView.newMission);
    }
  }

  String _labelForBillingFilter(String option) {
    if (option == 'Tous') return 'Tous les statuts';
    return option;
  }

  String _labelForStatus(String code) {
    if (code == 'Tous') return 'Tous les statuts mission';
    return _workflowLabels[code] ?? 'Statut $code';
  }

  String _labelForMissionTypeFilter(String option) {
    if (option == 'Tous') return 'Tous les types';
    return option;
  }

  bool _isMissionEligibleForBilling(Map<String, dynamic> mission) {
    final status = (mission['mission_status'] ?? '').toString().trim();
    return status == '0' || status == '1';
  }

  List<String> _decodeMissionTypes(dynamic raw) {
    if (raw == null) return <String>[];
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return <String>[];
    return text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String _missionTypesLabel(dynamic raw) {
    final values = _decodeMissionTypes(raw);
    if (values.isEmpty) return '—';
    return values.join(', ');
  }

  String _friendlyMissionError(String? message, {required bool isCreation}) {
    final fallback = isCreation
        ? 'Impossible de créer la mission.'
        : 'Impossible de mettre à jour la mission.';
    if (message == null || message.trim().isEmpty) return fallback;
    final lowered = message.toLowerCase();
    if (lowered.contains('duplicate') || lowered.contains('existe')) {
      return 'Une mission similaire existe déjà.';
    }
    if (lowered.contains('interpreter')) {
      return 'Veuillez sélectionner un interprète valide.';
    }
    return message;
  }

  DateTime? _parseMissionDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;
    try {
      return _dateDisplayFormat.parse(trimmed);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseMissionTime(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    String normalized = trimmed.replaceAll('H', 'h');
    if (!normalized.contains('h') && normalized.contains(':')) {
      final parts = normalized.split(':');
      final h = int.tryParse(parts[0]);
      final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }
    if (normalized.contains('h')) {
      final parts = normalized.split('h');
      final h = int.tryParse(parts[0]);
      final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }
    if (normalized.length == 4) {
      final h = int.tryParse(normalized.substring(0, 2));
      final m = int.tryParse(normalized.substring(2));
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }
    final value = int.tryParse(normalized);
    if (value != null) {
      final h = (value ~/ 100).clamp(0, 23);
      final m = (value % 100).clamp(0, 59);
      return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final date = DateTime(1970, 1, 1, time.hour, time.minute);
    return _timeDisplayFormat.format(date);
  }

  int? _parseDurationMinutes(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('h')) {
      final parts = trimmed.replaceAll('H', 'h').split('h');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return h * 60 + m;
    }
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return h * 60 + m;
    }
    return int.tryParse(trimmed);
  }

  DateTime? _parseDateTimeInput(String date, String time) {
    final datePart = date.trim();
    if (datePart.isEmpty) return null;
    final parsedDate = _parseMissionDate(datePart);
    if (parsedDate == null) return null;
    final parsedTime = time.trim().isEmpty ? null : _parseMissionTime(time);
    if (parsedTime == null) return parsedDate;
    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  String _formatDateTimeForApi(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  String _fmtDate(DateTime date) => _dateDisplayFormat.format(date);

  String _formatDisplayDateValue(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '—';
    final parsed = DateTime.tryParse(text) ?? _parseMissionDate(text);
    if (parsed == null) return text;
    return _dateDisplayFormat.format(parsed);
  }

  String _formatDisplayDateTimeValue(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '—';
    final parsed = DateTime.tryParse(text) ?? _parseMissionDate(text);
    if (parsed == null) return text;
    final hasTime =
        text.contains(':') ||
        parsed.hour != 0 ||
        parsed.minute != 0 ||
        parsed.second != 0;
    return hasTime
        ? _dateTimeDisplayFormat.format(parsed)
        : _dateDisplayFormat.format(parsed);
  }

  ({DateTime? start, DateTime? end}) _resolvedDateRange() {
    DateTime? start = _dateStart;
    DateTime? end = _dateEnd;
    if (start == null && end == null) {
      final today = DateTime.now();
      switch (_dateFilter) {
        case 'Aujourd\'hui':
          start = DateTime(today.year, today.month, today.day);
          end = start;
          break;
        case '7 derniers jours':
          end = DateTime(today.year, today.month, today.day);
          start = end.subtract(const Duration(days: 6));
          break;
        case '30 derniers jours':
          end = DateTime(today.year, today.month, today.day);
          start = end.subtract(const Duration(days: 29));
          break;
        case 'Ce mois':
          start = DateTime(today.year, today.month, 1);
          end = DateTime(today.year, today.month + 1, 0);
          break;
      }
    }
    return (start: start, end: end);
  }

  void _applyPresetDateFilter(String option) {
    setState(() {
      _dateFilter = option;
      _dateStart = null;
      _dateEnd = null;
    });
    _load(resetPage: true);
  }

  void _applyBillingStatusFilter(String? value) {
    setState(() {
      _statusFilter = value ?? 'Tous';
    });
    _load(resetPage: true);
  }

  void _applyMissionStatusFilter(String? value) {
    setState(() {
      _workflowFilter = value ?? 'Tous';
    });
    _load(resetPage: true);
  }

  void _applyMissionTypeFilter(String? value) {
    setState(() {
      _missionTypeFilter = value ?? 'Tous';
    });
    _load(resetPage: true);
  }

  void _applyRequestingCompanyFilter([String? value]) {
    setState(() {
      _requestingCompanyFilter = (value ?? _requestingCompanyCtrl.text).trim();
      _requestingCompanyCtrl.value = TextEditingValue(
        text: _requestingCompanyFilter,
        selection: TextSelection.collapsed(
          offset: _requestingCompanyFilter.length,
        ),
      );
    });
    _load(resetPage: true);
  }

  Future<void> _loadRequestingCompanySuggestions() async {
    await _searchRequestingCompanies('');
  }

  void _scheduleRequestingCompanySearch(
    String query, {
    bool immediate = false,
  }) {
    _requestingCompanySearchDebounce?.cancel();
    final normalized = query.trim();
    if (!immediate && normalized == _lastRequestingCompanySearchQuery) {
      return;
    }

    void runSearch() {
      _searchRequestingCompanies(normalized);
    }

    if (immediate) {
      runSearch();
      return;
    }

    _requestingCompanySearchDebounce = Timer(
      const Duration(milliseconds: 250),
      runSearch,
    );
  }

  Future<void> _searchRequestingCompanies(String query) async {
    final normalized = query.trim();
    final int requestId = ++_requestingCompanySearchRequestId;
    _lastRequestingCompanySearchQuery = normalized;

    if (mounted) {
      setState(() {
        _requestingCompanySearchLoading = true;
      });
    }

    try {
      final results = await ClientService.getClientSummaries(
        query: normalized.isEmpty ? null : normalized,
      );
      if (!mounted || requestId != _requestingCompanySearchRequestId) return;
      setState(() {
        _requestingCompanySuggestions = results;
        _requestingCompanySearchLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestingCompanySearchRequestId) return;
      setState(() {
        _requestingCompanySearchLoading = false;
      });
    }
  }

  List<_AutocompleteEntry<String>> _buildRequestingCompanyEntries() {
    final normalizedFilter = _requestingCompanyFilter.trim().toLowerCase();
    final entries =
        _requestingCompanySuggestions
            .where((client) => client.name.trim().isNotEmpty)
            .map(
              (client) => _AutocompleteEntry<String>(
                value: client.name,
                label: client.name,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    if (normalizedFilter.isNotEmpty &&
        !entries.any(
          (entry) => entry.label.toLowerCase() == normalizedFilter,
        )) {
      entries.insert(
        0,
        _AutocompleteEntry<String>(
          value: _requestingCompanyFilter,
          label: _requestingCompanyFilter,
        ),
      );
    }
    return entries;
  }

  Widget _buildRequestingCompanyOptionsView({
    required Iterable<_AutocompleteEntry<String>> options,
    required double dropdownWidth,
    required AutocompleteOnSelected<_AutocompleteEntry<String>> onSelected,
  }) {
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
  }

  void _clearRequestingCompanyFilter() {
    if (_requestingCompanyFilter.isEmpty &&
        _requestingCompanyCtrl.text.isEmpty) {
      return;
    }
    setState(() {
      _requestingCompanyFilter = '';
      _requestingCompanyCtrl.clear();
    });
    _load(resetPage: true);
  }

  void _clearDateFilter() {
    setState(() {
      _dateFilter = 'Tous';
      _dateStart = null;
      _dateEnd = null;
    });
    _load(resetPage: true);
  }

  void _resetAllFilters() {
    setState(() {
      _statusFilter = 'Tous';
      _workflowFilter = 'Tous';
      _missionTypeFilter = 'Tous';
      _requestingCompanyFilter = '';
      _dateFilter = 'Tous';
      _dateStart = null;
      _dateEnd = null;
      _searchCtrl.clear();
      _requestingCompanyCtrl.clear();
    });
    _load(resetPage: true);
  }

  Future<void> _loadLanguageOptions() async {
    try {
      final options = await LanguageService.getLanguages(limit: 10000);
      if (!mounted) return;
      setState(() {
        _languageOptions = options.map((option) => option.displayName).toList();
        _languageEntries = options
            .map(
              (option) => _AutocompleteEntry<String>(
                value: option.ref.trim().isEmpty
                    ? option.displayName
                    : option.ref.trim(),
                label: option.displayName,
              ),
            )
            .toList();
      });
    } catch (_) {
      // Ignored: absence of langues n'empêche pas la création
    }
  }

  Future<void> _load({bool resetPage = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      if (resetPage) _page = 1;
    });
    final query = _searchCtrl.text.trim();
    final range = _resolvedDateRange();
    try {
      final response = await MissionService.getMissionsDatatable(
        page: _page,
        pageSize: _pageSize,
        q: query.isEmpty ? null : query,
        requestingCompany: _requestingCompanyFilter.isEmpty
            ? null
            : _requestingCompanyFilter,
        dateStart: range.start != null
            ? _dateApiFormat.format(range.start!)
            : null,
        dateEnd: range.end != null ? _dateApiFormat.format(range.end!) : null,
        billedStatus: _statusFilter == 'Tous' ? null : _statusFilter,
        missionStatus: _workflowFilter == 'Tous' ? null : _workflowFilter,
        missionType: _missionTypeFilter == 'Tous' ? null : _missionTypeFilter,
      );
      if (!mounted) return;
      final missions = (response['missions'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      missions.sort((a, b) {
        final dateA = (a['datemission_iso'] ?? a['datemission'] ?? '').toString();
        final dateB = (b['datemission_iso'] ?? b['datemission'] ?? '').toString();
        final dc = dateB.compareTo(dateA); // DESC
        if (dc != 0) return dc;
        final heureA = (a['heuredebutmission'] ?? '').toString();
        final heureB = (b['heuredebutmission'] ?? '').toString();
        return heureA.compareTo(heureB); // ASC
      });
      setState(() {
        _missions = missions;
        _total = (response['total'] as int?) ?? missions.length;
        _page = (response['page'] as int?) ?? _page;
        _pageSize = (response['pageSize'] as int?) ?? _pageSize;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _missions = <Map<String, dynamic>>[];
        _total = 0;
        _busy = false;
      });
    }
  }

  List<Map<String, dynamic>> _filtered() {
    Iterable<Map<String, dynamic>> data = _missions;
    final search = _searchCtrl.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      data = data.where((mission) {
        final fields = [
          mission['reference_devis'],
          mission['client_name'],
          mission['interpreter_name'],
          mission['produit_ref'],
          _missionTypesLabel(mission['mission_types']),
          mission['label'],
        ];
        return fields.any(
          (value) =>
              value != null && value.toString().toLowerCase().contains(search),
        );
      });
    }
    if (_requestingCompanyFilter.isNotEmpty) {
      final companyFilter = _requestingCompanyFilter.toLowerCase();
      data = data.where((mission) {
        final clientName = (mission['client_name'] ?? '')
            .toString()
            .toLowerCase();
        return clientName.contains(companyFilter);
      });
    }
    return data.toList(growable: false);
  }

  List<Map<String, dynamic>> _selectedMissionsForBilling() {
    final rows = _filtered();
    if (_selectAllAcrossFilters) {
      return rows
          .where((mission) {
            final id = int.tryParse((mission['rowid'] ?? '0').toString()) ?? 0;
            return !_deselectedRowIds.contains(id) &&
                _isMissionEligibleForBilling(mission);
          })
          .toList(growable: false);
    }
    return rows
        .where((mission) {
          final id = int.tryParse((mission['rowid'] ?? '0').toString()) ?? 0;
          return _selectedRowIds.contains(id) &&
              _isMissionEligibleForBilling(mission);
        })
        .toList(growable: false);
  }

  Future<void> _exportFilteredCsv() async {
    final query = _searchCtrl.text.trim();
    final range = _resolvedDateRange();
    final rows = await MissionService.getMissionsDatatableAll(
      q: query.isEmpty ? null : query,
      requestingCompany: _requestingCompanyFilter.isEmpty
          ? null
          : _requestingCompanyFilter,
      dateStart: range.start != null
          ? _dateApiFormat.format(range.start!)
          : null,
      dateEnd: range.end != null ? _dateApiFormat.format(range.end!) : null,
      billedStatus: _statusFilter == 'Tous' ? null : _statusFilter,
      missionStatus: _workflowFilter == 'Tous' ? null : _workflowFilter,
      missionType: _missionTypeFilter == 'Tous' ? null : _missionTypeFilter,
    );
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune mission à exporter.')),
      );
      return;
    }
    final headers = [
      'Ref mission',
      'Client',
      'Interprète',
      'Langue',
      'Type de mission',
      'Date',
      'Heure',
      'Durée (min)',
      'Statut mission',
    ];
    final buffer = StringBuffer()..writeln(headers.join(';'));
    for (final mission in rows) {
      buffer.writeln(
        [
              mission['reference_devis'] ?? '',
              mission['client_name'] ?? '',
              mission['interpreter_name'] ?? '',
              mission['produit_ref'] ?? '',
              _missionTypesLabel(mission['mission_types']),
              _formatDisplayDateValue(
                mission['datemission_iso'] ?? mission['datemission'],
              ),
              mission['heuredebutmission'] ?? '',
              mission['dureemission'] ?? '',
              _labelForStatus((mission['mission_status'] ?? '').toString()),
            ]
            .map((value) {
              final text = value.toString().replaceAll(';', ',');
              return '"${text.replaceAll('"', '""')}"';
            })
            .join(';'),
      );
    }
    await downloadBytes(
      bytes: utf8.encode(buffer.toString()),
      filename:
          'missions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      mimeType: 'text/csv',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Export CSV généré.')));
  }

  void _sortByString(
    String? Function(Map<String, dynamic>) selector,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _missions.sort((a, b) {
        final left = selector(a)?.toLowerCase() ?? '';
        final right = selector(b)?.toLowerCase() ?? '';
        return ascending ? left.compareTo(right) : right.compareTo(left);
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
        final left = selector(a);
        final right = selector(b);
        return ascending ? left.compareTo(right) : right.compareTo(left);
      });
    });
  }

  void _sortByDate(
    DateTime? Function(Map<String, dynamic>) selector,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _missions.sort((a, b) {
        final left = selector(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = selector(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ascending ? left.compareTo(right) : right.compareTo(left);
      });
    });
  }

  Future<void> _showMissionFormDialog({Map<String, dynamic>? mission}) async {
    final isCreation = mission == null;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
            child: _MissionFormPanel(
              isCreation: isCreation,
              mission: mission,
              missionTypeChoices: _missionTypeChoices,
              workflowOptions: _workflowOptions,
              workflowLabels: _workflowLabels,
              labelForStatus: _labelForStatus,
              languageEntries: _languageEntries,
              languageOptions: _languageOptions,
              decodeMissionTypes: _decodeMissionTypes,
              dateDisplayFormat: _dateDisplayFormat,
              timeDisplayFormat: _timeDisplayFormat,
              dateApiFormat: _dateApiFormat,
              parseMissionDate: _parseMissionDate,
              parseMissionTime: _parseMissionTime,
              formatTimeOfDay: _formatTimeOfDay,
              parseDurationMinutes: _parseDurationMinutes,
              parseDateTimeInput: _parseDateTimeInput,
              formatDateTimeForApi: _formatDateTimeForApi,
              friendlyMissionError: _friendlyMissionError,
              embedded: false,
              onSuccess: (created) {
                Navigator.of(ctx).pop(true);
                _load(resetPage: created);
              },
              onCancel: () => Navigator.of(ctx).pop(false),
            ),
          ),
        );
      },
    );
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
                    buildSwitch('typeMission', 'Type de mission'),
                    buildSwitch('facture', 'Facture interprète'),
                    buildSwitch('statut', 'Statut mission'),
                    buildSwitch('factureClient', 'Facture client'),
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
        const SnackBar(
          content: Text(
            'Veuillez sélectionner au moins une mission en Brouillon ou Validée. Les missions annulées sont exclues de la facturation.',
          ),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/billing',
      arguments: BillingPageArguments(missions: selected),
    );
  }

  void _setActiveView(_MissionWorkspaceView view) {
    if (_activeView == view) return;
    if (view == _MissionWorkspaceView.devis) {
      setState(() {
        _activeView = view;
        _devisLoading = true;
        _devisError = null;
      });
      unawaited(_loadDevisQuotes(reset: true));
    } else {
      setState(() {
        _activeView = view;
      });
    }
  }

  Future<void> _loadDevisQuotes({bool reset = false}) async {
    if (reset) {
      setState(() {
        _devisPage = 1;
        _devisQuotes = [];
        _devisQuotesTotal = 0;
      });
    }
    setState(() {
      _devisLoading = true;
      _devisError = null;
    });
    try {
      final result = await QuoteService.getQuotes(
        status: _devisStatusFilter,
        page: _devisPage,
        pageSize: _devisPageSize,
      );
      if (mounted) {
        setState(() {
          _devisQuotes = result.quotes;
          _devisQuotesTotal = result.total;
          _devisLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _devisError = e.toString();
          _devisLoading = false;
        });
      }
    }
  }

  Widget _buildCompactWorkspaceSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Navigation',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SegmentedButton<_MissionWorkspaceView>(
            multiSelectionEnabled: false,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_MissionWorkspaceView>(
                value: _MissionWorkspaceView.newMission,
                icon: Icon(Icons.add_circle_outline),
                label: Text('Nouvelle mission'),
              ),
              ButtonSegment<_MissionWorkspaceView>(
                value: _MissionWorkspaceView.table,
                icon: Icon(Icons.table_rows_outlined),
                label: Text('Tableau'),
              ),
              ButtonSegment<_MissionWorkspaceView>(
                value: _MissionWorkspaceView.devis,
                icon: Icon(Icons.request_quote_outlined),
                label: Text('Devis'),
              ),
            ],
            selected: <_MissionWorkspaceView>{_activeView},
            onSelectionChanged: (selection) {
              final view = selection.firstOrNull;
              if (view != null) {
                _setActiveView(view);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(double spacing) {
    final double viewWidth = MediaQuery.of(context).size.width;
    final bool forceCompact = viewWidth < 1100;
    final bool collapsed = forceCompact ? true : _sidebarCollapsed;
    final double panelWidth = collapsed ? 64 : 240;

    Widget navItem({
      required IconData icon,
      required String label,
      required _MissionWorkspaceView target,
    }) {
      final bool active = _activeView == target;
      final Color activeColor = active ? Colors.white : const Color(0xFF111827);
      final Color background = active ? _primaryBlue : Colors.transparent;
      final Color iconColor = active ? Colors.white : const Color(0xFF4B5563);
      final BorderRadius radius = BorderRadius.circular(8);
      return Tooltip(
        message: collapsed ? label : '',
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: () {
            _setActiveView(target);
          },
          borderRadius: radius,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 16,
              vertical: 12,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: background, borderRadius: radius),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 20),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: activeColor,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: panelWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Column(
        children: [
          SizedBox(height: spacing / 3),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.dashboard_customize,
                    color: Color(0xFF000091),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Navigation',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Replier',
                    onPressed: forceCompact
                        ? null
                        : () => setState(() => _sidebarCollapsed = true),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ],
              ),
            )
          else
            IconButton(
              tooltip: forceCompact ? null : 'Déplier',
              onPressed: forceCompact
                  ? null
                  : () => setState(() => _sidebarCollapsed = false),
              icon: const Icon(Icons.menu_open),
            ),
          const SizedBox(height: 8),
          navItem(
            icon: Icons.add_circle_outline,
            label: 'Nouvelle mission',
            target: _MissionWorkspaceView.newMission,
          ),
          navItem(
            icon: Icons.table_rows_outlined,
            label: 'Tableau des missions',
            target: _MissionWorkspaceView.table,
          ),
          navItem(
            icon: Icons.request_quote_outlined,
            label: 'Devis',
            target: _MissionWorkspaceView.devis,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDevisView(double spacing) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    const statuses = [
      ('draft', 'Brouillons'),
      ('sent', 'Envoyés'),
      ('accepted', 'Acceptés'),
      ('rejected', 'Rejetés'),
      ('expired', 'Expirés'),
      ('accepted_converted', 'Convertis'),
    ];

    Widget buildList() {
      if (_devisLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_devisError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 32),
              const SizedBox(height: 8),
              Text(_devisError!, style: const TextStyle(color: Color(0xFFB91C1C))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(_loadDevisQuotes(reset: true)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      }
      if (_devisQuotes.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.request_quote_outlined, size: 40, color: Color(0xFF9CA3AF)),
              SizedBox(height: 8),
              Text('Aucun devis pour ce statut.', style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        );
      }
      return ListView.separated(
        itemCount: _devisQuotes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final quote = _devisQuotes[index];
          final statusColor = Quote.statusColor(quote.status);
          return ListTile(
            leading: Icon(Icons.request_quote_outlined, color: statusColor),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    quote.clientName ?? '(client inconnu)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    Quote.statusLabel(quote.status),
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '#${quote.id}'
              '${quote.missionRef != null ? '  •  Mission : ${quote.missionRef}' : ''}'
              '  •  ${fmt.format(quote.totalHt)} HT'
              '${quote.dateValidUntil != null ? '  •  Valable : ${quote.dateValidUntil}' : ''}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => QuoteEditPage(initialQuote: quote),
                ),
              );
              if (mounted) unawaited(_loadDevisQuotes(reset: true));
            },
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.all(spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Devis',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
              const SizedBox(width: 6),
              if (_devisQuotesTotal > 0)
                Text(
                  '($_devisQuotesTotal)',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _devisStatusFilter,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: statuses
                    .map((s) => DropdownMenuItem(
                          value: s.$1,
                          child: Text(s.$2, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null || v == _devisStatusFilter) return;
                  setState(() {
                    _devisStatusFilter = v;
                    _devisPage = 1;
                  });
                  unawaited(_loadDevisQuotes(reset: true));
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
                onPressed: () => unawaited(_loadDevisQuotes(reset: true)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Devis liés aux missions — brouillons, envoyés et historique.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableScreen(double spacing) {
    if (_activeView == _MissionWorkspaceView.newMission) {
      return _buildNewMissionScreen(spacing);
    }
    if (_activeView == _MissionWorkspaceView.devis) {
      return _buildDevisView(spacing);
    }
    return Container(
      key: const ValueKey('missions-table-view'),
      padding: EdgeInsets.only(
        top: spacing / 4,
        left: spacing / 2,
        right: spacing / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterPanel(spacing),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
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
                      children: [
                        const Icon(Icons.table_rows, color: Color(0xFF000091)),
                        const SizedBox(width: 8),
                        const Text(
                          'Tableau des missions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (_busy)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            '$_total mission${_total > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE5E7EB),
                  ),
                  _buildMissionPaginationToolbar(),
                  Expanded(child: _buildTableArea()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewMissionScreen(double spacing) {
    if (!widget.userRights.canManageMissions()) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, size: 48, color: Color(0xFF6B7280)),
              SizedBox(height: 12),
              Text(
                'Vous n’avez pas les droits nécessaires pour créer une mission.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('missions-new-view'),
      padding: EdgeInsets.only(
        top: spacing / 4,
        left: spacing / 2,
        right: spacing / 2,
        bottom: spacing / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nouvelle mission',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'Les champs avec astérixe (*) sont obligatoires',
            style: TextStyle(color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              child: _MissionFormPanel(
                isCreation: true,
                mission: null,
                missionTypeChoices: _missionTypeChoices,
                workflowOptions: _workflowOptions,
                workflowLabels: _workflowLabels,
                labelForStatus: _labelForStatus,
                languageEntries: _languageEntries,
                languageOptions: _languageOptions,
                decodeMissionTypes: _decodeMissionTypes,
                dateDisplayFormat: _dateDisplayFormat,
                timeDisplayFormat: _timeDisplayFormat,
                dateApiFormat: _dateApiFormat,
                parseMissionDate: _parseMissionDate,
                parseMissionTime: _parseMissionTime,
                formatTimeOfDay: _formatTimeOfDay,
                parseDurationMinutes: _parseDurationMinutes,
                parseDateTimeInput: _parseDateTimeInput,
                formatDateTimeForApi: _formatDateTimeForApi,
                friendlyMissionError: _friendlyMissionError,
                embedded: true,
                onSuccess: (created) => _load(resetPage: created),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const BrandFooter(),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(double spacing) {
    if (_filtersCollapsed) {
      return _buildCollapsedFiltersBanner();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 720;
        final bool stackedFilters = constraints.maxWidth < 980;
        final bool stackedActions = constraints.maxWidth < 1180;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filtres du tableau',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _filtersCollapsed = true),
                          child: const Text('Masquer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (stackedFilters) ...[
                    _buildStatusFilters(compact: compact),
                    const SizedBox(height: 16),
                    _buildSearchPanel(compact: compact),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _filtersCollapsed = true),
                          child: const Text('Masquer les filtres'),
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildStatusFilters(compact: false),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 10,
                          child: _buildSearchPanel(compact: false),
                        ),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _filtersCollapsed = true),
                            child: const Text('Masquer les filtres'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildFilterSummaryText(),
                  const SizedBox(height: 14),
                  if (compact) ...[
                    _buildDateControls(compact: true),
                    const SizedBox(height: 12),
                    _buildActionButtonsRow(compact: true),
                  ] else if (stackedActions) ...[
                    _buildDateControls(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildActionButtonsRow(),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildDateControls()),
                        const SizedBox(width: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildActionButtonsRow(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildDateResetRow(compact: compact),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildCollapsedFiltersBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 760),
            child: Text(
              'Filtres masqués. Cliquez sur "Afficher les filtres" pour modifier la recherche.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _filtersCollapsed = false),
            child: const Text('Afficher les filtres'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummaryText() {
    final loaded = _missions.length;
    final filtered = _filtered().length;
    final bool hasRange = _dateStart != null && _dateEnd != null;
    final String dateLabel = hasRange
        ? '${_fmtDate(_dateStart!)} → ${_fmtDate(_dateEnd!)}'
        : _dateFilter;
    final String query = _searchCtrl.text.trim();
    final buffer = StringBuffer(
      'Chargées: $loaded, Après filtres: $filtered • Statut facture: $_statusFilter • Statut mission: ${_labelForStatus(_workflowFilter)} • Type: ${_labelForMissionTypeFilter(_missionTypeFilter)} • Date: $dateLabel',
    );
    if (_requestingCompanyFilter.isNotEmpty) {
      buffer.write(' • Société: $_requestingCompanyFilter');
    }
    if (query.isNotEmpty) {
      buffer.write(' • Recherche: $query');
    }
    return Text(
      buffer.toString(),
      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
    );
  }

  /// Construit une rangée de FilterChips pour un groupe de filtres.
  Widget _buildChipGroup({
    required String label,
    required String current,
    required List<String> options,
    required String Function(String) displayLabel,
    required void Function(String?) onChanged,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 5),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final selected = opt == current;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  selected: selected,
                  label: Text(displayLabel(opt),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected ? primary : const Color(0xFF374151))),
                  onSelected: (_) => onChanged(opt),
                  backgroundColor: Colors.white,
                  selectedColor: primary.withValues(alpha: 0.10),
                  checkmarkColor: primary,
                  showCheckmark: false,
                  side: BorderSide(
                      color: selected ? primary : const Color(0xFFD1D5DB),
                      width: selected ? 1.5 : 1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilters({bool compact = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtres',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF111827))),
          const SizedBox(height: 10),
          _buildChipGroup(
            label: 'Statut facture',
            current: _statusFilter,
            options: _statusOptions,
            displayLabel: _labelForBillingFilter,
            onChanged: _applyBillingStatusFilter,
          ),
          const SizedBox(height: 10),
          _buildChipGroup(
            label: 'Statut mission',
            current: _workflowFilter,
            options: _workflowOptions,
            displayLabel: _labelForStatus,
            onChanged: _applyMissionStatusFilter,
          ),
          const SizedBox(height: 10),
          _buildChipGroup(
            label: 'Type de mission',
            current: _missionTypeFilter,
            options: _missionTypeFilterOptions,
            displayLabel: _labelForMissionTypeFilter,
            onChanged: _applyMissionTypeFilter,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel({bool compact = false}) {
    final requestingCompanyEntries = _buildRequestingCompanyEntries();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recherche',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: compact
                  ? 'Réf. mission, client, interprète...'
                  : 'Rechercher (Ref. mission, client, interprète, produit)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _busy ? null : () => _load(resetPage: true),
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Lancer la recherche',
              ),
            ),
            onSubmitted: (_) => _load(resetPage: true),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final double dropdownWidth = constraints.maxWidth;
              return Autocomplete<_AutocompleteEntry<String>>(
                initialValue: _requestingCompanyCtrl.value,
                displayStringForOption: (option) => option.label,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) return requestingCompanyEntries;
                  return requestingCompanyEntries.where(
                    (option) => option.label.toLowerCase().contains(query),
                  );
                },
                onSelected: (option) {
                  _applyRequestingCompanyFilter(option.label);
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      if (!_requestingCompanyFieldListenerAttached) {
                        textEditingController.value =
                            _requestingCompanyCtrl.value;
                        textEditingController.addListener(() {
                          if (_requestingCompanyCtrl.value !=
                              textEditingController.value) {
                            setState(() {
                              _requestingCompanyCtrl.value =
                                  textEditingController.value;
                            });
                            _scheduleRequestingCompanySearch(
                              textEditingController.text,
                            );
                          }
                        });
                        _requestingCompanyFieldListenerAttached = true;
                      }
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: compact
                              ? 'Société demandeuse'
                              : 'Filtrer par société demandeuse',
                          prefixIcon: const Icon(Icons.business_outlined),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_requestingCompanyCtrl.text.trim().isNotEmpty)
                                IconButton(
                                  onPressed: _clearRequestingCompanyFilter,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Effacer le filtre société',
                                ),
                              IconButton(
                                onPressed: _busy
                                    ? null
                                    : () => _applyRequestingCompanyFilter(
                                        textEditingController.text,
                                      ),
                                icon: const Icon(Icons.arrow_forward),
                                tooltip: 'Filtrer par société',
                              ),
                            ],
                          ),
                        ),
                        onSubmitted: (_) => _applyRequestingCompanyFilter(
                          textEditingController.text,
                        ),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) =>
                    _buildRequestingCompanyOptionsView(
                      options: options,
                      dropdownWidth: dropdownWidth,
                      onSelected: onSelected,
                    ),
              );
            },
          ),
          if (_requestingCompanySearchLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> options,
    required String Function(String option) displayLabel,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFE),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options
                  .map(
                    (opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(displayLabel(opt)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.expand_more, color: Color(0xFF000091)),
              style: const TextStyle(color: Color(0xFF161616), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateControls({bool compact = false}) {
    final bool hasCustomRange = _dateStart != null || _dateEnd != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._dateFilterOptions.map((opt) {
          final bool selected = !hasCustomRange && _dateFilter == opt;
          return ChoiceChip(
            label: Text(opt),
            selected: selected,
            onSelected: (_) => _applyPresetDateFilter(opt),
            selectedColor: _primaryBlue,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _primaryBlue,
            ),
            backgroundColor: Colors.white,
            shape: StadiumBorder(side: BorderSide(color: _primaryBlue)),
          );
        }),
        FilledButton(
          onPressed: _pickDateRange,
          style: FilledButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Text(compact ? 'Période' : 'Choisir période'),
        ),
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTime initialStart =
        _dateStart ?? DateTime(now.year, now.month, 1);
    final DateTime initialEndCandidate = _dateEnd ?? now;
    final DateTime initialEnd = initialEndCandidate.isBefore(initialStart)
        ? initialStart
        : initialEndCandidate;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Sélectionnez une période',
      cancelText: 'Annuler',
      confirmText: 'Appliquer',
    );

    if (!mounted || picked == null) return;

    setState(() {
      _dateStart = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _dateEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      _dateFilter = 'Tous';
    });
    _load(resetPage: true);
  }

  Widget _buildDateResetRow({bool compact = false}) {
    final actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: [
        if (_dateStart != null || _dateEnd != null)
          TextButton(onPressed: _clearDateFilter, child: const Text('Effacer')),
        TextButton(
          onPressed: _resetAllFilters,
          child: const Text('Réinitialiser les filtres'),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_dateStart != null && _dateEnd != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_fmtDate(_dateStart!)} → ${_fmtDate(_dateEnd!)}',
                style: const TextStyle(color: Color(0xFF161616)),
              ),
            ),
          actions,
        ],
      );
    }
    return Row(
      children: [
        if (_dateStart != null && _dateEnd != null)
          Text(
            '${_fmtDate(_dateStart!)} → ${_fmtDate(_dateEnd!)}',
            style: const TextStyle(color: Color(0xFF161616)),
          ),
        const Spacer(),
        actions,
      ],
    );
  }

  Widget _buildActionButtonsRow({bool compact = false}) {
    final buttons = [
      ElevatedButton(
        onPressed: _busy ? null : _exportFilteredCsv,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size(compact ? double.infinity : 0, 40),
        ),
        child: const Text('Exporter filtré (CSV)'),
      ),
      ElevatedButton(
        onPressed: _busy ? null : _showColumnPicker,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size(compact ? double.infinity : 0, 40),
        ),
        child: const Text('Colonnes à afficher'),
      ),
      ElevatedButton(
        onPressed: _canCreateInvoice ? _goToBilling : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size(compact ? double.infinity : 0, 40),
        ),
        child: const Text('Créer facture'),
      ),
    ];
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < buttons.length; index++) ...[
            buttons[index],
            if (index < buttons.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: buttons,
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
      'ref': 140,
      'refmission': 110,
      'langue': 140,
      'typeMission': 210,
      'datemission': 140,
      'heuredebut': 130,
      'duree': 110,
      'societe': 210,
      'demandeur': 190,
      'interprete': 190,
      'label': 260,
      'telephone': 150,
      'mobile': 150,
      'facture': 150,
      'statut': 220,
      'createur': 170,
      'datecrea': 160,
      'dateModif': 170,
      'modifiePar': 170,
      'actions': 220,
    };
    final double w = widths[keyWidth] ?? 140;
    return DataCell(
      SizedBox(
        width: w,
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  DataCell _statusCell(String statusCode, {String clientBilledStatus = ''}) {
    const Map<String, double> widths = {'statut': 220};
    final displayStatus = statusCode.trim().isEmpty
        ? '—'
        : _labelForStatus(statusCode);
    final isCancelled = statusCode.trim() == '9';
    final isClientInvoiced = !isCancelled &&
        clientBilledStatus == 'validated';
    return DataCell(
      SizedBox(
        width: widths['statut']!,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(displayStatus, overflow: TextOverflow.ellipsis),
            if (isCancelled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFDA4AF)),
                ),
                child: const Text(
                  'Non facturable',
                  style: TextStyle(
                    color: Color(0xFFBE123C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (isClientInvoiced)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Text(
                  'Facturée',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DataCell _clientInvoiceCell(
    String invoiceNumber,
    String statusCode,
    String statusLabel,
  ) {
    if (invoiceNumber.isEmpty) {
      return DataCell(
        SizedBox(
          width: 200,
          child: Text('—', style: const TextStyle(color: Color(0xFF9CA3AF))),
        ),
      );
    }

    // Badge couleur selon le statut
    Color bgColor;
    Color borderColor;
    Color textColor;
    switch (statusCode) {
      case 'validated':
        bgColor = const Color(0xFFECFDF5);
        borderColor = const Color(0xFF6EE7B7);
        textColor = const Color(0xFF065F46);
        break;
      case 'sent':
        bgColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFF93C5FD);
        textColor = const Color(0xFF1D4ED8);
        break;
      case 'paid':
        bgColor = const Color(0xFFF0FDF4);
        borderColor = const Color(0xFF4ADE80);
        textColor = const Color(0xFF15803D);
        break;
      default:
        bgColor = const Color(0xFFF9FAFB);
        borderColor = const Color(0xFFD1D5DB);
        textColor = const Color(0xFF374151);
    }

    final label = statusLabel.isNotEmpty ? statusLabel : statusCode;

    return DataCell(
      SizedBox(
        width: 200,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/billing',
                  arguments: BillingPageArguments(
                    missions: const [],
                    invoiceNumber: invoiceNumber,
                  ),
                ),
                child: Text(
                  invoiceNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF000091),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF000091),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (label.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionPaginationToolbar() {
    const pageSizes = [25, 50, 100, 250, 500];
    final int pageCount = _pageSize > 0 ? ((_total + _pageSize - 1) ~/ _pageSize).clamp(1, 99999) : 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Text('Lignes :', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(width: 6),
          DropdownButton<int>(
            value: pageSizes.contains(_pageSize) ? _pageSize : 25,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: pageSizes
                .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    if (v == null || v == _pageSize) return;
                    setState(() {
                      _pageSize = v;
                      _page = 1;
                    });
                    _load();
                  },
          ),
          const SizedBox(width: 16),
          Text(
            '$_total mission${_total > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.first_page, size: 18),
            tooltip: 'Première page',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: (_busy || _page <= 1)
                ? null
                : () {
                    setState(() => _page = 1);
                    _load();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            tooltip: 'Page précédente',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: (_busy || _page <= 1)
                ? null
                : () {
                    setState(() => _page = _page - 1);
                    _load();
                  },
          ),
          Text(
            'Page $_page / $pageCount',
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            tooltip: 'Page suivante',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: (_busy || _page >= pageCount)
                ? null
                : () {
                    setState(() => _page = _page + 1);
                    _load();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 18),
            tooltip: 'Dernière page',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: (_busy || _page >= pageCount)
                ? null
                : () {
                    setState(() => _page = pageCount);
                    _load();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTableArea() {
    if (_busy) {
      return const Center(child: CircularProgressIndicator());
    }
    final rowsData = _filtered();
    final Set<int> visibleIds = rowsData
        .where(_isMissionEligibleForBilling)
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
      controller: _vScrollCtrl,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        controller: _vScrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Scrollbar(
          thumbVisibility: true,
          controller: _hScrollCtrl,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _hScrollCtrl,
            child: IconTheme(
              data: IconThemeData(color: _primaryBlue),
              child: DataTable(
                columnSpacing: 10,
                headingRowHeight: 38,   // réduit 44 → 38
                horizontalMargin: 10,
                checkboxHorizontalMargin: 6,
                showCheckboxColumn: false,
                dataRowMinHeight: 34,   // réduit 40 → 34
                dataRowMaxHeight: 36,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: Tooltip(
                      message:
                          'Sélectionner toutes les missions visibles et facturables',
                      child: Checkbox(
                        tristate: true,
                        value: headerValue,
                        onChanged: (v) {
                          setState(() {
                            if ((v ?? false)) {
                              _selectAllAcrossFilters = true;
                              _selectedRowIds.clear();
                              _deselectedRowIds.clear();
                            } else {
                              _selectAllAcrossFilters = false;
                              _selectedRowIds.clear();
                              _deselectedRowIds.clear();
                            }
                          });
                        },
                      ),
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
                  if (_visibleColumns['typeMission'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Type de mission'),
                      onSort: (i, asc) => _sortByString(
                        (m) => _missionTypesLabel(m['mission_types']),
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['datemission'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Date mission'),
                      onSort: (i, asc) => _sortByDate(
                        (m) => _parseMissionDate(
                          (m['datemission_iso'] ?? m['datemission'] ?? '')
                              .toString(),
                        ),
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
                            ('${((m['prenom_demandeur'] ?? '') as String).trim()} ${((m['nom_demandeur'] ?? '') as String).trim()}')
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
                      label: _sortableHeader('Statut mission'),
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
                  if (_visibleColumns['factureClient'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Facture client'),
                      onSort: (i, asc) => _sortByString(
                        (m) => (m['client_invoice_number'] ?? '').toString(),
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
                        (m) {
                          final raw =
                              (m['date_creation_iso'] ??
                                      m['date_creation'] ??
                                      '')
                                  .toString();
                          return DateTime.tryParse(raw) ??
                              _parseMissionDate(raw);
                        },
                        i,
                        asc,
                      ),
                    ),
                  if (_visibleColumns['dateModif'] ?? false)
                    DataColumn(
                      label: _sortableHeader('Date modification'),
                      onSort: (i, asc) => _sortByDate(
                        (m) {
                          final raw =
                              (m['date_modification_iso'] ??
                                      m['date_modification'] ??
                                      '')
                                  .toString();
                          return DateTime.tryParse(raw) ??
                              _parseMissionDate(raw);
                        },
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
                rows: rowsData.asMap().entries.map<DataRow>((entry) {
                  final idx = entry.key;
                  final m = entry.value;
                  final rowId =
                      int.tryParse((m['rowid'] ?? '0').toString()) ?? 0;
                  final isBillable = _isMissionEligibleForBilling(m);
                  final selected =
                      isBillable &&
                      (_selectAllAcrossFilters
                          ? !_deselectedRowIds.contains(rowId)
                          : _selectedRowIds.contains(rowId));
                  final ref = (m['reference_devis'] ?? '').toString();
                  final libelle = (m['label'] ?? '').toString();
                  final langue = (m['produit_ref'] ?? '').toString();
                  final missionTypes = _missionTypesLabel(m['mission_types']);
                  final dateMission = _formatDisplayDateValue(
                    m['datemission_iso'] ?? m['datemission'],
                  );
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
                  final dateCrea = _formatDisplayDateTimeValue(
                    m['date_creation_iso'] ?? m['date_creation'],
                  );
                  final dateModif = _formatDisplayDateTimeValue(
                    m['date_modification_iso'] ?? m['date_modification'],
                  );
                  final updatedBy = (m['updated_by'] ?? '').toString();
                  final statutTxt = (m['mission_status'] ?? '').toString();
                  final clientBilledStatus = (m['client_billed_status'] ?? '').toString().toLowerCase();
                  final clientInvoiceNumber = (m['client_invoice_number'] ?? '').toString().trim();
                  final clientBilledStatusLabel = (m['client_billed_status_label'] ?? '').toString().trim();
                  final cells = <DataCell>[
                    DataCell(
                      Checkbox(
                        value: selected,
                        onChanged: isBillable
                            ? (v) {
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
                              }
                            : null,
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
                  if (_visibleColumns['typeMission'] ?? true) {
                    cells.add(_cell(missionTypes, keyWidth: 'typeMission'));
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
                        facture.isEmpty ? 'Brouillon' : facture,
                        keyWidth: 'facture',
                      ),
                    );
                  }
                  if (_visibleColumns['statut'] ?? true) {
                    cells.add(_statusCell(statutTxt, clientBilledStatus: clientBilledStatus));
                  }
                  if (_visibleColumns['factureClient'] ?? true) {
                    cells.add(_clientInvoiceCell(clientInvoiceNumber, clientBilledStatus, clientBilledStatusLabel));
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
                    cells.add(_cell(dateCrea, keyWidth: 'datecrea'));
                  }
                  if (_visibleColumns['dateModif'] ?? false) {
                    cells.add(_cell(dateModif, keyWidth: 'dateModif'));
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
                          width: 310,
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    _showMissionFormDialog(mission: m),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF000091),
                                  size: 18,
                                ),
                                label: const Text('Editer'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF000091),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => QuoteEditPage(
                                        missionId: rowId,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.request_quote_outlined,
                                  color: Color(0xFF0D6E3F),
                                  size: 18,
                                ),
                                label: const Text('Devis'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D6E3F),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Color(0xFFCE0500),
                                  size: 18,
                                ),
                                label: const Text('Supprimer'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFCE0500),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Annuler la mission ?'),
                                      content: const Text(
                                        'La mission passera au statut Annulé.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Confirmer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (!mounted || confirm != true) return;
                                  final ok = await MissionService.deleteMission(
                                    rowId,
                                  );
                                  if (!mounted) return;
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mission annulée'),
                                      ),
                                    );
                                    _load();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Échec de la suppression',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  // Zebra striping : lignes paires légèrement colorées
                  final zebraColor = idx.isOdd
                      ? null
                      : WidgetStateProperty.all(const Color(0xFFF8FAFC));
                  return DataRow(
                    selected: selected,
                    color: selected ? null : zebraColor,
                    onSelectChanged: isBillable
                        ? (v) {
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
                          }
                        : null,
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
    final isCompactLayout = MediaQuery.of(context).size.width < 860;
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
      body: SafeArea(
        child: isCompactLayout
            ? Column(
                children: [
                  _buildCompactWorkspaceSwitcher(),
                  Expanded(child: _buildTableScreen(spacing)),
                ],
              )
            : Row(
                children: [
                  _buildSidebar(spacing),
                  Expanded(child: _buildTableScreen(spacing)),
                ],
              ),
      ),
    );
  }
}

class _MissionFormPanel extends StatefulWidget {
  const _MissionFormPanel({
    required this.isCreation,
    required this.missionTypeChoices,
    required this.workflowOptions,
    required this.workflowLabels,
    required this.labelForStatus,
    required this.languageEntries,
    required this.languageOptions,
    required this.decodeMissionTypes,
    required this.dateDisplayFormat,
    required this.timeDisplayFormat,
    required this.dateApiFormat,
    required this.parseMissionDate,
    required this.parseMissionTime,
    required this.formatTimeOfDay,
    required this.parseDurationMinutes,
    required this.parseDateTimeInput,
    required this.formatDateTimeForApi,
    required this.friendlyMissionError,
    required this.embedded,
    this.mission,
    this.onSuccess,
    this.onCancel,
  });

  final bool isCreation;
  final Map<String, dynamic>? mission;
  final List<String> missionTypeChoices;
  final List<String> workflowOptions;
  final Map<String, String> workflowLabels;
  final String Function(String code) labelForStatus;
  final List<_AutocompleteEntry<String>> languageEntries;
  final List<String> languageOptions;
  final List<String> Function(dynamic raw) decodeMissionTypes;
  final DateFormat dateDisplayFormat;
  final DateFormat timeDisplayFormat;
  final DateFormat dateApiFormat;
  final DateTime? Function(String raw) parseMissionDate;
  final TimeOfDay? Function(String raw) parseMissionTime;
  final String Function(TimeOfDay time) formatTimeOfDay;
  final int? Function(String input) parseDurationMinutes;
  final DateTime? Function(String date, String time) parseDateTimeInput;
  final String Function(DateTime dt) formatDateTimeForApi;
  final String Function(String? message, {required bool isCreation})
  friendlyMissionError;
  final void Function(bool created)? onSuccess;
  final VoidCallback? onCancel;
  final bool embedded;

  @override
  State<_MissionFormPanel> createState() => _MissionFormPanelState();
}

class _MissionFormPanelState extends State<_MissionFormPanel> {
  late final TextEditingController _langueCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _heureCtrl;
  late final TextEditingController _dureeCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _commentaireCtrl;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _interpreterCtrl;
  late final TextEditingController _statusCtrl;
  final ScrollController _formScrollCtrl = ScrollController();

  int? _missionId;
  int? _selectedInterpreterId;
  int? _selectedClientId;
  int? _selectedContactId;
  String? _selectedLanguageRef;
  DateTime? _selectedMissionDate;
  TimeOfDay? _selectedMissionTime;
  Set<String> _selectedMissionTypes = <String>{};
  String _selectedStatusCode = '';
  List<String> _statusCodes = <String>[];
  List<ContactInfo> _contactOptions = <ContactInfo>[];
  final Map<int, List<ContactInfo>> _contactsCache = {};
  bool _contactsLoading = false;
  bool _lookupsLoading = true;
  bool _submitting = false;
  String? _validationMessage;
  String? _successMessage;
  bool _showCreatedSummary = false;
  Map<String, dynamic>? _createdMissionSnapshot;
  List<Map<String, dynamic>> _interpretes = <Map<String, dynamic>>[];
  List<ClientSummary> _clientSummaries = <ClientSummary>[];
  String _initialClientName = '';
  String _initialContactName = '';
  String _initialInterpreterName = '';
  Timer? _clientSearchDebounce;
  Timer? _contactSearchDebounce;
  Timer? _interpreterSearchDebounce;
  Timer? _languageSearchDebounce;
  int _clientSearchRequestId = 0;
  int _interpreterSearchRequestId = 0;
  int _languageSearchRequestId = 0;
  bool _clientSearchLoading = false;
  bool _interpreterSearchLoading = false;
  bool _languageSearchLoading = false;
  String _lastClientSearchQuery = '';
  String _lastInterpreterSearchQuery = '';
  List<_AutocompleteEntry<String>> _languageSearchEntries =
      <_AutocompleteEntry<String>>[];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadLookups();
  }

  @override
  void dispose() {
    _clientSearchDebounce?.cancel();
    _contactSearchDebounce?.cancel();
    _interpreterSearchDebounce?.cancel();
    _languageSearchDebounce?.cancel();
    _langueCtrl.dispose();
    _dateCtrl.dispose();
    _heureCtrl.dispose();
    _dureeCtrl.dispose();
    _labelCtrl.dispose();
    _commentaireCtrl.dispose();
    _clientCtrl.dispose();
    _contactCtrl.dispose();
    _interpreterCtrl.dispose();
    _statusCtrl.dispose();
    _formScrollCtrl.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    final mission = widget.mission;
    _missionId = int.tryParse(
      (mission?['rowid'] ?? mission?['id'] ?? '0').toString(),
    );
    _langueCtrl = TextEditingController(
      text: (mission?['produit_ref'] ?? '').toString(),
    );
    _dateCtrl = TextEditingController(
      text: (mission?['datemission'] ?? '').toString(),
    );
    _heureCtrl = TextEditingController(
      text: (mission?['heuredebutmission'] ?? '').toString(),
    );
    _dureeCtrl = TextEditingController(
      text: (mission?['dureemission'] ?? '').toString(),
    );
    _labelCtrl = TextEditingController(
      text: (mission?['label'] ?? '').toString(),
    );
    _commentaireCtrl = TextEditingController(
      text: (mission?['commentaires'] ?? mission?['description'] ?? '')
          .toString(),
    );

    final initialLanguageRef = (mission?['produit_ref'] ?? '').toString().trim();
    final initialLanguageLabel = (mission?['produit_label'] ?? '').toString().trim();
    if (initialLanguageLabel.isNotEmpty) {
      _langueCtrl.text = initialLanguageLabel;
    } else if (initialLanguageRef.isNotEmpty) {
      _langueCtrl.text = initialLanguageRef;
    }

    _selectedLanguageRef = initialLanguageRef.isEmpty ? null : initialLanguageRef;

    _selectedMissionDate = widget.parseMissionDate(_dateCtrl.text);
    if (_selectedMissionDate != null) {
      _dateCtrl.text = widget.dateDisplayFormat.format(_selectedMissionDate!);
    }
    _selectedMissionTime = widget.parseMissionTime(_heureCtrl.text);
    if (_selectedMissionTime != null) {
      _heureCtrl.text = widget.formatTimeOfDay(_selectedMissionTime!);
    }

    _selectedInterpreterId = int.tryParse(
      (mission?['nominterprete'] ?? mission?['interpreter_id'] ?? '')
          .toString(),
    );
    _initialInterpreterName = (mission?['interpreter_name'] ?? '')
        .toString()
        .trim();

    _selectedClientId = int.tryParse(
      (mission?['client_id'] ?? mission?['fk_soc'] ?? '').toString(),
    );
    _initialClientName = (mission?['client_name'] ?? '').toString().trim();
    _selectedContactId = int.tryParse(
      (mission?['contact_id'] ?? mission?['contactdemandeur'] ?? '').toString(),
    );
    final prenom = (mission?['prenom_demandeur'] ?? '').toString().trim();
    final nom = (mission?['nom_demandeur'] ?? '').toString().trim();
    final combined = [
      prenom,
      nom,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    _initialContactName = combined.isNotEmpty
        ? combined
        : (mission?['contactdemandeur_name'] ?? '').toString().trim();

    _clientCtrl = TextEditingController(
      text: (_selectedClientId != null && _selectedClientId! > 0)
          ? (_initialClientName.isEmpty
                ? 'Client #${_selectedClientId!}'
                : _initialClientName)
          : '',
    );
    _contactCtrl = TextEditingController(
      text: (_selectedContactId != null && _selectedContactId! > 0)
          ? (_initialContactName.isEmpty
                ? 'Contact #${_selectedContactId!}'
                : _initialContactName)
          : '',
    );
    _interpreterCtrl = TextEditingController(
      text: (_selectedInterpreterId != null && _selectedInterpreterId! > 0)
          ? (_initialInterpreterName.isEmpty
                ? 'Interprète #${_selectedInterpreterId!}'
                : _initialInterpreterName)
          : '',
    );

    _selectedMissionTypes = widget
        .decodeMissionTypes(mission?['mission_types'])
        .toSet();
    if (_selectedMissionTypes.isEmpty &&
        widget.missionTypeChoices.contains('Interprétariat')) {
      _selectedMissionTypes.add('Interprétariat');
    }

    final rawStatus = (mission?['mission_status'] ?? '').toString().trim();
    final statusCodeSet = <String>{
      ...widget.workflowLabels.keys,
      ...widget.workflowOptions.where((code) => code != 'Tous'),
    }..add(rawStatus);
    int compareStatus(String a, String b) {
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      if (ai != null) return -1;
      if (bi != null) return 1;
      return a.compareTo(b);
    }

    _statusCodes =
        statusCodeSet.where((code) => code.trim().isNotEmpty).toList()
          ..sort(compareStatus);
    if (_statusCodes.isEmpty) {
      _statusCodes.add('1');
    }
    _selectedStatusCode = rawStatus.isEmpty ? _statusCodes.first : rawStatus;
    if (_selectedStatusCode.isEmpty) {
      _selectedStatusCode = _statusCodes.first;
    }
    _statusCtrl = TextEditingController(
      text: widget.labelForStatus(_selectedStatusCode),
    );
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        MissionService.getInterpretes(limit: 1000),
        ClientService.getClientSummaries(limit: 10000),
      ]);
      if (!mounted) return;
      setState(() {
        _interpretes = results[0] as List<Map<String, dynamic>>;
        _clientSummaries = results[1] as List<ClientSummary>;
        _lookupsLoading = false;
      });
      if (_selectedClientId != null && _selectedClientId! > 0) {
        await _loadContactsForClient(_selectedClientId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lookupsLoading = false;
      });
    }
  }

  void _clearContactSelection({
    bool clearText = false,
    bool clearOptions = false,
  }) {
    _selectedContactId = null;
    if (clearOptions) {
      _contactOptions = <ContactInfo>[];
    }
    if (clearText) {
      _contactCtrl.clear();
    }
  }

  void _clearClientSelection({bool clearText = false}) {
    _selectedClientId = null;
    _clearContactSelection(clearText: true, clearOptions: true);
    if (clearText) {
      _clientCtrl.clear();
    }
    _lastClientSearchQuery = '';
  }

  void _clearInterpreterSelection({bool clearText = false}) {
    _selectedInterpreterId = null;
    if (clearText) {
      _interpreterCtrl.clear();
    }
    _lastInterpreterSearchQuery = '';
  }

  void _clearLanguageSelection({
    bool clearText = false,
    bool clearSuggestions = false,
  }) {
    _selectedLanguageRef = null;
    if (clearText) {
      _langueCtrl.clear();
    }
    if (clearSuggestions) {
      _languageSearchEntries = <_AutocompleteEntry<String>>[];
    }
  }

  void _resetAutocompleteSearchState() {
    _clientSearchDebounce?.cancel();
    _contactSearchDebounce?.cancel();
    _interpreterSearchDebounce?.cancel();
    _languageSearchDebounce?.cancel();
    _clientSearchRequestId++;
    _interpreterSearchRequestId++;
    _languageSearchRequestId++;
    _clientSearchLoading = false;
    _contactsLoading = false;
    _interpreterSearchLoading = false;
    _languageSearchLoading = false;
    _lastClientSearchQuery = '';
    _lastInterpreterSearchQuery = '';
    _languageSearchEntries = <_AutocompleteEntry<String>>[];
  }

  void _restoreDefaultLookupSuggestions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleClientSearch('', immediate: true);
      _scheduleInterpreterSearch('', immediate: true);
    });
  }

  Future<void> _openRequestersManagement() async {
    await Navigator.of(context).pushNamed('/requesters');
    if (!mounted) return;

    await _loadLookups();
    if (!mounted) return;

    if (_selectedClientId != null && _selectedClientId! > 0) {
      await _loadContactsForClient(_selectedClientId);
      if (!mounted) return;
    }

    setState(() {
      _validationMessage = null;
    });
  }

  void _scheduleClientSearch(String query, {bool immediate = false}) {
    _clientSearchDebounce?.cancel();
    final normalized = query.trim();
    if (!immediate && normalized == _lastClientSearchQuery) {
      return;
    }

    void runSearch() {
      _searchClients(normalized);
    }

    if (immediate) {
      runSearch();
      return;
    }

    _clientSearchDebounce = Timer(const Duration(milliseconds: 250), runSearch);
  }

  Future<void> _searchClients(String query) async {
    final normalized = query.trim();
    final int requestId = ++_clientSearchRequestId;
    _lastClientSearchQuery = normalized;

    if (mounted) {
      setState(() {
        _clientSearchLoading = true;
      });
    }

    try {
      final results = await ClientService.getClientSummaries(
        query: normalized.isEmpty ? null : normalized,
        limit: normalized.isEmpty ? 10000 : 1000,
      );
      if (!mounted || requestId != _clientSearchRequestId) return;
      setState(() {
        _clientSummaries = results;
        _clientSearchLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _clientSearchRequestId) return;
      setState(() {
        _clientSearchLoading = false;
      });
    }
  }

  void _scheduleInterpreterSearch(String query, {bool immediate = false}) {
    _interpreterSearchDebounce?.cancel();
    final normalized = query.trim();
    if (!immediate && normalized == _lastInterpreterSearchQuery) {
      return;
    }

    void runSearch() {
      _searchInterpreters(normalized);
    }

    if (immediate) {
      runSearch();
      return;
    }

    _interpreterSearchDebounce = Timer(
      const Duration(milliseconds: 250),
      runSearch,
    );
  }

  Future<void> _searchInterpreters(String query) async {
    final normalized = query.trim();
    final int requestId = ++_interpreterSearchRequestId;
    _lastInterpreterSearchQuery = normalized;

    if (mounted) {
      setState(() {
        _interpreterSearchLoading = true;
      });
    }

    try {
      final results = await MissionService.getInterpretes(
        query: normalized.isEmpty ? null : normalized,
        limit: normalized.isEmpty ? 1000 : 200,
      );
      if (!mounted || requestId != _interpreterSearchRequestId) return;
      setState(() {
        _interpretes = results;
        _interpreterSearchLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _interpreterSearchRequestId) return;
      setState(() {
        _interpreterSearchLoading = false;
      });
    }
  }

  Future<void> _searchLanguages(String query) async {
    final normalized = query.trim();
    final int requestId = ++_languageSearchRequestId;

    if (mounted) {
      setState(() {
        _languageSearchLoading = true;
      });
    }

    try {
      final results = await LanguageService.getLanguages(
        query: normalized.isEmpty ? null : normalized,
        limit: normalized.isEmpty ? 1000 : 200,
      );
      if (!mounted || requestId != _languageSearchRequestId) return;
      setState(() {
        _languageSearchEntries = results
            .map(
              (option) => _AutocompleteEntry<String>(
                value: option.ref.trim().isEmpty
                    ? option.displayName
                    : option.ref.trim(),
                label: option.displayName,
              ),
            )
            .toList();
        _languageSearchLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _languageSearchRequestId) return;
      setState(() {
        _languageSearchLoading = false;
      });
    }
  }

  Future<void> _loadContactsForClient(int? clientId) async {
    if (clientId == null || clientId <= 0) {
      setState(() {
        _clearContactSelection(clearText: true, clearOptions: true);
        _contactsLoading = false;
      });
      return;
    }
    if (_contactsCache.containsKey(clientId)) {
      setState(() {
        _contactOptions = _contactsCache[clientId]!;
        _contactsLoading = false;
      });
      _syncContactController();
      return;
    }
    setState(() {
      _contactsLoading = true;
      _contactOptions = <ContactInfo>[];
    });
    try {
      final fetched = await ContactService.getContactsForClient(
        clientId: clientId,
      );
      if (!mounted) return;
      setState(() {
        _contactsCache[clientId] = fetched;
        _contactOptions = fetched;
        _contactsLoading = false;
      });
      _syncContactController();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contactsLoading = false;
      });
    }
  }

  void _syncContactController() {
    if (_selectedContactId == null) {
      _contactCtrl.text = '';
      return;
    }
    ContactInfo? match;
    for (final contact in _contactOptions) {
      if (contact.id == _selectedContactId) {
        match = contact;
        break;
      }
    }
    if (match != null) {
      _contactCtrl.text = match.displayName;
    } else {
      _selectedContactId = null;
      _contactCtrl.text = '';
    }
  }

  ContactInfo? _findContactMatchByDisplayName(
    Iterable<ContactInfo> contacts,
    String rawValue,
  ) {
    final normalized = rawValue
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    if (normalized.isEmpty) return null;
    for (final contact in contacts) {
      final displayName = contact.displayName
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .toLowerCase();
      if (displayName == normalized) {
        return contact;
      }
    }
    return null;
  }

  Future<void> _resolveContactSelectionFromInput() async {
    if ((_selectedContactId ?? 0) > 0) return;
    final clientId = _selectedClientId;
    final rawValue = _contactCtrl.text.trim();
    if (clientId == null || clientId <= 0 || rawValue.isEmpty) return;

    ContactInfo? match = _findContactMatchByDisplayName(
      _contactOptions,
      rawValue,
    );
    if (match == null && _contactsCache.containsKey(clientId)) {
      match = _findContactMatchByDisplayName(
        _contactsCache[clientId]!,
        rawValue,
      );
    }
    if (match == null) {
      final fetched = await ContactService.getContactsForClient(
        clientId: clientId,
        limit: 500,
      );
      if (!mounted) return;
      match = _findContactMatchByDisplayName(fetched, rawValue);
      setState(() {
        _contactsCache[clientId] = fetched;
        _contactOptions = fetched;
      });
    }

    if (match == null || !mounted) return;
    setState(() {
      _selectedContactId = match!.id;
      _contactCtrl.value = TextEditingValue(
        text: match.displayName,
        selection: TextSelection.collapsed(offset: match.displayName.length),
      );
      _validationMessage = null;
    });
  }

  Future<void> _showContactPicker() async {
    final clientId = _selectedClientId;
    if (clientId == null || clientId <= 0) {
      setState(() {
        _validationMessage = 'Sélectionnez d’abord une société demandeuse';
      });
      return;
    }

    if (_contactsLoading) return;

    if (_contactOptions.isEmpty && !_contactsCache.containsKey(clientId)) {
      await _loadContactsForClient(clientId);
      if (!mounted) return;
    }

    final contacts = List<ContactInfo>.from(_contactOptions);
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun contact disponible pour cette société.'),
        ),
      );
      return;
    }

    ContactInfo? selectedContact;
    String filter = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            final normalizedFilter = filter.trim().toLowerCase();
            final filteredContacts = contacts
                .where((contact) {
                  if (normalizedFilter.isEmpty) return true;
                  return contact.displayName.toLowerCase().contains(
                        normalizedFilter,
                      ) ||
                      contact.email.toLowerCase().contains(normalizedFilter) ||
                      contact.phone.toLowerCase().contains(normalizedFilter) ||
                      contact.mobile.toLowerCase().contains(normalizedFilter);
                })
                .toList(growable: false);

            return AlertDialog(
              title: const Text('Personne demandeuse'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un contact',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setLocalState(() {
                          filter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredContacts.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun contact trouvé pour cette recherche.',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredContacts.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final contact = filteredContacts[index];
                                final subtitleParts = <String>[
                                  if (contact.email.trim().isNotEmpty)
                                    contact.email.trim(),
                                  if (contact.phone.trim().isNotEmpty)
                                    contact.phone.trim(),
                                  if (contact.mobile.trim().isNotEmpty)
                                    contact.mobile.trim(),
                                ];
                                return ListTile(
                                  title: Text(contact.displayName),
                                  subtitle: subtitleParts.isEmpty
                                      ? null
                                      : Text(subtitleParts.join(' • ')),
                                  onTap: () {
                                    selectedContact = contact;
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || selectedContact == null) return;

    final displayName = selectedContact!.displayName;
    setState(() {
      _selectedContactId = selectedContact!.id;
      _contactCtrl.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
      _validationMessage = null;
    });
  }

  Future<_AutocompleteEntry<T>?> _showEntryPicker<T>({
    required String title,
    required List<_AutocompleteEntry<T>> entries,
    String emptyMessage = 'Aucun résultat disponible.',
    String? Function(_AutocompleteEntry<T> option)? subtitleBuilder,
  }) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emptyMessage)));
      return null;
    }

    _AutocompleteEntry<T>? selectedEntry;
    String filter = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            final normalizedFilter = filter.trim().toLowerCase();
            final filteredEntries = entries
                .where((entry) {
                  if (normalizedFilter.isEmpty) return true;
                  final subtitle =
                      subtitleBuilder?.call(entry)?.toLowerCase() ?? '';
                  return entry.label.toLowerCase().contains(normalizedFilter) ||
                      subtitle.contains(normalizedFilter) ||
                      entry.value.toString().toLowerCase().contains(
                        normalizedFilter,
                      );
                })
                .toList(growable: false);

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setLocalState(() {
                          filter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredEntries.isEmpty
                          ? Center(child: Text(emptyMessage))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredEntries.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = filteredEntries[index];
                                final subtitle = subtitleBuilder?.call(entry);
                                return ListTile(
                                  title: Text(entry.label),
                                  subtitle: subtitle == null
                                      ? null
                                      : Text(subtitle),
                                  onTap: () {
                                    selectedEntry = entry;
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    return selectedEntry;
  }

  Future<void> _showClientPicker() async {
    if (_clientSearchLoading) return;
    if (_clientSummaries.isEmpty) {
      await _searchClients('');
      if (!mounted) return;
    }

    List<_AutocompleteEntry<int>> entries = _buildClientEntries();
    _AutocompleteEntry<int>? selectedEntry;
    Timer? debounce;
    int requestId = 0;
    bool loading = false;
    String emptyMessage = 'Aucune société disponible.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            Future<void> runSearch(String rawQuery) async {
              final normalized = rawQuery.trim();
              final int currentRequestId = ++requestId;
              setLocalState(() {
                loading = true;
              });

              try {
                final results = await ClientService.getClientSummaries(
                  query: normalized.isEmpty ? null : normalized,
                  limit: normalized.isEmpty ? 10000 : 1000,
                );
                if (!mounted || currentRequestId != requestId) return;

                final mappedEntries =
                    results
                        .map(
                          (client) => _AutocompleteEntry<int>(
                            value: client.id,
                            label: client.name.isEmpty
                                ? 'Client #${client.id}'
                                : client.name,
                          ),
                        )
                        .toList()
                      ..sort(
                        (a, b) => a.label.toLowerCase().compareTo(
                          b.label.toLowerCase(),
                        ),
                      );

                if (_selectedClientId != null &&
                    _selectedClientId! > 0 &&
                    !mappedEntries.any(
                      (entry) => entry.value == _selectedClientId,
                    )) {
                  final fallback = _initialClientName.isEmpty
                      ? 'Client #${_selectedClientId!}'
                      : '$_initialClientName (hors liste)';
                  mappedEntries.insert(
                    0,
                    _AutocompleteEntry<int>(
                      value: _selectedClientId!,
                      label: fallback,
                    ),
                  );
                }

                setState(() {
                  _clientSummaries = results;
                });
                setLocalState(() {
                  entries = mappedEntries;
                  loading = false;
                  emptyMessage = normalized.isEmpty
                      ? 'Aucune société disponible.'
                      : 'Aucune société trouvée pour cette recherche.';
                });
              } catch (_) {
                if (!mounted || currentRequestId != requestId) return;
                setLocalState(() {
                  loading = false;
                  entries = const <_AutocompleteEntry<int>>[];
                  emptyMessage = 'Recherche société indisponible.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Société demandeuse'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une société',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => runSearch(value),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Flexible(
                      child: entries.isEmpty
                          ? Center(child: Text(emptyMessage))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: entries.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return ListTile(
                                  title: Text(entry.label),
                                  subtitle: Text('ID ${entry.value}'),
                                  onTap: () {
                                    selectedEntry = entry;
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    debounce?.cancel();
    if (!mounted || selectedEntry == null) return;

    final label = selectedEntry!.label;
    setState(() {
      _selectedClientId = selectedEntry!.value;
      _clientCtrl.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
      _clearContactSelection(clearText: true, clearOptions: true);
      _validationMessage = null;
    });
    await _loadContactsForClient(selectedEntry!.value);
  }

  Future<void> _showInterpreterPicker() async {
    if (_interpreterSearchLoading) return;
    if (_interpretes.isEmpty) {
      await _searchInterpreters('');
      if (!mounted) return;
    }

    List<_AutocompleteEntry<int>> entries = _buildInterpreterEntries();
    _AutocompleteEntry<int>? selectedEntry;
    Timer? debounce;
    int requestId = 0;
    bool loading = false;
    String emptyMessage = 'Aucun interprète disponible.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            Future<void> runSearch(String rawQuery) async {
              final normalized = rawQuery.trim();
              final int currentRequestId = ++requestId;
              setLocalState(() {
                loading = true;
              });

              try {
                final results = await MissionService.getInterpretes(
                  query: normalized.isEmpty ? null : normalized,
                  limit: normalized.isEmpty ? 1000 : 200,
                );
                if (!mounted || currentRequestId != requestId) return;

                final mappedEntries =
                    results
                        .map((entry) {
                          final id = int.tryParse(
                            (entry['id'] ?? '').toString(),
                          );
                          if (id == null) return null;
                          final rawName = (entry['display_name'] ?? '')
                              .toString()
                              .trim();
                          final label = rawName.isEmpty
                              ? 'Interprète #$id'
                              : rawName;
                          return _AutocompleteEntry<int>(
                            value: id,
                            label: label,
                          );
                        })
                        .whereType<_AutocompleteEntry<int>>()
                        .toList()
                      ..sort(
                        (a, b) => a.label.toLowerCase().compareTo(
                          b.label.toLowerCase(),
                        ),
                      );

                if (_selectedInterpreterId != null &&
                    _selectedInterpreterId! > 0 &&
                    !mappedEntries.any(
                      (entry) => entry.value == _selectedInterpreterId,
                    )) {
                  final fallback = _initialInterpreterName.isEmpty
                      ? 'Interprète #${_selectedInterpreterId!}'
                      : '$_initialInterpreterName (hors liste)';
                  mappedEntries.insert(
                    0,
                    _AutocompleteEntry<int>(
                      value: _selectedInterpreterId!,
                      label: fallback,
                    ),
                  );
                }

                setState(() {
                  _interpretes = results;
                });
                setLocalState(() {
                  entries = mappedEntries;
                  loading = false;
                  emptyMessage = normalized.isEmpty
                      ? 'Aucun interprète disponible.'
                      : 'Aucun interprète trouvé pour cette recherche.';
                });
              } catch (_) {
                if (!mounted || currentRequestId != requestId) return;
                setLocalState(() {
                  loading = false;
                  entries = const <_AutocompleteEntry<int>>[];
                  emptyMessage = 'Recherche interprète indisponible.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Interprète'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un interprète',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => runSearch(value),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Flexible(
                      child: entries.isEmpty
                          ? Center(child: Text(emptyMessage))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: entries.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return ListTile(
                                  title: Text(entry.label),
                                  subtitle: Text('ID ${entry.value}'),
                                  onTap: () {
                                    selectedEntry = entry;
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    debounce?.cancel();
    if (!mounted || selectedEntry == null) return;

    final label = selectedEntry!.label;
    setState(() {
      _selectedInterpreterId = selectedEntry!.value;
      _interpreterCtrl.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
      _validationMessage = null;
    });
  }

  Future<void> _showLanguagePicker() async {
    if (_languageSearchLoading) return;

    // Always reopen from the full loaded list instead of a stale previous search.
    if (_languageSearchEntries.isNotEmpty && widget.languageEntries.isNotEmpty) {
      setState(() {
        _languageSearchEntries = <_AutocompleteEntry<String>>[];
      });
    }

    if (_languageSearchEntries.isEmpty && widget.languageEntries.isEmpty) {
      await _searchLanguages('');
      if (!mounted) return;
    }

    List<_AutocompleteEntry<String>> entries = _buildLanguageEntries();
    _AutocompleteEntry<String>? selectedEntry;
    Timer? debounce;
    int requestId = 0;
    bool loading = false;
    String emptyMessage = 'Aucune langue disponible.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            Future<void> runSearch(String rawQuery) async {
              final normalized = rawQuery.trim();
              final int currentRequestId = ++requestId;
              setLocalState(() {
                loading = true;
              });

              try {
                final results = await LanguageService.getLanguages(
                  query: normalized.isEmpty ? null : normalized,
                  limit: 10000,
                );
                if (!mounted || currentRequestId != requestId) return;

                final mappedEntries = results
                    .map(
                      (option) => _AutocompleteEntry<String>(
                        value: option.ref.trim().isEmpty
                            ? option.displayName
                            : option.ref.trim(),
                        label: option.displayName,
                      ),
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        a.label.toLowerCase().compareTo(b.label.toLowerCase()),
                  );

                setState(() {
                  _languageSearchEntries = mappedEntries;
                });
                setLocalState(() {
                  entries = mappedEntries;
                  loading = false;
                  emptyMessage = normalized.isEmpty
                      ? 'Aucune langue disponible.'
                      : 'Aucune langue trouvée pour cette recherche.';
                });
              } catch (_) {
                if (!mounted || currentRequestId != requestId) return;
                setLocalState(() {
                  loading = false;
                  entries = const <_AutocompleteEntry<String>>[];
                  emptyMessage = 'Recherche langue indisponible.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Langue'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une langue',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => runSearch(value),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Flexible(
                      child: entries.isEmpty
                          ? Center(child: Text(emptyMessage))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: entries.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return ListTile(
                                  title: Text(entry.label),
                                  onTap: () {
                                    selectedEntry = entry;
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    debounce?.cancel();
    if (!mounted || selectedEntry == null) return;

    final label = selectedEntry!.label;
    setState(() {
      _selectedLanguageRef = selectedEntry!.value.trim();
      _langueCtrl.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
      _validationMessage = null;
    });
  }

  Future<void> _showStatusPicker() async {
    final selected = await _showEntryPicker<String>(
      title: 'Statut mission',
      entries: _buildStatusEntries(),
      emptyMessage: 'Aucun statut disponible.',
      subtitleBuilder: (option) => option.value,
    );
    if (!mounted || selected == null) return;

    final label = selected.label;
    setState(() {
      _selectedStatusCode = selected.value;
      _statusCtrl.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
    });
  }

  List<_AutocompleteEntry<int>> _buildClientEntries() {
    final entries =
        _clientSummaries
            .map(
              (client) => _AutocompleteEntry<int>(
                value: client.id,
                label: client.name.isEmpty
                    ? 'Client #${client.id}'
                    : client.name,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    if (_selectedClientId != null &&
        _selectedClientId! > 0 &&
        !entries.any((entry) => entry.value == _selectedClientId)) {
      final fallback = _initialClientName.isEmpty
          ? 'Client #${_selectedClientId!}'
          : '$_initialClientName (hors liste)';
      entries.insert(
        0,
        _AutocompleteEntry<int>(value: _selectedClientId!, label: fallback),
      );
    }
    return entries;
  }

  List<_AutocompleteEntry<int>> _buildInterpreterEntries() {
    final entries =
        _interpretes
            .map((entry) {
              final id = int.tryParse((entry['id'] ?? '').toString());
              if (id == null) return null;
              final rawName = (entry['display_name'] ?? '').toString().trim();
              final label = rawName.isEmpty ? 'Interprète #$id' : rawName;
              return _AutocompleteEntry<int>(value: id, label: label);
            })
            .whereType<_AutocompleteEntry<int>>()
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    if (_selectedInterpreterId != null &&
        _selectedInterpreterId! > 0 &&
        !entries.any((entry) => entry.value == _selectedInterpreterId)) {
      final fallback = _initialInterpreterName.isEmpty
          ? 'Interprète #${_selectedInterpreterId!}'
          : '$_initialInterpreterName (hors liste)';
      entries.insert(
        0,
        _AutocompleteEntry<int>(
          value: _selectedInterpreterId!,
          label: fallback,
        ),
      );
    }
    return entries;
  }

  List<_AutocompleteEntry<String>> _buildLanguageEntries() {
    if (_languageSearchEntries.isNotEmpty) {
      return _languageSearchEntries;
    }
    if (widget.languageEntries.isNotEmpty) {
      return widget.languageEntries;
    }
    return widget.languageOptions
        .map((label) => _AutocompleteEntry<String>(value: label, label: label))
        .toList();
  }

  List<_AutocompleteEntry<String>> _buildStatusEntries() {
    return _statusCodes
        .where((code) => code.trim().isNotEmpty)
        .map(
          (code) => _AutocompleteEntry<String>(
            value: code,
            label: widget.labelForStatus(code),
          ),
        )
        .toList();
  }

  bool get _isEditingExistingMission =>
      (_missionId ?? 0) > 0 &&
      (!widget.isCreation || _showCreatedSummary == false);

  Map<String, dynamic> _buildMissionSnapshot(MissionApiResult result) {
    final dynamic rawId = result.data?['id'];
    final int? createdId = rawId == null
        ? null
        : int.tryParse(rawId.toString());
    final String ref = (result.data?['ref'] ?? '').toString().trim();
    return <String, dynamic>{
      'rowid': createdId ?? _missionId,
      'reference_devis': ref,
      'mission_types': _selectedMissionTypes.toList(),
      'label': _labelCtrl.text.trim(),
      'datemission': _dateCtrl.text.trim(),
      'heuredebutmission': _heureCtrl.text.trim(),
      'dureemission': _dureeCtrl.text.trim(),
      'client_name': _clientCtrl.text.trim(),
      'contact_name': _contactCtrl.text.trim(),
      'interpreter_name': _interpreterCtrl.text.trim(),
      'produit_ref': _langueCtrl.text.trim(),
      'mission_status': _selectedStatusCode,
      'commentaires': _commentaireCtrl.text.trim(),
    };
  }

  void _startNewMissionEntry() {
    setState(() {
      _missionId = null;
      _createdMissionSnapshot = null;
      _showCreatedSummary = false;
      _successMessage = null;
      _resetForm();
    });
  }

  void _startDuplicatedMissionEntry() {
    setState(() {
      _missionId = null;
      _showCreatedSummary = false;
      _successMessage = null;
      _validationMessage = null;
    });
  }

  Widget _buildSummaryField(String label, String value) {
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedMissionSummary() {
    final snapshot = _createdMissionSnapshot!;
    final String statusLabel = widget.labelForStatus(
      (snapshot['mission_status'] ?? '').toString(),
    );
    final String missionTypes = widget
        .decodeMissionTypes(snapshot['mission_types'])
        .join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_successMessage != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mission créée',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showCreatedSummary = false;
                    _successMessage = null;
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _startDuplicatedMissionEntry,
                icon: const Icon(Icons.content_copy),
                label: const Text('Dupliquer'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _startNewMissionEntry,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle mission'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 32,
            runSpacing: 4,
            children: [
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Réf. mission',
                  (snapshot['reference_devis'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField('Statut', statusLabel),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField('Type de mission', missionTypes),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Libellé',
                  (snapshot['label'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Date de mission',
                  (snapshot['datemission'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Heure de début',
                  (snapshot['heuredebutmission'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Durée',
                  (snapshot['dureemission'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Société demandeuse',
                  (snapshot['client_name'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Personne demandeuse',
                  (snapshot['contact_name'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Interprète',
                  (snapshot['interpreter_name'] ?? '').toString(),
                ),
              ),
              SizedBox(
                width: 260,
                child: _buildSummaryField(
                  'Langue',
                  (snapshot['produit_ref'] ?? '').toString(),
                ),
              ),
            ],
          ),
          _buildSummaryField(
            'Commentaires',
            (snapshot['commentaires'] ?? '').toString(),
          ),
        ],
      ),
    );
  }

  String? _validateMissionForm() {
    if ((_selectedContactId ?? 0) <= 0) {
      return 'Sélectionnez une personne demandeuse';
    }
    if ((_selectedClientId ?? 0) <= 0) {
      return 'Sélectionnez une société demandeuse';
    }
    if ((_selectedInterpreterId ?? 0) <= 0) {
      return 'Sélectionnez un interprète';
    }

    final langue = _langueCtrl.text.trim();
    final langueRef = _selectedLanguageRef?.trim() ?? '';
    if (langue.isEmpty && langueRef.isEmpty) {
      return 'Renseignez une langue';
    }

    final dateText = _dateCtrl.text.trim();
    final effectiveDate =
        _selectedMissionDate ?? widget.parseMissionDate(dateText);
    if (dateText.isEmpty || effectiveDate == null) {
      return 'Renseignez une date de mission valide';
    }

    return null;
  }

  Future<void> _handleSubmit() async {
    await _resolveContactSelectionFromInput();
    final validationMessage = _validateMissionForm();
    if (validationMessage != null) {
      setState(() {
        _validationMessage = validationMessage;
        _successMessage = null;
      });
      return;
    }
    setState(() {
      _validationMessage = null;
      _successMessage = null;
      _submitting = true;
    });

    final bool isCreation = (_missionId ?? 0) <= 0;
    final missionId = _missionId ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    if (!isCreation && missionId <= 0) {
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Identifiant de mission manquant')),
      );
      return;
    }

    final payload = <String, dynamic>{};
    if (!isCreation) {
      payload['id'] = missionId;
    }
    final int? interpreterId = _selectedInterpreterId;
    if (interpreterId != null && interpreterId > 0) {
      payload['interpreter_id'] = interpreterId;
    }
    payload['label'] = _labelCtrl.text.trim();
    final clientId = _selectedClientId;
    if (clientId != null && clientId > 0) {
      payload['client_id'] = clientId;
    }
    final contactId = _selectedContactId;
    if (contactId != null && contactId > 0) {
      payload['contact_id'] = contactId;
    }
    payload['commentaires'] = _commentaireCtrl.text.trim();

    final langue = _langueCtrl.text.trim();
    final langueRef = _selectedLanguageRef?.trim() ?? '';
    if (langueRef.isNotEmpty) {
      payload['produit_ref'] = langueRef;
    } else if (langue.isNotEmpty) {
      payload['produit_ref'] = langue;
    }

    final dateText = _dateCtrl.text.trim();
    final DateTime? effectiveDate =
        _selectedMissionDate ?? widget.parseMissionDate(dateText);
    String dateForComputation = '';
    if (effectiveDate != null) {
      dateForComputation = widget.dateApiFormat.format(effectiveDate);
      payload['datemission'] = dateForComputation;
    } else if (dateText.isNotEmpty) {
      dateForComputation = dateText;
      payload['datemission'] = dateText;
    }

    final heureText = _heureCtrl.text.trim();
    final TimeOfDay? effectiveTime =
        _selectedMissionTime ?? widget.parseMissionTime(heureText);
    String heureForComputation = '';
    if (effectiveTime != null) {
      heureForComputation = widget.formatTimeOfDay(effectiveTime);
      payload['heuredebutmission'] = heureForComputation;
    } else if (heureText.isNotEmpty) {
      heureForComputation = heureText;
      payload['heuredebutmission'] = heureText;
    }

    final durationText = _dureeCtrl.text.trim();
    final parsedDuration = durationText.isEmpty
        ? null
        : widget.parseDurationMinutes(durationText);
    if (durationText.isNotEmpty && parsedDuration == null) {
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Durée invalide. Utilisez 3h, 2h30, 2:30 ou 150.'),
        ),
      );
      return;
    }
    if ((parsedDuration ?? 0) > 0) {
      payload['dureemission'] = parsedDuration;
    }
    if (_selectedStatusCode.isNotEmpty) {
      final parsedStatus = int.tryParse(_selectedStatusCode);
      payload['mission_status'] = parsedStatus ?? _selectedStatusCode;
    }
    payload['mission_types'] = _selectedMissionTypes.toList();

    final start = widget.parseDateTimeInput(
      dateForComputation,
      heureForComputation,
    );
    if (start != null) {
      payload['debutmission'] = widget.formatDateTimeForApi(start);
      final end = (parsedDuration ?? 0) > 0
          ? start.add(Duration(minutes: parsedDuration!))
          : start;
      payload['finmission'] = widget.formatDateTimeForApi(end);
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
    if (result.success) {
      final snapshot = _buildMissionSnapshot(result);
      final dynamic returnedId = result.data?['id'];
      final int? resolvedMissionId = returnedId == null
          ? int.tryParse((snapshot['rowid'] ?? '').toString())
          : int.tryParse(returnedId.toString());
      setState(() {
        _submitting = false;
        _validationMessage = null;
        _missionId = resolvedMissionId ?? _missionId;
        _createdMissionSnapshot = snapshot;
        _showCreatedSummary = widget.embedded;
        _successMessage = isCreation
            ? 'Mission créée avec succès.'
            : 'Mission mise à jour avec succès.';
      });
      if (!widget.embedded) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isCreation ? 'Mission créée' : 'Mission mise à jour'),
          ),
        );
      }
      widget.onSuccess?.call(isCreation);
      if (widget.embedded) {
        _formScrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } else {
      setState(() {
        _submitting = false;
        _successMessage = null;
      });
      final msg = widget.friendlyMissionError(
        result.message,
        isCreation: isCreation,
      );
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _resetForm() {
    _dateCtrl.clear();
    _heureCtrl.clear();
    _dureeCtrl.clear();
    _labelCtrl.clear();
    _commentaireCtrl.clear();
    _clearClientSelection(clearText: true);
    _clearInterpreterSelection(clearText: true);
    _clearLanguageSelection(clearText: true, clearSuggestions: true);
    _statusCtrl.text = widget.labelForStatus(
      _statusCodes.isEmpty ? '1' : _statusCodes.first,
    );
    _selectedMissionDate = null;
    _selectedMissionTime = null;
    _selectedStatusCode = _statusCodes.isEmpty ? '1' : _statusCodes.first;
    _contactsCache.clear();
    _resetAutocompleteSearchState();
    _validationMessage = null;
    _successMessage = null;
    _selectedMissionTypes = widget.missionTypeChoices.contains('Interprétariat')
        ? {'Interprétariat'}
        : <String>{};
    _restoreDefaultLookupSuggestions();
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700));
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _formScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _formScrollCtrl,
        padding: const EdgeInsets.all(24),
        child:
            _showCreatedSummary &&
                widget.embedded &&
                _createdMissionSnapshot != null
            ? _buildCreatedMissionSummary()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lookupsLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Type de mission'),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.missionTypeChoices.map((choice) {
                                final bool selected = _selectedMissionTypes
                                    .contains(choice);
                                return FilterChip(
                                  label: Text(choice),
                                  selected: selected,
                                  onSelected: (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedMissionTypes
                                          ..clear()
                                          ..add(choice);
                                      } else {
                                        _selectedMissionTypes.remove(choice);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _labelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Libellé',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Planification'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateCtrl,
                          readOnly: true,
                          onTap: () async {
                            final now = DateTime.now();
                            final initialDate = _selectedMissionDate ?? now;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(now.year - 5),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (!mounted || picked == null) return;
                            setState(() {
                              _selectedMissionDate = picked;
                              _dateCtrl.text = widget.dateDisplayFormat.format(
                                picked,
                              );
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Date de la mission * (JJ/MM/AAAA)',
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _heureCtrl,
                          readOnly: true,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  _selectedMissionTime ?? TimeOfDay.now(),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (!mounted || picked == null) return;
                            setState(() {
                              _selectedMissionTime = picked;
                              _heureCtrl.text = widget.formatTimeOfDay(picked);
                            });
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
                          controller: _dureeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Durée (minutes)',
                            hintText: 'Ex: 3h, 2h30, 2:30 ou 150',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSectionTitle('Informations demandeur'),
                      ),
                      TextButton.icon(
                        onPressed: _openRequestersManagement,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Gérer les demandeurs'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clientCtrl,
                    readOnly: true,
                    onTap: _showClientPicker,
                    decoration: InputDecoration(
                      labelText: 'Société demandeuse *',
                      isDense: true,
                      suffixIcon: IconButton(
                        onPressed: _showClientPicker,
                        icon: const Icon(Icons.arrow_drop_down),
                        tooltip: 'Afficher les sociétés',
                      ),
                    ),
                  ),
                  if (_clientSearchLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contactCtrl,
                    readOnly: true,
                    onTap: _showContactPicker,
                    decoration: InputDecoration(
                      labelText: 'Personne demandeuse *',
                      isDense: true,
                      suffixIcon: IconButton(
                        onPressed: _showContactPicker,
                        icon: const Icon(Icons.arrow_drop_down),
                        tooltip: 'Afficher les contacts',
                      ),
                    ),
                  ),
                  if (_contactsLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Mission'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _interpreterCtrl,
                          readOnly: true,
                          onTap: _showInterpreterPicker,
                          decoration: InputDecoration(
                            labelText: 'Interprète *',
                            isDense: true,
                            suffixIcon: IconButton(
                              onPressed: _showInterpreterPicker,
                              icon: const Icon(Icons.arrow_drop_down),
                              tooltip: 'Afficher les interprètes',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _langueCtrl,
                          readOnly: true,
                          onTap: _showLanguagePicker,
                          decoration: InputDecoration(
                            labelText: 'Langue * (ref produit)',
                            isDense: true,
                            suffixIcon: IconButton(
                              onPressed: _showLanguagePicker,
                              icon: const Icon(Icons.arrow_drop_down),
                              tooltip: 'Afficher les langues',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_interpreterSearchLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_languageSearchLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentaireCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Commentaires',
                      alignLabelWithHint: true,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _statusCtrl,
                    readOnly: true,
                    onTap: _showStatusPicker,
                    decoration: InputDecoration(
                      labelText: 'Statut mission',
                      isDense: true,
                      suffixIcon: IconButton(
                        onPressed: _showStatusPicker,
                        icon: const Icon(Icons.arrow_drop_down),
                        tooltip: 'Afficher les statuts',
                      ),
                    ),
                  ),
                  if (_validationMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _validationMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onCancel != null) ...[
                        TextButton(
                          onPressed: _submitting ? null : widget.onCancel,
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      FilledButton(
                        onPressed: _submitting ? null : _handleSubmit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditingExistingMission
                                    ? 'Enregistrer'
                                    : 'Créer',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
