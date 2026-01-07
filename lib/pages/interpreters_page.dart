import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/interpreter.dart';
import '../services/interpreter_service.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = InterpreterService.getInterpreters();
    _future.then((list) {
      setState(() {
        _all = list;
        _applyFilters();
      });
    }).catchError((e) {
      // ignore for now
    });
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    _filtered = _all.where((i) {
      if (q.isEmpty) return true;
      return i.displayName.toLowerCase().contains(q) || i.languesParlees.toLowerCase().contains(q) || i.ville.toLowerCase().contains(q);
    }).toList();
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
      if (!await launchUrl(uri)) messenger.showSnackBar(const SnackBar(content: Text('Impossible d\'appeler')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Numéro WhatsApp invalide')));
      return;
    }
    final wa = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$wa');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) messenger.showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _confirmDelete(Interpreter i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer ${i.displayName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      try {
        final success = await InterpreterService.deleteInterpreter(i.id);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        if (success) {
          _load();
        } else {
          messenger.showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _showInterpreterForm({Interpreter? interpreter}) async {
    final isEdit = interpreter != null;
    final numeroCtrl = TextEditingController(text: interpreter?.numero ?? '');
    final nomCtrl = TextEditingController(text: interpreter?.nom ?? '');
    final prenomCtrl = TextEditingController(text: interpreter?.prenom ?? '');
    final mobileCtrl = TextEditingController(text: interpreter?.telMobile ?? '');
    final commentairesCtrl = TextEditingController(text: interpreter?.commentaires ?? '');
    String statusValue = interpreter?.status ?? 'Disponible';
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (c, setStateDialog) => AlertDialog(
            title: Text(isEdit ? 'Modifier un interprète' : 'Ajouter un interprète'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: numeroCtrl, decoration: const InputDecoration(labelText: 'Numéro')),
                  TextFormField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => (v == null || v.isEmpty) ? 'Nom obligatoire' : null),
                  TextFormField(controller: prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom')),
                  TextFormField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Téléphone mobile')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: statusValue,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: ['Disponible', 'Indisponible', 'En mission'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setStateDialog(() => statusValue = v ?? statusValue),
                  ),
                  TextFormField(controller: commentairesCtrl, decoration: const InputDecoration(labelText: 'Commentaires'), maxLines: 3),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                  ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final i = Interpreter(
                      id: interpreter?.id ?? 0,
                      numero: numeroCtrl.text.trim(),
                      nom: nomCtrl.text.trim(),
                      prenom: prenomCtrl.text.trim(),
                      email: interpreter?.email ?? '',
                      telMobile: mobileCtrl.text.trim(),
                      telDomicile: interpreter?.telDomicile ?? '',
                      languesParlees: interpreter?.languesParlees ?? '',
                      adresse: interpreter?.adresse ?? '',
                      codePostal: interpreter?.codePostal ?? '',
                      ville: interpreter?.ville ?? '',
                      pays: interpreter?.pays ?? '',
                      commentaires: commentairesCtrl.text.trim(),
                      status: statusValue,
                      displayName: ('${nomCtrl.text} ${prenomCtrl.text}').trim().toUpperCase(),
                    );
                    try {
                      final success = isEdit ? await InterpreterService.updateInterpreter(i) : await InterpreterService.addInterpreter(i);
                      if (!mounted) return;
                      if (success) navigator.pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  },
                  child: const Text('Enregistrer'))
            ],
          )),
    );

    if (ok == true) _load();
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
    final canManage = widget.userRights.canManageInterpreters() || widget.userRights.isAdmin();
    return Scaffold(
      appBar: AppBar(title: const Text('Annuaire des interprètes')),
      floatingActionButton: canManage ? FloatingActionButton(
        onPressed: () => _showInterpreterForm(),
        child: const Icon(Icons.add),
      ) : null,
      body: ResponsiveContainer(
        child: Column(children: [
          // Search bar with responsive padding
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveHelper.getSpacing(context),
            ),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                hintText: 'Rechercher...',
                hintStyle: TextStyle(color: Colors.grey),
                border: UnderlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getSpacing(context)),
          Expanded(
            child: FutureBuilder<List<Interpreter>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _all.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                if (_filtered.isEmpty) {
                  return const Center(child: Text('Aucun interprète trouvé'));
                }

                // Responsive grid configuration
                final int crossAxisCount = ResponsiveHelper.getGridColumns(
                  context,
                  mobile: 1,
                  tablet: 2,
                  desktop: ResponsiveHelper.isLargeDesktop(context) ? 4 : 3,
                );

                final double childAspectRatio;
                if (ResponsiveHelper.isMobile(context)) {
                  childAspectRatio = 1.4;
                } else if (ResponsiveHelper.isTablet(context)) {
                  childAspectRatio = 1.6;
                } else if (ResponsiveHelper.isLargeDesktop(context)) {
                  childAspectRatio = 2.2;
                } else {
                  childAspectRatio = 1.9;
                }

                // Use GridView for wider screens
                if (ResponsiveHelper.isDesktop(context) || ResponsiveHelper.isTablet(context)) {
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: ResponsiveHelper.getSpacing(context),
                      mainAxisSpacing: ResponsiveHelper.getSpacing(context),
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final i = _filtered[index];
                      return _buildInterpreterCard(i, canManage, isGrid: true);
                    },
                  );
                }

                // Mobile: ListView
                return ListView.builder(
                  itemCount: _filtered.length,
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveHelper.getSpacing(context, mobile: 4),
                  ),
                  itemBuilder: (context, index) {
                    final i = _filtered[index];
                    return _buildInterpreterCard(i, canManage, isGrid: false);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInterpreterCard(Interpreter i, bool canManage, {required bool isGrid}) {
    final spacing = ResponsiveHelper.isMobile(context) ? 8.0 : 12.0;
    
    return Card(
      elevation: ResponsiveHelper.getCardElevation(context),
      margin: isGrid ? EdgeInsets.zero : EdgeInsets.symmetric(vertical: spacing / 2),
      shape: RoundedRectangleBorder(
        borderRadius: ResponsiveHelper.getBorderRadius(context),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: isGrid ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // Status indicator
            Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: i.status.toLowerCase().contains('dis')
                      ? Colors.green
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: spacing),
              Text(
                i.status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.getFontSize(context, base: 13),
                ),
              ),
              const Spacer(),
            ]),
            SizedBox(height: spacing),
            
            // Name
            Center(
              child: Text(
                i.displayName,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, base: 16),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: spacing),
            
            // Languages
            Center(
              child: Text(
                i.languesParlees,
                style: TextStyle(
                  color: const Color(0xFF6B021F),
                  fontSize: ResponsiveHelper.getFontSize(context, base: 14),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: spacing),
            
            // Phone number
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
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: ResponsiveHelper.getFontSize(context, base: 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
            
            // Actions row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.message, color: Colors.green),
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
                SizedBox(width: spacing / 2),
                Expanded(
                  child: Text(
                    i.commentaires,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, base: 12),
                    ),
                  ),
                ),
                if (canManage) ...[
                  SizedBox(width: spacing / 2),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showInterpreterForm(interpreter: i),
                    tooltip: 'Modifier',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(i),
                    tooltip: 'Supprimer',
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

