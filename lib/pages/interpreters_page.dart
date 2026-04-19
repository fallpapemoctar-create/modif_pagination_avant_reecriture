import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/interpreter.dart';
import '../models/country.dart';
import '../services/interpreter_service.dart';
import '../services/country_service.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import '../core/custom_scrollbar.dart';
import '../core/brand_footer.dart';

class InterpretersPage extends StatefulWidget {
  final UserRights userRights;
  const InterpretersPage({super.key, required this.userRights});

  @override
  State<InterpretersPage> createState() => _InterpretersPageState();
}

class _InterpretersPageState extends State<InterpretersPage> {
  late Future<List<Interpreter>> _future;
  List<Interpreter> _all = [];
  List<Interpreter> _filtered = [];
  String _search = '';
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  Timer? _scrollTimer;
  Future<List<Country>>? _countriesFuture;

  @override
  void initState() {
    super.initState();
    _load();
    _ensureCountriesLoaded();
    _searchFocusNode.addListener(() => setState(() {}));
    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _future = InterpreterService.getInterpreters();
    _future
        .then((list) {
          setState(() {
            _all = list;
            _applyFilters();
          });
        })
        .catchError((e) {
          // ignore for now
        });
  }

  Future<List<Country>> _ensureCountriesLoaded() {
    _countriesFuture ??= CountryService.getCountries();
    return _countriesFuture!;
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    _filtered = _all.where((i) {
      if (q.isEmpty) return true;
      return i.displayName.toLowerCase().contains(q) ||
          i.languesParlees.toLowerCase().contains(q) ||
          i.ville.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openFmi() async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse('https://fmi.planetapplis.fr/');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir FMI')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _onSearchChanged(String v) {
    setState(() {
      _search = v;
      _applyFilters();
    });
  }

  Future<void> _callNumber(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Numéro invalide')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (!await launchUrl(uri)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d\'appeler')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Numéro WhatsApp invalide')),
      );
      return;
    }
    final wa = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$wa');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _confirmDelete(Interpreter i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Container(
          width: ResponsiveHelper.getDialogWidth(context),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Supprimer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF161616),
              ),
            ),
            content: Text(
              'Supprimer ${i.displayName} ?',
              style: const TextStyle(fontSize: 16, color: Color(0xFF3A3A3A)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF000091),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Annuler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE1000F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      try {
        final success = await InterpreterService.deleteInterpreter(i.id);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        if (success) {
          _load();
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _showInterpreterForm({Interpreter? interpreter}) async {
    final isEdit = interpreter != null;
    List<Country> countries;
    try {
      countries = await _ensureCountriesLoaded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger les pays: $e')),
      );
      return;
    }

    if (!mounted) return;

    int? countryId = interpreter?.fkCountry;
    if (countryId == null && (interpreter?.pays.isNotEmpty ?? false)) {
      final target = interpreter!.pays.toUpperCase();
      for (final country in countries) {
        final label = country.label.toUpperCase();
        if (label == target) {
          countryId = country.id;
          break;
        }
      }
    }

    Country? countryFromId(int? id) {
      if (id == null) return null;
      for (final c in countries) {
        if (c.id == id) {
          return c;
        }
      }
      return null;
    }
    final numeroCtrl = TextEditingController(text: interpreter?.numero ?? '');
    final nomCtrl = TextEditingController(text: interpreter?.nom ?? '');
    final prenomCtrl = TextEditingController(text: interpreter?.prenom ?? '');
    final mobileCtrl = TextEditingController(
      text: interpreter?.telMobile ?? '',
    );
    final emailCtrl = TextEditingController(text: interpreter?.email ?? '');
    final languesCtrl = TextEditingController(
      text: interpreter?.languesParlees ?? '',
    );
    final commentairesCtrl = TextEditingController(
      text: interpreter?.commentaires ?? '',
    );
    String statusValue = interpreter?.status ?? 'Disponible';
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: ResponsiveHelper.getDialogWidth(context),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: StatefulBuilder(
            builder: (c, setStateDialog) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                isEdit ? 'Modifier un interprète' : 'Ajouter un interprète',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF161616),
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomCtrl,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        onChanged: (_) {
                          if (!isEdit) formKey.currentState?.validate();
                        },
                      ),
                      TextFormField(
                        controller: prenomCtrl,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        onChanged: (_) {
                          if (!isEdit) formKey.currentState?.validate();
                        },
                      ),
                      if (!isEdit)
                        FormField<bool>(
                          validator: (_) {
                            final hasNom = nomCtrl.text.trim().isNotEmpty;
                            final hasPrenom = prenomCtrl.text.trim().isNotEmpty;
                            return hasNom || hasPrenom
                              ? null
                              : 'Renseignez au moins le nom ou le prénom';
                          },
                          builder: (state) {
                            if (!state.hasError) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  state.errorText!,
                                  style: const TextStyle(color: Color(0xFFE1000F)),
                                ),
                              ),
                            );
                          },
                        ),
                      TextFormField(
                        controller: mobileCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone mobile',
                        ),
                      ),
                      TextFormField(
                        controller: numeroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone fixe',
                        ),
                      ),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextFormField(
                        controller: languesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Langues parlées',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: statusValue,
                        decoration: const InputDecoration(labelText: 'Statut'),
                        items: ['Disponible', 'Indisponible', 'En mission']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) => setStateDialog(
                          () => statusValue = v ?? statusValue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: countryId,
                        decoration: const InputDecoration(labelText: 'Pays'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Non renseigné'),
                          ),
                          ...countries.map(
                            (country) => DropdownMenuItem<int?>(
                              value: country.id,
                              child: Text(country.label),
                            ),
                          ),
                        ],
                        onChanged: (value) => setStateDialog(() {
                          countryId = value;
                        }),
                      ),
                      TextFormField(
                        controller: commentairesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Commentaires',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF000091),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000091),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final selectedCountry = countryFromId(countryId);
                    final fallbackCountryLabel = interpreter?.pays ?? '';
                    final fallbackCountryId = interpreter?.fkCountry;
                    final fallbackCountryCode = interpreter?.countryCode;
                    final fallbackCountryIso = interpreter?.countryIso;
                    final rawNom = nomCtrl.text.trim();
                    final rawPrenom = prenomCtrl.text.trim();
                    final previousNom = (interpreter?.nom ?? '').trim();
                    final previousPrenom = (interpreter?.prenom ?? '').trim();
                    final resolvedNom = rawNom.isNotEmpty
                      ? rawNom
                      : rawPrenom.isNotEmpty
                        ? rawPrenom
                        : previousNom.isNotEmpty
                          ? previousNom
                          : 'Interprète';
                    final resolvedPrenom = rawPrenom.isNotEmpty
                      ? rawPrenom
                      : previousPrenom.isNotEmpty
                        ? previousPrenom
                        : rawNom;
                    final display = ('$rawNom $rawPrenom').trim();
                    final i = Interpreter(
                      id: interpreter?.id ?? 0,
                      numero: numeroCtrl.text.trim(),
                      nom: resolvedNom,
                      prenom: resolvedPrenom,
                      email: emailCtrl.text.trim(),
                      telMobile: mobileCtrl.text.trim(),
                      telDomicile: interpreter?.telDomicile ?? '',
                      languesParlees: languesCtrl.text.trim(),
                      adresse: interpreter?.adresse ?? '',
                      codePostal: interpreter?.codePostal ?? '',
                      ville: interpreter?.ville ?? '',
                      pays: selectedCountry?.label ?? fallbackCountryLabel,
                      fkCountry: selectedCountry?.id ?? fallbackCountryId,
                      countryCode: selectedCountry?.code ?? fallbackCountryCode,
                      countryIso: selectedCountry?.codeIso ?? fallbackCountryIso,
                      commentaires: commentairesCtrl.text.trim(),
                      status: statusValue,
                      displayName: (display.isNotEmpty ? display : resolvedNom)
                        .toUpperCase(),
                    );
                    try {
                      final success = isEdit
                          ? await InterpreterService.updateInterpreter(i)
                          : await InterpreterService.addInterpreter(i);
                      if (!mounted) return;
                      if (success) navigator.pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (ok == true) {
      setState(() {
        _load();
      });
    }
  }

  double _getHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 576) {
      // Mobile : 16px
      return 16.0;
    } else if (screenWidth < 768) {
      // Tablette portrait : 24px
      return 24.0;
    } else if (screenWidth < 1200) {
      // Tablette paysage / petit desktop : 32px
      return 32.0;
    } else if (screenWidth < 1440) {
      // Desktop : 48px
      return 48.0;
    } else {
      // Large desktop : 64px
      return 64.0;
    }
  }

  String _formatPhone(String p) {
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 2) return p;
    final parts = <String>[];
    for (var i = 0; i < digits.length; i += 2) {
      final end = (i + 2) < digits.length ? i + 2 : digits.length;
      parts.add(digits.substring(i, end));
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        widget.userRights.canManageInterpreters() ||
        widget.userRights.isAdmin();
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        final screenHeight = MediaQuery.of(context).size.height;

        if (event is KeyDownEvent) {
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
            // Annuler le timer précédent si existant
            _scrollTimer?.cancel();
            // Premier scroll immédiat
            _scrollController.jumpTo(
              (_scrollController.offset + screenHeight * 0.8).clamp(
                0,
                _scrollController.position.maxScrollExtent,
              ),
            );
            // Continuer à scroller tant que la touche est maintenue
            _scrollTimer = Timer.periodic(const Duration(milliseconds: 100), (
              timer,
            ) {
              if (_scrollController.hasClients) {
                final newOffset = _scrollController.offset + screenHeight * 0.2;
                if (newOffset >= _scrollController.position.maxScrollExtent) {
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                  timer.cancel();
                } else {
                  _scrollController.jumpTo(newOffset);
                }
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
            // Annuler le timer précédent si existant
            _scrollTimer?.cancel();
            // Premier scroll immédiat
            _scrollController.jumpTo(
              (_scrollController.offset - screenHeight * 0.8).clamp(
                0,
                _scrollController.position.maxScrollExtent,
              ),
            );
            // Continuer à scroller tant que la touche est maintenue
            _scrollTimer = Timer.periodic(const Duration(milliseconds: 100), (
              timer,
            ) {
              if (_scrollController.hasClients) {
                final newOffset = _scrollController.offset - screenHeight * 0.2;
                if (newOffset <= 0) {
                  _scrollController.jumpTo(0);
                  timer.cancel();
                } else {
                  _scrollController.jumpTo(newOffset);
                }
              }
            });
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
        } else if (event is KeyUpEvent) {
          // Arrêter le scroll continu quand la touche est relâchée
          if (event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.pageUp ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _scrollTimer?.cancel();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(
          title: const Text('Annuaire des interprètes'),
          backgroundColor: const Color(0xFFF8F9FA),
          foregroundColor: const Color(0xFF000091),
          elevation: 1,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton.icon(
                onPressed: _openFmi,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF000091),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                icon: const Icon(Icons.receipt_long, size: 22),
                label: const Text('FMI - Facturation des interprètes'),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _getHorizontalPadding(context),
            vertical: ResponsiveHelper.getSpacing(context),
          ),
          child: Column(
            children: [
              // Search bar with add button
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.getSpacing(context),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                                  hintText: 'Rechercher un interprète',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: _onSearchChanged,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                  setState(() {});
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
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showInterpreterForm(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000091),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 24),
                      label: const Text(
                        'Ajouter',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              Expanded(
                child: FutureBuilder<List<Interpreter>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _all.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF000091),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    }
                    if (_filtered.isEmpty) {
                      return const Center(
                        child: Text('Aucun interprète trouvé'),
                      );
                    }

                    // Responsive grid configuration based on screen width
                    final screenWidth = MediaQuery.of(context).size.width;
                    final int crossAxisCount;
                    final double childAspectRatio;

                    if (screenWidth < 600) {
                      // Mobile: 1 column
                      crossAxisCount = 1;
                      childAspectRatio = 0.85;
                    } else if (screenWidth < 900) {
                      // Tablet portrait: 2 columns
                      crossAxisCount = 2;
                      childAspectRatio = 0.95;
                    } else if (screenWidth < 1400) {
                      // Tablet landscape / Small desktop: 3 columns
                      crossAxisCount = 3;
                      childAspectRatio = 1.0;
                    } else if (screenWidth < 1800) {
                      // Desktop: 4 columns
                      crossAxisCount = 4;
                      childAspectRatio = 1.1;
                    } else if (screenWidth < 2200) {
                      // Large desktop: 5 columns
                      crossAxisCount = 5;
                      childAspectRatio = 1.2;
                    } else {
                      // Extra large desktop: 6 columns
                      crossAxisCount = 6;
                      childAspectRatio = 1.3;
                    }

                    // Use GridView for wider screens
                    if (screenWidth >= 600) {
                      return DsfrScrollbar(
                        controller: _scrollController,
                        child: GridView.builder(
                          controller: _scrollController,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: ResponsiveHelper.getSpacing(
                                  context,
                                ),
                                mainAxisSpacing: ResponsiveHelper.getSpacing(
                                  context,
                                ),
                                childAspectRatio: childAspectRatio,
                              ),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final i = _filtered[index];
                            return _buildInterpreterCard(
                              i,
                              canManage,
                              isGrid: true,
                            );
                          },
                        ),
                      );
                    }

                    // Mobile: ListView with scrollbar
                    return DsfrScrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _filtered.length,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.getSpacing(
                            context,
                            mobile: 4,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final i = _filtered[index];
                          return _buildInterpreterCard(
                            i,
                            canManage,
                            isGrid: false,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterpreterCard(
    Interpreter i,
    bool canManage, {
    required bool isGrid,
  }) {
    final spacing = ResponsiveHelper.isMobile(context) ? 12.0 : 16.0;

    return Card(
      elevation: 0,
      margin: isGrid
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(vertical: spacing / 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: isGrid ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // Name in large bold text
            Center(
              child: Text(
                i.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF161616),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: spacing),

            // Languages in red/brown color
            Flexible(
              child: Center(
                child: Text(
                  i.languesParlees,
                  style: const TextStyle(
                    color: Color(0xFF3A3A3A),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: isGrid ? 3 : null,
                  overflow: isGrid ? TextOverflow.ellipsis : null,
                ),
              ),
            ),
            SizedBox(height: spacing),

            // Phone number in blue
            Center(
              child: TextButton(
                onPressed: () {
                  final phone = i.telMobile.isNotEmpty
                      ? i.telMobile
                      : (i.telDomicile.isNotEmpty ? i.telDomicile : '');
                  if (phone.isNotEmpty) _callNumber(phone);
                },
                child: Text(
                  _formatPhone(
                    i.telMobile.isNotEmpty
                        ? i.telMobile
                        : (i.telDomicile.isNotEmpty ? i.telDomicile : ''),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF000091),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing / 2),

            // Email with icon
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      i.email.isNotEmpty ? i.email : 'N/A',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Availability status badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i.status.toLowerCase().contains('dis')
                      ? const Color(0xFFB8FEC9)
                      : const Color(0xFFFFE9E9),
                  border: Border.all(
                    color: i.status.toLowerCase().contains('dis')
                        ? const Color(0xFF18753C)
                        : const Color(0xFFE1000F),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  i.status,
                  style: TextStyle(
                    color: i.status.toLowerCase().contains('dis')
                        ? const Color(0xFF18753C)
                        : const Color(0xFFE1000F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),

            // Notes/Comments with checkbox icon
            if (i.commentaires.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_box_outline_blank,
                    size: 18,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i.commentaires,
                      maxLines: isGrid ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                  ),
                ],
              ),
            if (i.commentaires.isNotEmpty) SizedBox(height: spacing),

            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // WhatsApp button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chat, color: Colors.white, size: 20),
                    onPressed: () {
                      final phone = i.telMobile.isNotEmpty
                          ? i.telMobile
                          : (i.telDomicile.isNotEmpty ? i.telDomicile : '');
                      if (phone.isNotEmpty) {
                        _launchWhatsApp(phone);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Aucun numéro')),
                        );
                      }
                    },
                  ),
                ),
                if (canManage) ...[
                  // Edit button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF000091),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _showInterpreterForm(interpreter: i),
                      tooltip: 'Modifier',
                    ),
                  ),
                  // Delete button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1000F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _confirmDelete(i),
                      tooltip: 'Supprimer',
                    ),
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
