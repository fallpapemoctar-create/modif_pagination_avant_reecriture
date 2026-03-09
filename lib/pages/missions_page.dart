import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/mission_service.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import '../core/custom_scrollbar.dart';
import '../core/brand_footer.dart';

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

  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _interpretersFuture = MissionService.getInterpretersWithMissions();
    _interpretersFuture
        .then((list) {
          if (!mounted) return;
          setState(() {
            _interpreters
              ..clear()
              ..addAll(list);
            _applyFilter();
          });
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _search.trim().toLowerCase();
    _filtered
      ..clear()
      ..addAll(
        q.isEmpty
            ? _interpreters
            : _interpreters.where((m) {
                final lastname = (m['lastname'] ?? '').toString().toLowerCase();
                final firstname = (m['firstname'] ?? '')
                    .toString()
                    .toLowerCase();
                final phone = (m['tel_mobile'] ?? m['telMobile'] ?? '')
                    .toString()
                    .toLowerCase();
                final combined = '$lastname $firstname';
                return combined.contains(q) || phone.contains(q);
              }).toList(),
      );
  }

  double _getHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 576) {
      return 16.0;
    } else if (screenWidth < 768) {
      return 24.0;
    } else if (screenWidth < 1200) {
      return 32.0;
    } else if (screenWidth < 1440) {
      return 48.0;
    } else {
      return 64.0;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    final canCopyRef =
        label == 'Référence mission' &&
        value.trim().isNotEmpty &&
        value != 'Sans référence' &&
        value != 'N/A';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(value)),
              if (canCopyRef)
                IconButton(
                  icon: const Icon(
                    Icons.copy,
                    size: 18,
                    color: Color(0xFF000091),
                  ),
                  tooltip: 'Copier la référence',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Référence copiée')),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showMissionForm({
    Map<String, dynamic>? mission,
    required int interpreterId,
  }) async {
    final isEdit = mission != null;
    final refCtrl = TextEditingController(
      text: mission?['reference_devis']?.toString() ?? '',
    );
    final prodCtrl = TextEditingController(
      text: mission?['produit_ref']?.toString() ?? '',
    );
    final debutCtrl = TextEditingController(
      text: mission?['debutmission']?.toString() ?? '',
    );
    final finCtrl = TextEditingController(
      text: mission?['finmission']?.toString() ?? '',
    );
    final tarifCtrl = TextEditingController(
      text: mission?['tarif_horaire']?.toString() ?? '',
    );

    DateTime? debutDate = DateTime.tryParse(
      mission?['debutmission']?.toString() ?? '',
    );
    DateTime? finDate = DateTime.tryParse(
      mission?['finmission']?.toString() ?? '',
    );
    final initialDuree = debutDate != null && finDate != null
        ? finDate.difference(debutDate).inHours
        : 0;
    final dureeCtrl = TextEditingController(
      text: initialDuree > 0 ? initialDuree.toString() : '',
    );

    bool paid = (mission?['status_payment']?.toString() == '1');

    final localContext = context;
    final ok = await showDialog<bool>(
      context: localContext,
      builder: (ctx) => Dialog(
        child: Container(
          width: ResponsiveHelper.getDialogWidth(ctx),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              void updateFinFromDuree() {
                final duree = int.tryParse(dureeCtrl.text);
                if (debutDate != null && duree != null && duree > 0) {
                  finDate = debutDate!.add(Duration(hours: duree));
                  finCtrl.text = DateFormat('yyyy-MM-dd').format(finDate!);
                }
              }

              void updateDureeFromDates() {
                if (debutDate != null && finDate != null) {
                  final hours = finDate!.difference(debutDate!).inHours;
                  dureeCtrl.text = hours.toString();
                }
              }

              return AlertDialog(
                title: Text(
                  isEdit ? 'Modifier la mission' : 'Ajouter une mission',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Référence',
                        ),
                      ),
                      TextField(
                        controller: prodCtrl,
                        decoration: const InputDecoration(labelText: 'Produit'),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: debutDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              debutDate = picked;
                              debutCtrl.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                              updateDureeFromDates();
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de mission',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            debutDate != null
                                ? DateFormat('yyyy-MM-dd').format(debutDate!)
                                : 'Sélectionner une date',
                            style: TextStyle(
                              color: debutDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: finDate ?? debutDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              finDate = picked;
                              finCtrl.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                              updateDureeFromDates();
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fin',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            finDate != null
                                ? DateFormat('yyyy-MM-dd').format(finDate!)
                                : 'Sélectionner une date',
                            style: TextStyle(
                              color: finDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: dureeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Durée (heures)',
                          helperText: 'Modifiable - met à jour la date de fin',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            updateFinFromDuree();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tarifCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tarif horaire (€)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      CheckboxListTile(
                        title: const Text('Payé'),
                        value: paid,
                        onChanged: (v) => setState(() => paid = v ?? false),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF000091),
                    ),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'interpreter_id': interpreterId,
      'reference_devis': refCtrl.text.trim(),
      'produit_ref': prodCtrl.text.trim(),
      'debutmission': debutCtrl.text.trim(),
      'finmission': finCtrl.text.trim(),
      'tarif_horaire': tarifCtrl.text.trim(),
      'status_payment': paid ? 1 : 0,
    };
    if (isEdit) payload['id'] = mission['id'];

    try {
      final success = isEdit
          ? await MissionService.updateMissionMap(payload)
          : await MissionService.addMissionMap(payload);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Mission enregistrée')),
        );
        if (_selectedId != null) {
          setState(
            () => _detailFuture = MissionService.getMissionsByInterpreter(
              _selectedId!,
            ),
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'enregistrement')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        widget.userRights.canManageMissions() || widget.userRights.isAdmin();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final screenHeight = MediaQuery.of(context).size.height;

          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _scrollController.animateTo(
              _scrollController.offset + 50,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _scrollController.animateTo(
              _scrollController.offset - 50,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          } else if (event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _scrollController.animateTo(
              _scrollController.offset + screenHeight * 0.8,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
            _scrollController.animateTo(
              _scrollController.offset - screenHeight * 0.8,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else if (event.logicalKey == LogicalKeyboardKey.home) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          } else if (event.logicalKey == LogicalKeyboardKey.end) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(
          title: const Text('Missions par interprètes'),
          backgroundColor: const Color(0xFFF8F9FA),
          foregroundColor: const Color(0xFF000091),
          elevation: 1,
        ),
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _getHorizontalPadding(context),
                vertical: ResponsiveHelper.getSpacing(context),
              ),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveHelper.getSpacing(context),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _searchFocusNode.hasFocus
                              ? const Color(0xFF000091)
                              : const Color(0xFFDDDDDD),
                          width: _searchFocusNode.hasFocus ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.search,
                              color: Color(0xFF666666),
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              cursorColor: const Color(0xFF000091),
                              decoration: const InputDecoration(
                                hintText: 'Rechercher un interprète...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (v) => setState(() {
                                _search = v;
                                _applyFilter();
                              }),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _search = '';
                                  _applyFilter();
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(
                                  Icons.close,
                                  color: Color(0xFF666666),
                                  size: 20,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context)),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _interpretersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _interpreters.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF000091),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Erreur: ${snapshot.error}'),
                          );
                        }

                        return _filtered.isEmpty
                            ? const Center(
                                child: Text('Aucun interprète avec mission'),
                              )
                            : DsfrScrollbar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (ctx, i) =>
                                      _buildInterpreterExpandable(
                                        _filtered[i],
                                        canManage,
                                      ),
                                ),
                              );
                      },
                    ),
                  ),
                  const BrandFooter(),
                ],
              ),
            ),
            // Scroll up button at top
            Positioned(
              right: 4,
              top: 60,
              child: Material(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: () {
                    _scrollController.animateTo(
                      _scrollController.offset - 200,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_drop_up,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
            // Scroll down button at bottom
            Positioned(
              right: 4,
              bottom: 4,
              child: Material(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: () {
                    _scrollController.animateTo(
                      _scrollController.offset + 200,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterpreterExpandable(
    Map<String, dynamic> interp,
    bool canManage,
  ) {
    final lastname = (interp['lastname'] ?? '').toString().trim();
    final firstname = (interp['firstname'] ?? '').toString().trim();
    final display =
        '${lastname.isEmpty ? 'INCONNU' : lastname} ${firstname.isEmpty ? '' : firstname}'
            .trim();
    final id = int.tryParse(interp['id']?.toString() ?? '') ?? -1;
    final phone = (interp['tel_mobile'] ?? interp['telMobile'] ?? '')
        .toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: const Color(0xFF000091).withValues(alpha: 0.05),
          highlightColor: const Color(0xFF000091).withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF000091),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              lastname.isNotEmpty ? lastname[0].toUpperCase() : 'I',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(
            display.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF161616),
            ),
          ),
          subtitle: phone.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                )
              : null,
          trailing: const Icon(
            Icons.expand_more,
            color: Color(0xFF000091),
            size: 24,
          ),
          onExpansionChanged: (expanded) {
            if (expanded) {
              setState(() {
                _selectedId = id;
                _detailFuture = MissionService.getMissionsByInterpreter(id);
              });
            }
          },
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _selectedId == id ? _detailFuture : Future.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }
                final missions = snapshot.data ?? [];
                if (missions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Aucune mission trouvée'),
                  );
                }

                return Column(
                  children: [
                    if (canManage)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showMissionForm(interpreterId: id),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text(
                              'Ajouter une mission',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000091),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ...missions.map(
                      (m) => _buildMissionExpandable(m, id, canManage),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionExpandable(
    Map<String, dynamic> m,
    int interpreterId,
    bool canManage,
  ) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    // Removed unused 'paid' local
    final billedStatus = m['billed_status']?.toString();
    final hasBilled = billedStatus != null && billedStatus.trim().isNotEmpty;
    final debut = DateTime.tryParse(m['debutmission']?.toString() ?? '');
    final fin = DateTime.tryParse(m['finmission']?.toString() ?? '');
    final dureeHours = debut != null && fin != null
        ? fin.difference(debut).inHours
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: const Color(0xFF000091).withValues(alpha: 0.05),
          highlightColor: const Color(0xFF000091).withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            m['produit_ref'] ?? m['ref'] ?? 'Service non spécifié',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF161616),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              debut != null
                  ? dateFmt.format(debut)
                  : (m['debutmission'] ?? 'Date non définie'),
              style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF6A6A6A), width: 1),
                ),
                child: Text(
                  hasBilled ? billedStatus : 'Statut non renseigné',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A3A3A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more, color: Color(0xFF000091), size: 24),
            ],
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Référence mission',
                  m['reference_devis'] ?? 'Sans référence',
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Service', m['produit_ref'] ?? m['ref'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Date de mission',
                  debut != null
                      ? dateFmt.format(debut)
                      : (m['debutmission'] ?? 'N/A'),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Durée',
                  dureeHours > 0 ? '${dureeHours}h' : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Statut facture',
                  hasBilled ? billedStatus : 'Statut non renseigné',
                ),
                if (canManage) ...[
                  const Divider(
                    height: 32,
                    thickness: 1,
                    color: Color(0xFFDDDDDD),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, color: Color(0xFF000091), size: 18),
                        label: const Text(
                          'Modifier',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF000091),
                          side: const BorderSide(
                            color: Color(0xFF000091),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () => _showMissionForm(
                          mission: m,
                          interpreterId: interpreterId,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete, color: Color(0xFFCE0500), size: 18),
                        label: const Text(
                          'Supprimer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFCE0500),
                          side: const BorderSide(
                            color: Color(0xFFCE0500),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmer'),
                              content: const Text('Supprimer cette mission ?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF000091),
                                  ),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );
                          if (!mounted) return;
                          if (confirm != true) return;
                          try {
                            final ok = await MissionService.deleteMission(
                              int.tryParse(m['id']?.toString() ?? '') ?? 0,
                            );
                            if (!mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Mission supprimée'),
                                ),
                              );
                              setState(
                                () => _detailFuture =
                                    MissionService.getMissionsByInterpreter(
                                      interpreterId,
                                    ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Erreur lors de la suppression',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
