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
import 'missions_table_page_arguments.dart';
import 'billing_page.dart';

class _AutocompleteEntry<T> {
  final T value;
  final String label;
  const _AutocompleteEntry({required this.value, required this.label});
}

enum _MissionWorkspaceView { newMission, table }

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

  final DateFormat _dateDisplayFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateApiFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeDisplayFormat = DateFormat('HH:mm');

  // Workflow (mission_status) filter
  String _workflowFilter = 'Tous';
  final List<String> _workflowOptions = const ['Tous', '0', '1', '9'];
  List<String> _languageOptions = <String>[];
  List<_AutocompleteEntry<String>> _languageEntries = <_AutocompleteEntry<String>>[];
  _MissionWorkspaceView _activeView = _MissionWorkspaceView.table;
  bool _sidebarCollapsed = false;
  bool _filtersCollapsed = false;
  final Set<int> _selectedRowIds = <int>{};
  final Set<int> _deselectedRowIds = <int>{};
  bool _selectAllAcrossFilters = false;
  final Map<String, bool> _visibleColumns = <String, bool>{
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
    'telephone': true,
    'mobile': true,
    'facture': true,
    'statut': true,
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
  final Map<String, String> _workflowLabels = const {
    'Tous': 'Tous',
    '0': 'Brouillon',
    '1': 'Validée',
    '2': 'Envoyée',
    '3': 'Renvoyée',
    '4': 'Planifiée',
    '9': 'Payée',
  };
  bool _routeArgsHandled = false;

  @override
  void initState() {
    super.initState();
    _activeView = _MissionWorkspaceView.newMission;
    _loadLanguageOptions();
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
    if (code == 'Tous') return 'Tous les workflows';
    return _workflowLabels[code] ?? 'Statut $code';
  }

  List<String> _decodeMissionTypes(dynamic raw) {
    if (raw == null) return <String>[];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return <String>[];
    return text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String _friendlyMissionError(String? message, {required bool isCreation}) {
    final fallback = isCreation ? 'Impossible de créer la mission.' : 'Impossible de mettre à jour la mission.';
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
    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
  }

  String _formatDateTimeForApi(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  String _fmtDate(DateTime date) => _dateDisplayFormat.format(date);

  Future<void> _loadLanguageOptions() async {
    try {
      final names = await LanguageService.getLanguageDisplayNames(limit: 500);
      if (!mounted) return;
      setState(() {
        _languageOptions = names;
        _languageEntries = names
            .map((name) => _AutocompleteEntry<String>(value: name, label: name))
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
    try {
      final response = await MissionService.getMissionsDatatable(
        page: _page,
        pageSize: _pageSize,
        q: query.isEmpty ? null : query,
      );
      if (!mounted) return;
      final missions = (response['missions'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
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
    if (_statusFilter != 'Tous') {
      final needle = _statusFilter.toLowerCase();
      data = data.where((mission) => (mission['billed_status'] ?? '').toString().toLowerCase() == needle);
    }
    if (_workflowFilter != 'Tous') {
      data = data.where((mission) => (mission['mission_status'] ?? '').toString() == _workflowFilter);
    }
    final search = _searchCtrl.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      data = data.where((mission) {
        final fields = [
          mission['reference_devis'],
          mission['client_name'],
          mission['interpreter_name'],
          mission['produit_ref'],
          mission['label'],
        ];
        return fields.any(
          (value) => value != null && value.toString().toLowerCase().contains(search),
        );
      });
    }

    DateTime? start = _dateStart;
    DateTime? end = _dateEnd?.add(const Duration(days: 1));
    final today = DateTime.now();
    if (start == null && end == null) {
      switch (_dateFilter) {
        case 'Aujourd\'hui':
          start = DateTime(today.year, today.month, today.day);
          end = start.add(const Duration(days: 1));
          break;
        case '7 derniers jours':
          end = DateTime(today.year, today.month, today.day + 1);
          start = end.subtract(const Duration(days: 7));
          break;
        case '30 derniers jours':
          end = DateTime(today.year, today.month, today.day + 1);
          start = end.subtract(const Duration(days: 30));
          break;
        case 'Ce mois':
          start = DateTime(today.year, today.month, 1);
          end = DateTime(today.year, today.month + 1, 1);
          break;
      }
    }
    if (start != null || end != null) {
      data = data.where((mission) {
        final raw = (mission['datemission_iso'] ?? mission['datemission'] ?? '').toString();
        final parsed = _parseMissionDate(raw);
        if (parsed == null) return false;
        if (start != null && parsed.isBefore(start)) return false;
        if (end != null && !parsed.isBefore(end)) return false;
        return true;
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
            return !_deselectedRowIds.contains(id);
          })
          .toList(growable: false);
    }
    return rows
        .where((mission) {
          final id = int.tryParse((mission['rowid'] ?? '0').toString()) ?? 0;
          return _selectedRowIds.contains(id);
        })
        .toList(growable: false);
  }

  Future<void> _exportFilteredCsv() async {
    final rows = _filtered();
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
      'Date',
      'Heure',
      'Durée (min)',
      'Workflow',
    ];
    final buffer = StringBuffer()..writeln(headers.join(';'));
    for (final mission in rows) {
      buffer.writeln([
        mission['reference_devis'] ?? '',
        mission['client_name'] ?? '',
        mission['interpreter_name'] ?? '',
        mission['produit_ref'] ?? '',
        mission['datemission'] ?? mission['datemission_iso'] ?? '',
        mission['heuredebutmission'] ?? '',
        mission['dureemission'] ?? '',
        _labelForStatus((mission['mission_status'] ?? '').toString()),
      ].map((value) {
        final text = value.toString().replaceAll(';', ',');
        return '"${text.replaceAll('"', '""')}"';
      }).join(';'));
    }
    await downloadBytes(
      bytes: utf8.encode(buffer.toString()),
      filename: 'missions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      mimeType: 'text/csv',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export CSV généré.')),
    );
  }

  void _sortByString(String? Function(Map<String, dynamic>) selector, int columnIndex, bool ascending) {
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

  void _sortByNum(num Function(Map<String, dynamic>) selector, int columnIndex, bool ascending) {
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

  void _sortByDate(DateTime? Function(Map<String, dynamic>) selector, int columnIndex, bool ascending) {
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

  void _setActiveView(_MissionWorkspaceView view) {
    if (_activeView == view) return;
    setState(() {
      _activeView = view;
    });
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
            decoration: BoxDecoration(
              color: background,
              borderRadius: radius,
            ),
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
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
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
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: spacing / 3),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.dashboard_customize,
                      color: Color(0xFF000091)),
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
          const Spacer(),
        ],
      ),
    );
  }


  Widget _buildTableScreen(double spacing) {
    if (_activeView == _MissionWorkspaceView.newMission) {
      return _buildNewMissionScreen(spacing);
    }
    return Container(
      key: const ValueKey('missions-table-view'),
      padding: EdgeInsets.only(
        top: spacing / 4,
        left: spacing / 2,
        right: spacing / 2,
        bottom: spacing / 2,
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
                  Expanded(child: _buildTableArea()),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE5E7EB),
                  ),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 720;
                        final pageSizeDropdown = DropdownButton<int>(
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
                        );
                        final navigation = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: _busy || _page <= 1
                                  ? null
                                  : () {
                                      setState(() {
                                        _page -= 1;
                                      });
                                      _load();
                                    },
                              child: const Text('Préc.'),
                            ),
                            ElevatedButton(
                              onPressed: _busy || (_page * _pageSize >= _total)
                                  ? null
                                  : () {
                                      setState(() {
                                        _page += 1;
                                      });
                                      _load();
                                    },
                              child: const Text('Suiv.'),
                            ),
                          ],
                        );
                        final summary = Text('Page $_page • Total $_total');
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              pageSizeDropdown,
                              const SizedBox(height: 8),
                              navigation,
                              const SizedBox(height: 8),
                              summary,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            pageSizeDropdown,
                            const SizedBox(width: 8),
                            navigation,
                            const SizedBox(width: 12),
                            summary,
                          ],
                        );
                      },
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
            'Renseignez le formulaire ci-dessous pour créer une mission. '
            'L’ancien contenu de la modale est désormais disponible en plein écran.',
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
        final bool medium = constraints.maxWidth < 1080;

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
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      SizedBox(
                        width: compact
                            ? constraints.maxWidth
                            : medium
                            ? constraints.maxWidth
                            : 390,
                        child: _buildStatusFilters(compact: compact),
                      ),
                      SizedBox(
                        width: compact
                            ? constraints.maxWidth
                            : medium
                            ? constraints.maxWidth
                            : 360,
                        child: _buildSearchPanel(compact: compact),
                      ),
                      if (!compact)
                        TextButton(
                          onPressed: () =>
                              setState(() => _filtersCollapsed = true),
                          child: const Text('Masquer les filtres'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildFilterSummaryText(),
                  const SizedBox(height: 14),
                  if (compact) ...[
                    _buildDateControls(compact: true),
                    const SizedBox(height: 12),
                    _buildActionButtonsRow(compact: true),
                  ] else ...[
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 320,
                            maxWidth: 680,
                          ),
                          child: _buildDateControls(),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _buildActionButtonsRow(),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Filtres masqués. Cliquez sur "Afficher les filtres" pour modifier la recherche.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 12),
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
      'Chargées: $loaded, Après filtres: $filtered • Statut: $_statusFilter • Workflow: $_workflowFilter • Date: $dateLabel',
    );
    if (query.isNotEmpty) {
      buffer.write(' • Recherche: $query');
    }
    return Text(
      buffer.toString(),
      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
    );
  }

  Widget _buildStatusFilters({bool compact = false}) {
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
            'Statuts',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          if (compact)
            Column(
              children: [
                _buildDropdownFilter(
                  label: 'Statut facture',
                  value: _statusFilter,
                  options: _statusOptions,
                  displayLabel: (option) => _labelForBillingFilter(option),
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'Tous'),
                ),
                const SizedBox(height: 12),
                _buildDropdownFilter(
                  label: 'Statut mission',
                  value: _workflowFilter,
                  options: _workflowOptions,
                  displayLabel: (option) => _labelForStatus(option),
                  onChanged: (v) =>
                      setState(() => _workflowFilter = v ?? 'Tous'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildDropdownFilter(
                    label: 'Statut facture',
                    value: _statusFilter,
                    options: _statusOptions,
                    displayLabel: (option) => _labelForBillingFilter(option),
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'Tous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownFilter(
                    label: 'Statut mission',
                    value: _workflowFilter,
                    options: _workflowOptions,
                    displayLabel: (option) => _labelForStatus(option),
                    onChanged: (v) =>
                        setState(() => _workflowFilter = v ?? 'Tous'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel({bool compact = false}) {
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
              style: const TextStyle(
                color: Color(0xFF161616),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateControls({bool compact = false}) {
    return Wrap(
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
    final DateTime initialStart = _dateStart ?? DateTime(now.year, now.month, 1);
    final DateTime initialEndCandidate = _dateEnd ?? now;
    final DateTime initialEnd = initialEndCandidate.isBefore(initialStart) ? initialStart : initialEndCandidate;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Sélectionnez une période',
      cancelText: 'Annuler',
      confirmText: 'Appliquer',
    );

    if (picked == null) return;

    setState(() {
      _dateStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _dateEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      _dateFilter = 'Tous';
    });
  }

  Widget _buildDateResetRow({bool compact = false}) {
    final actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: [
        if (_dateStart != null || _dateEnd != null)
          TextButton(
            onPressed: () => setState(() {
              _dateStart = null;
              _dateEnd = null;
            }),
            child: const Text('Effacer'),
          ),
        TextButton(
          onPressed: () => setState(() {
            _statusFilter = 'Tous';
            _workflowFilter = 'Tous';
            _dateFilter = 'Tous';
            _dateStart = null;
            _dateEnd = null;
            _searchCtrl.clear();
          }),
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
      'statut': 140,
      'createur': 170,
      'datecrea': 160,
      'dateModif': 170,
      'modifiePar': 170,
      'actions': 130,
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
                    label: Tooltip(
                      message: 'Sélectionner toutes les missions visibles',
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
                  if (_visibleColumns['datemission'] ?? true)
                    DataColumn(
                      label: _sortableHeader('Date mission'),
                      onSort: (i, asc) => _sortByDate(
                        (m) => _parseMissionDate((m['datemission_iso'] ?? m['datemission'] ?? '').toString()),
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
                        (m) {
                          final raw = (m['date_creation_iso'] ?? m['date_creation'] ?? '').toString();
                          return DateTime.tryParse(raw) ?? _parseMissionDate(raw);
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
                          final raw = (m['date_modification_iso'] ?? m['date_modification'] ?? '').toString();
                          return DateTime.tryParse(raw) ?? _parseMissionDate(raw);
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
                        facture.isEmpty ? 'Brouillon' : facture,
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
                  Expanded(
                    child: _buildTableScreen(spacing),
                  ),
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
  final String Function(String? message, {required bool isCreation}) friendlyMissionError;
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
  List<Map<String, dynamic>> _interpretes = <Map<String, dynamic>>[];
  List<ClientSummary> _clientSummaries = <ClientSummary>[];
  String _initialClientName = '';
  String _initialContactName = '';
  String _initialInterpreterName = '';

  bool _clientFieldListenerAttached = false;
  bool _contactFieldListenerAttached = false;
  bool _interpreterFieldListenerAttached = false;
  bool _langueFieldListenerAttached = false;
  bool _statusFieldListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadLookups();
  }

  @override
  void dispose() {
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
    _missionId = int.tryParse((mission?['rowid'] ?? mission?['id'] ?? '0').toString());
    _langueCtrl = TextEditingController(text: (mission?['produit_ref'] ?? '').toString());
    _dateCtrl = TextEditingController(text: (mission?['datemission'] ?? '').toString());
    _heureCtrl = TextEditingController(text: (mission?['heuredebutmission'] ?? '').toString());
    _dureeCtrl = TextEditingController(text: (mission?['dureemission'] ?? '').toString());
    _labelCtrl = TextEditingController(text: (mission?['label'] ?? '').toString());
    _commentaireCtrl = TextEditingController(
      text: (mission?['commentaires'] ?? mission?['description'] ?? '').toString(),
    );

    _selectedLanguageRef = (mission?['produit_ref'] ?? '').toString().trim().isEmpty
        ? null
        : (mission?['produit_ref'] ?? '').toString().trim();

    _selectedMissionDate = widget.parseMissionDate(_dateCtrl.text);
    if (_selectedMissionDate != null) {
      _dateCtrl.text = widget.dateDisplayFormat.format(_selectedMissionDate!);
    }
    _selectedMissionTime = widget.parseMissionTime(_heureCtrl.text);
    if (_selectedMissionTime != null) {
      _heureCtrl.text = widget.formatTimeOfDay(_selectedMissionTime!);
    }

    _selectedInterpreterId = int.tryParse(
      (mission?['nominterprete'] ?? mission?['interpreter_id'] ?? '').toString(),
    );
    _initialInterpreterName = (mission?['interpreter_name'] ?? '').toString().trim();

    _selectedClientId = int.tryParse(
      (mission?['client_id'] ?? mission?['fk_soc'] ?? '').toString(),
    );
    _initialClientName = (mission?['client_name'] ?? '').toString().trim();
    _selectedContactId = int.tryParse(
      (mission?['contact_id'] ?? mission?['contactdemandeur'] ?? '').toString(),
    );
    final prenom = (mission?['prenom_demandeur'] ?? '').toString().trim();
    final nom = (mission?['nom_demandeur'] ?? '').toString().trim();
    final combined = [prenom, nom].where((part) => part.isNotEmpty).join(' ').trim();
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

    _selectedMissionTypes = widget.decodeMissionTypes(mission?['mission_types']).toSet();
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

    _statusCodes = statusCodeSet
        .where((code) => code.trim().isNotEmpty)
        .toList()
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
        MissionService.getInterpretes(),
        ClientService.getClientSummaries(limit: 500),
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

  Future<void> _loadContactsForClient(int? clientId) async {
    if (clientId == null || clientId <= 0) {
      setState(() {
        _contactOptions = <ContactInfo>[];
        _selectedContactId = null;
        _contactsLoading = false;
      });
      _contactCtrl.text = '';
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
      final fetched = await ContactService.getContactsForClient(clientId: clientId);
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

  List<_AutocompleteEntry<int>> _buildClientEntries() {
    final entries = _clientSummaries
        .map(
          (client) => _AutocompleteEntry<int>(
            value: client.id,
            label: client.name.isEmpty ? 'Client #${client.id}' : client.name,
          ),
        )
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
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

  List<_AutocompleteEntry<int>> _buildContactEntries() {
    final entries = _contactOptions
        .map((contact) => _AutocompleteEntry<int>(
              value: contact.id,
              label: contact.displayName,
            ))
        .toList();
    if (_selectedContactId != null &&
        _selectedContactId! > 0 &&
        !entries.any((entry) => entry.value == _selectedContactId)) {
      final fallback = _initialContactName.isEmpty
          ? 'Contact #${_selectedContactId!}'
          : '$_initialContactName (hors liste)';
      entries.insert(
        0,
        _AutocompleteEntry<int>(value: _selectedContactId!, label: fallback),
      );
    }
    return entries;
  }

  List<_AutocompleteEntry<int>> _buildInterpreterEntries() {
    final entries = _interpretes
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
    if (_selectedInterpreterId != null &&
        _selectedInterpreterId! > 0 &&
        !entries.any((entry) => entry.value == _selectedInterpreterId)) {
      final fallback = _initialInterpreterName.isEmpty
          ? 'Interprète #${_selectedInterpreterId!}'
          : '$_initialInterpreterName (hors liste)';
      entries.insert(
        0,
        _AutocompleteEntry<int>(value: _selectedInterpreterId!, label: fallback),
      );
    }
    return entries;
  }

  List<_AutocompleteEntry<String>> _buildLanguageEntries() {
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
        .map((code) => _AutocompleteEntry<String>(
              value: code,
              label: widget.labelForStatus(code),
            ))
        .toList();
  }

  Future<void> _handleSubmit() async {
    if ((_selectedInterpreterId ?? 0) <= 0) {
      setState(() {
        _validationMessage = 'Sélectionnez un interprète';
      });
      return;
    }
    setState(() {
      _validationMessage = null;
      _submitting = true;
    });

    final bool isCreation = widget.isCreation;
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
    final DateTime? effectiveDate = _selectedMissionDate ?? widget.parseMissionDate(dateText);
    String dateForComputation = '';
    if (effectiveDate != null) {
      dateForComputation = widget.dateApiFormat.format(effectiveDate);
      payload['datemission'] = dateForComputation;
    } else if (dateText.isNotEmpty) {
      dateForComputation = dateText;
      payload['datemission'] = dateText;
    }

    final heureText = _heureCtrl.text.trim();
    final TimeOfDay? effectiveTime = _selectedMissionTime ?? widget.parseMissionTime(heureText);
    String heureForComputation = '';
    if (effectiveTime != null) {
      heureForComputation = widget.formatTimeOfDay(effectiveTime);
      payload['heuredebutmission'] = heureForComputation;
    } else if (heureText.isNotEmpty) {
      heureForComputation = heureText;
      payload['heuredebutmission'] = heureText;
    }

    final parsedDuration = widget.parseDurationMinutes(_dureeCtrl.text.trim());
    if (parsedDuration == null) {
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Durée invalide. Utilisez 3h, 2h30, 2:30 ou 150.')),
      );
      return;
    }
    if (parsedDuration > 0) {
      payload['dureemission'] = parsedDuration;
    }
    if (_selectedStatusCode.isNotEmpty) {
      final parsedStatus = int.tryParse(_selectedStatusCode);
      payload['mission_status'] = parsedStatus ?? _selectedStatusCode;
    }
    payload['mission_types'] = _selectedMissionTypes.toList();

    final start = widget.parseDateTimeInput(dateForComputation, heureForComputation);
    if (start != null) {
      payload['debutmission'] = widget.formatDateTimeForApi(start);
      if (parsedDuration > 0) {
        payload['finmission'] = widget.formatDateTimeForApi(
          start.add(Duration(minutes: parsedDuration)),
        );
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
    setState(() {
      _submitting = false;
    });
    if (result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(isCreation ? 'Mission créée' : 'Mission mise à jour')),
      );
      widget.onSuccess?.call(isCreation);
      if (widget.embedded && isCreation) {
        _resetForm();
      }
    } else {
      final msg = widget.friendlyMissionError(result.message, isCreation: isCreation);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _resetForm() {
    _langueCtrl.clear();
    _dateCtrl.clear();
    _heureCtrl.clear();
    _dureeCtrl.clear();
    _labelCtrl.clear();
    _commentaireCtrl.clear();
    _clientCtrl.clear();
    _contactCtrl.clear();
    _interpreterCtrl.clear();
    _statusCtrl.text = widget.labelForStatus(_statusCodes.isEmpty ? '1' : _statusCodes.first);
    _selectedInterpreterId = null;
    _selectedClientId = null;
    _selectedContactId = null;
    _selectedLanguageRef = null;
    _selectedMissionDate = null;
    _selectedMissionTime = null;
    _selectedStatusCode = _statusCodes.isEmpty ? '1' : _statusCodes.first;
    _contactOptions = <ContactInfo>[];
    _contactsCache.clear();
    _selectedMissionTypes = widget.missionTypeChoices.contains('Interprétariat')
        ? {'Interprétariat'}
        : <String>{};
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientEntries = _buildClientEntries();
    final contactEntries = _buildContactEntries();
    final interpreterEntries = _buildInterpreterEntries();
    final languageEntries = _buildLanguageEntries();
    final statusEntries = _buildStatusEntries();

    return Scrollbar(
      controller: _formScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _formScrollCtrl,
        padding: const EdgeInsets.all(24),
        child: Column(
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
                          final bool selected = _selectedMissionTypes.contains(choice);
                          return FilterChip(
                            label: Text(choice),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedMissionTypes.add(choice);
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
                      if (picked != null) {
                        setState(() {
                          _selectedMissionDate = picked;
                          _dateCtrl.text = widget.dateDisplayFormat.format(picked);
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
                    controller: _heureCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedMissionTime ?? TimeOfDay.now(),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedMissionTime = picked;
                          _heureCtrl.text = widget.formatTimeOfDay(picked);
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
            _buildSectionTitle('Informations demandeur'),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final double dropdownWidth = constraints.maxWidth;
                return Autocomplete<_AutocompleteEntry<int>>(
                  initialValue: _clientCtrl.value,
                  displayStringForOption: (option) => option.label,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) return clientEntries;
                    return clientEntries.where(
                      (option) => option.label.toLowerCase().contains(query) ||
                          option.value.toString().contains(query),
                    );
                  },
                  onSelected: (option) {
                    setState(() {
                      _selectedClientId = option.value;
                      _clientCtrl.value = TextEditingValue(text: option.label);
                      _selectedContactId = null;
                      _contactCtrl.text = '';
                      _contactOptions = <ContactInfo>[];
                    });
                    _loadContactsForClient(option.value);
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    if (!_clientFieldListenerAttached) {
                      textEditingController.value = _clientCtrl.value;
                      textEditingController.addListener(() {
                        if (_clientCtrl.value != textEditingController.value) {
                          setState(() {
                            _clientCtrl.value = textEditingController.value;
                            _selectedClientId = null;
                            _selectedContactId = null;
                            _contactOptions = <ContactInfo>[];
                            _contactCtrl.text = '';
                          });
                        }
                      });
                      _clientFieldListenerAttached = true;
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
                final double dropdownWidth = constraints.maxWidth;
                return Autocomplete<_AutocompleteEntry<int>>(
                  initialValue: _contactCtrl.value,
                  displayStringForOption: (option) => option.label,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) return contactEntries;
                    return contactEntries.where(
                      (option) => option.label.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (option) {
                    setState(() {
                      _selectedContactId = option.value;
                      _contactCtrl.value = TextEditingValue(text: option.label);
                    });
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    if (!_contactFieldListenerAttached) {
                      textEditingController.value = _contactCtrl.value;
                      textEditingController.addListener(() {
                        if (_contactCtrl.value != textEditingController.value) {
                          setState(() {
                            _contactCtrl.value = textEditingController.value;
                            _selectedContactId = null;
                          });
                        }
                      });
                      _contactFieldListenerAttached = true;
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double dropdownWidth = constraints.maxWidth;
                      return Autocomplete<_AutocompleteEntry<int>>(
                        initialValue: _interpreterCtrl.value,
                        displayStringForOption: (option) => option.label,
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.trim().toLowerCase();
                          if (query.isEmpty) return interpreterEntries;
                          return interpreterEntries.where(
                            (option) =>
                                option.label.toLowerCase().contains(query) ||
                                option.value.toString().contains(query),
                          );
                        },
                        onSelected: (option) {
                          setState(() {
                            _selectedInterpreterId = option.value;
                            _interpreterCtrl.value = TextEditingValue(text: option.label);
                            _validationMessage = null;
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          if (!_interpreterFieldListenerAttached) {
                            textEditingController.value = _interpreterCtrl.value;
                            textEditingController.addListener(() {
                              if (_interpreterCtrl.value != textEditingController.value) {
                                setState(() {
                                  _interpreterCtrl.value = textEditingController.value;
                                  _selectedInterpreterId = null;
                                });
                              }
                            });
                            _interpreterFieldListenerAttached = true;
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
                      return Autocomplete<_AutocompleteEntry<String>>(
                        initialValue: _langueCtrl.value,
                        displayStringForOption: (option) => option.label,
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.trim().toLowerCase();
                          if (languageEntries.isEmpty) {
                            return const Iterable<_AutocompleteEntry<String>>.empty();
                          }
                          if (query.isEmpty) {
                            return languageEntries;
                          }
                          return languageEntries.where((option) {
                            return option.label.toLowerCase().contains(query) ||
                                option.value.toLowerCase().contains(query);
                          });
                        },
                        onSelected: (option) {
                          setState(() {
                            _selectedLanguageRef = option.value.trim();
                            _langueCtrl.text = option.label;
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          if (!_langueFieldListenerAttached) {
                            textEditingController.value = _langueCtrl.value;
                            textEditingController.addListener(() {
                              if (_langueCtrl.value != textEditingController.value) {
                                setState(() {
                                  _langueCtrl.value = textEditingController.value;
                                  _selectedLanguageRef = null;
                                });
                              }
                            });
                            _langueFieldListenerAttached = true;
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
              controller: _commentaireCtrl,
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
                  initialValue: _statusCtrl.value,
                  displayStringForOption: (option) => option.label,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) return statusEntries;
                    return statusEntries.where((option) {
                      return option.label.toLowerCase().contains(query) ||
                          option.value.toLowerCase().contains(query);
                    });
                  },
                  onSelected: (option) {
                    setState(() {
                      _selectedStatusCode = option.value;
                      _statusCtrl.value = TextEditingValue(text: option.label);
                    });
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    if (!_statusFieldListenerAttached) {
                      textEditingController.value = _statusCtrl.value;
                      textEditingController.addListener(() {
                        if (_statusCtrl.value != textEditingController.value) {
                          setState(() {
                            _statusCtrl.value = textEditingController.value;
                            _selectedStatusCode = '';
                          });
                        }
                      });
                      _statusFieldListenerAttached = true;
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isCreation ? 'Créer' : 'Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
