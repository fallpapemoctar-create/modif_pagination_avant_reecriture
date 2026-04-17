// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../core/auth_manager.dart';
import '../core/brand_footer.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../models/country.dart';
import '../models/department.dart';
import '../services/client_service.dart';
import '../services/contact_service.dart';
import '../services/country_service.dart';
import '../services/department_service.dart';

class RequestersManagementPage extends StatefulWidget {
  final UserRights userRights;

  const RequestersManagementPage({super.key, required this.userRights});

  @override
  State<RequestersManagementPage> createState() =>
      _RequestersManagementPageState();
}

class _RequestersManagementPageState extends State<RequestersManagementPage> {
  final TextEditingController _companySearchCtrl = TextEditingController();
  final TextEditingController _contactSearchCtrl = TextEditingController();

  List<ClientSummary> _companies = <ClientSummary>[];
  List<ContactInfo> _contacts = <ContactInfo>[];
  Future<List<Country>>? _countriesFuture;
  Future<List<Department>>? _departmentsFuture;
  int? _selectedCompanyId;
  bool _loadingCompanies = true;
  bool _loadingContacts = false;
  String? _companiesError;
  String? _contactsError;

  ClientSummary? get _selectedCompany {
    final companyId = _selectedCompanyId;
    if (companyId == null) return null;
    for (final company in _companies) {
      if (company.id == companyId) return company;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _companySearchCtrl.dispose();
    _contactSearchCtrl.dispose();
    super.dispose();
  }

  Future<List<Country>> _ensureCountriesLoaded() {
    _countriesFuture ??= CountryService.getCountries();
    return _countriesFuture!;
  }

  Future<List<Department>> _ensureDepartmentsLoaded() {
    _departmentsFuture ??= DepartmentService.getDepartments();
    return _departmentsFuture!;
  }

  int? _matchCountryId(List<Country> countries, int currentId, String label) {
    if (currentId > 0) {
      for (final country in countries) {
        if (country.id == currentId) return currentId;
      }
    }

    final target = label.trim().toUpperCase();
    if (target.isEmpty) return null;
    for (final country in countries) {
      if (country.label.toUpperCase() == target ||
          (country.code?.toUpperCase() ?? '') == target ||
          (country.codeIso?.toUpperCase() ?? '') == target) {
        return country.id;
      }
    }
    return null;
  }

  int? _matchDepartmentId(
    List<Department> departments,
    int currentId,
    String label,
  ) {
    if (currentId > 0) {
      for (final department in departments) {
        if (department.id == currentId) return currentId;
      }
    }

    final target = label.trim().toUpperCase();
    if (target.isEmpty) return null;
    for (final department in departments) {
      if (department.label.toUpperCase() == target ||
          (department.code?.toUpperCase() ?? '') == target) {
        return department.id;
      }
    }
    return null;
  }

  Future<void> _loadCompanies({int? preserveSelectionId}) async {
    setState(() {
      _loadingCompanies = true;
      _companiesError = null;
    });

    try {
      final companies = await ClientService.getRequestingCompanies(
        query: _companySearchCtrl.text.trim().isEmpty
            ? null
            : _companySearchCtrl.text.trim(),
        limit: 500,
      );
      if (!mounted) return;

      final int? nextSelectedId = preserveSelectionId ?? _selectedCompanyId;
      final bool selectionExists =
          nextSelectedId != null &&
          companies.any((company) => company.id == nextSelectedId);

      setState(() {
        _companies = companies;
        _selectedCompanyId = selectionExists
            ? nextSelectedId
            : (companies.isNotEmpty ? companies.first.id : null);
        _loadingCompanies = false;
      });

      if (_selectedCompanyId != null) {
        await _loadContactsForSelectedCompany();
      } else {
        setState(() {
          _contacts = <ContactInfo>[];
          _contactsError = null;
          _loadingContacts = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCompanies = false;
        _companiesError = error.toString();
      });
    }
  }

  Future<void> _loadContactsForSelectedCompany() async {
    final companyId = _selectedCompanyId;
    if (companyId == null || companyId <= 0) {
      setState(() {
        _contacts = <ContactInfo>[];
        _contactsError = null;
        _loadingContacts = false;
      });
      return;
    }

    setState(() {
      _loadingContacts = true;
      _contactsError = null;
    });

    try {
      final contacts = await ContactService.getContactsForClient(
        clientId: companyId,
        query: _contactSearchCtrl.text.trim().isEmpty
            ? null
            : _contactSearchCtrl.text.trim(),
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loadingContacts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContacts = false;
        _contactsError = error.toString();
      });
    }
  }

  Future<void> _showCompanyDialog({ClientSummary? company}) async {
    List<Country> countries;
    List<Department> departments;
    try {
      countries = await _ensureCountriesLoaded();
      departments = await _ensureDepartmentsLoaded();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les référentiels: $error'),
        ),
      );
      return;
    }
    if (!mounted) return;

    int? countryId = _matchCountryId(
      countries,
      company?.countryId ?? 0,
      company?.countryLabel ?? '',
    );
    int? departmentId = _matchDepartmentId(
      departments,
      company?.departmentId ?? 0,
      company?.departmentLabel ?? '',
    );

    final nameCtrl = TextEditingController(text: company?.name ?? '');
    final aliasCtrl = TextEditingController(text: company?.alias ?? '');
    final addressCtrl = TextEditingController(text: company?.address ?? '');
    final zipCtrl = TextEditingController(text: company?.zip ?? '');
    final townCtrl = TextEditingController(text: company?.town ?? '');
    final phoneCtrl = TextEditingController(text: company?.phone ?? '');
    final faxCtrl = TextEditingController(text: company?.fax ?? '');
    final emailCtrl = TextEditingController(text: company?.email ?? '');
    final websiteCtrl = TextEditingController(text: company?.website ?? '');
    final sirenCtrl = TextEditingController(text: company?.siren ?? '');
    final siretCtrl = TextEditingController(text: company?.siret ?? '');
    final notePublicCtrl = TextEditingController(
      text: company?.notePublic ?? '',
    );
    final notePrivateCtrl = TextEditingController(
      text: company?.notePrivate ?? '',
    );
    bool saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            Future<void> save() async {
              final String name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setLocalState(() {
                  errorMessage = 'Le nom de la société est obligatoire.';
                });
                return;
              }

              setLocalState(() {
                saving = true;
                errorMessage = null;
              });

              try {
                final saved = company == null
                    ? await ClientService.addRequestingCompany(
                        name: name,
                        alias: aliasCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        zip: zipCtrl.text.trim(),
                        town: townCtrl.text.trim(),
                        country: countryId?.toString() ?? '',
                        department: departmentId?.toString() ?? '',
                        phone: phoneCtrl.text.trim(),
                        fax: faxCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        website: websiteCtrl.text.trim(),
                        siren: sirenCtrl.text.trim(),
                        siret: siretCtrl.text.trim(),
                        notePublic: notePublicCtrl.text.trim(),
                        notePrivate: notePrivateCtrl.text.trim(),
                        userId: AuthManager.userId > 0
                            ? AuthManager.userId
                            : null,
                      )
                    : await ClientService.updateRequestingCompany(
                        id: company.id,
                        name: name,
                        alias: aliasCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        zip: zipCtrl.text.trim(),
                        town: townCtrl.text.trim(),
                        country: countryId?.toString() ?? '',
                        department: departmentId?.toString() ?? '',
                        phone: phoneCtrl.text.trim(),
                        fax: faxCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        website: websiteCtrl.text.trim(),
                        siren: sirenCtrl.text.trim(),
                        siret: siretCtrl.text.trim(),
                        notePublic: notePublicCtrl.text.trim(),
                        notePrivate: notePrivateCtrl.text.trim(),
                        isActive: company.isActive,
                        userId: AuthManager.userId > 0
                            ? AuthManager.userId
                            : null,
                      );
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                await _loadCompanies(preserveSelectionId: saved.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      company == null
                          ? 'Société créée.'
                          : 'Société mise à jour.',
                    ),
                  ),
                );
              } catch (error) {
                setLocalState(() {
                  saving = false;
                  errorMessage = error.toString();
                });
              }
            }

            return AlertDialog(
              title: Text(
                company == null
                    ? 'Nouvelle société demandeuse'
                    : 'Modifier la société',
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: aliasCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom commercial / alias',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: zipCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Code postal',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: townCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ville',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: countryId,
                              decoration: const InputDecoration(
                                labelText: 'Pays',
                                isDense: true,
                              ),
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
                              onChanged: (value) {
                                setLocalState(() {
                                  countryId = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: departmentId,
                              decoration: const InputDecoration(
                                labelText: 'Département',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Non renseigné'),
                                ),
                                ...departments.map(
                                  (department) => DropdownMenuItem<int?>(
                                    value: department.id,
                                    child: Text(
                                      department.code == null ||
                                              department.code!.trim().isEmpty
                                          ? department.label
                                          : '${department.code} - ${department.label}',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setLocalState(() {
                                  departmentId = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: faxCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Fax',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: websiteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Site web',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sirenCtrl,
                              decoration: const InputDecoration(
                                labelText: 'SIREN',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: siretCtrl,
                              decoration: const InputDecoration(
                                labelText: 'SIRET',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notePublicCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note publique',
                          alignLabelWithHint: true,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notePrivateCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note privée',
                          alignLabelWithHint: true,
                          isDense: true,
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    aliasCtrl.dispose();
    addressCtrl.dispose();
    zipCtrl.dispose();
    townCtrl.dispose();
    phoneCtrl.dispose();
    faxCtrl.dispose();
    emailCtrl.dispose();
    websiteCtrl.dispose();
    sirenCtrl.dispose();
    siretCtrl.dispose();
    notePublicCtrl.dispose();
    notePrivateCtrl.dispose();
  }

  Future<void> _deleteCompany(ClientSummary company) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la société'),
        content: Text(
          'La société "${company.name}" sera désactivée dans Dolibarr. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ClientService.deleteRequestingCompany(
        id: company.id,
        userId: AuthManager.userId > 0 ? AuthManager.userId : null,
      );
      if (!mounted) return;
      await _loadCompanies();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Société désactivée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $error')));
    }
  }

  Future<void> _showContactDialog({ContactInfo? contact}) async {
    final companyId = _selectedCompanyId;
    if (companyId == null || companyId <= 0) return;

    List<Country> countries;
    List<Department> departments;
    try {
      countries = await _ensureCountriesLoaded();
      departments = await _ensureDepartmentsLoaded();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les référentiels: $error'),
        ),
      );
      return;
    }
    if (!mounted) return;

    int? countryId = _matchCountryId(
      countries,
      contact?.countryId ?? 0,
      contact?.countryLabel ?? '',
    );
    int? departmentId = _matchDepartmentId(
      departments,
      contact?.departmentId ?? 0,
      contact?.departmentLabel ?? '',
    );

    final firstnameCtrl = TextEditingController(text: contact?.firstname ?? '');
    final lastnameCtrl = TextEditingController(text: contact?.lastname ?? '');
    final civilityCtrl = TextEditingController(text: contact?.civility ?? '');
    final positionCtrl = TextEditingController(text: contact?.position ?? '');
    final emailCtrl = TextEditingController(text: contact?.email ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    final personalPhoneCtrl = TextEditingController(
      text: contact?.personalPhone ?? '',
    );
    final mobileCtrl = TextEditingController(text: contact?.mobile ?? '');
    final faxCtrl = TextEditingController(text: contact?.fax ?? '');
    final birthdayCtrl = TextEditingController(text: contact?.birthday ?? '');
    final addressCtrl = TextEditingController(text: contact?.address ?? '');
    final zipCtrl = TextEditingController(text: contact?.zip ?? '');
    final townCtrl = TextEditingController(text: contact?.town ?? '');
    final notePublicCtrl = TextEditingController(
      text: contact?.notePublic ?? '',
    );
    final notePrivateCtrl = TextEditingController(
      text: contact?.notePrivate ?? '',
    );
    bool saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            Future<void> save() async {
              final firstname = firstnameCtrl.text.trim();
              final lastname = lastnameCtrl.text.trim();
              if (firstname.isEmpty && lastname.isEmpty) {
                setLocalState(() {
                  errorMessage = 'Le prénom ou le nom est obligatoire.';
                });
                return;
              }

              setLocalState(() {
                saving = true;
                errorMessage = null;
              });

              try {
                await (contact == null
                    ? ContactService.addContact(
                        clientId: companyId,
                        firstname: firstname,
                        lastname: lastname,
                        civility: civilityCtrl.text.trim(),
                        position: positionCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        personalPhone: personalPhoneCtrl.text.trim(),
                        mobile: mobileCtrl.text.trim(),
                        fax: faxCtrl.text.trim(),
                        birthday: birthdayCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        zip: zipCtrl.text.trim(),
                        town: townCtrl.text.trim(),
                        country: countryId?.toString() ?? '',
                        department: departmentId?.toString() ?? '',
                        notePublic: notePublicCtrl.text.trim(),
                        notePrivate: notePrivateCtrl.text.trim(),
                        userId: AuthManager.userId > 0
                            ? AuthManager.userId
                            : null,
                      )
                    : ContactService.updateContact(
                        id: contact.id,
                        clientId: companyId,
                        firstname: firstname,
                        lastname: lastname,
                        civility: civilityCtrl.text.trim(),
                        position: positionCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        personalPhone: personalPhoneCtrl.text.trim(),
                        mobile: mobileCtrl.text.trim(),
                        fax: faxCtrl.text.trim(),
                        birthday: birthdayCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        zip: zipCtrl.text.trim(),
                        town: townCtrl.text.trim(),
                        country: countryId?.toString() ?? '',
                        department: departmentId?.toString() ?? '',
                        notePublic: notePublicCtrl.text.trim(),
                        notePrivate: notePrivateCtrl.text.trim(),
                        isActive: contact.isActive,
                        userId: AuthManager.userId > 0
                            ? AuthManager.userId
                            : null,
                      ));
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                await _loadContactsForSelectedCompany();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      contact == null ? 'Contact créé.' : 'Contact mis à jour.',
                    ),
                  ),
                );
              } catch (error) {
                setLocalState(() {
                  saving = false;
                  errorMessage = error.toString();
                });
              }
            }

            return AlertDialog(
              title: Text(
                contact == null
                    ? 'Nouvelle personne demandeuse'
                    : 'Modifier la personne demandeuse',
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: civilityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Civilité',
                                hintText: 'M., Mme, Dr...',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: firstnameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Prénom',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: lastnameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: positionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Fonction',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: personalPhoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone perso',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: mobileCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mobile',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: faxCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Fax',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: birthdayCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Date de naissance',
                          hintText: 'AAAA-MM-JJ',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: zipCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Code postal',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: townCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ville',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: countryId,
                              decoration: const InputDecoration(
                                labelText: 'Pays',
                                isDense: true,
                              ),
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
                              onChanged: (value) {
                                setLocalState(() {
                                  countryId = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: departmentId,
                              decoration: const InputDecoration(
                                labelText: 'Département',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Non renseigné'),
                                ),
                                ...departments.map(
                                  (department) => DropdownMenuItem<int?>(
                                    value: department.id,
                                    child: Text(
                                      department.code == null ||
                                              department.code!.trim().isEmpty
                                          ? department.label
                                          : '${department.code} - ${department.label}',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setLocalState(() {
                                  departmentId = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notePublicCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note publique',
                          alignLabelWithHint: true,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notePrivateCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note privée',
                          alignLabelWithHint: true,
                          isDense: true,
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    firstnameCtrl.dispose();
    lastnameCtrl.dispose();
    civilityCtrl.dispose();
    positionCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    personalPhoneCtrl.dispose();
    mobileCtrl.dispose();
    faxCtrl.dispose();
    birthdayCtrl.dispose();
    addressCtrl.dispose();
    zipCtrl.dispose();
    townCtrl.dispose();
    notePublicCtrl.dispose();
    notePrivateCtrl.dispose();
  }

  Future<void> _deleteContact(ContactInfo contact) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la personne demandeuse'),
        content: Text(
          'Le contact "${contact.displayName}" sera désactivé dans Dolibarr. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ContactService.deleteContact(
        id: contact.id,
        userId: AuthManager.userId > 0 ? AuthManager.userId : null,
      );
      if (!mounted) return;
      await _loadContactsForSelectedCompany();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact désactivé.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $error')));
    }
  }

  Widget _buildInfoLine(String label, String value) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {double? width}) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
            Expanded(child: Text(display)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompaniesPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sociétés demandeuses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _loadingCompanies ? null : _loadCompanies,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recharger',
                ),
                FilledButton.icon(
                  onPressed: () => _showCompanyDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companySearchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher une société',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: _loadingCompanies ? null : _loadCompanies,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Lancer la recherche',
                ),
              ),
              onSubmitted: (_) => _loadCompanies(),
            ),
            const SizedBox(height: 12),
            if (_loadingCompanies)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_companiesError != null)
              Expanded(child: Center(child: Text('Erreur: $_companiesError')))
            else if (_companies.isEmpty)
              const Expanded(
                child: Center(child: Text('Aucune société trouvée.')),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _companies.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final company = _companies[index];
                    final bool selected = company.id == _selectedCompanyId;
                    final subtitleParts = <String>[
                      if (company.town.trim().isNotEmpty) company.town.trim(),
                      if (company.countryLabel.trim().isNotEmpty)
                        company.countryLabel.trim(),
                      if (company.departmentLabel.trim().isNotEmpty)
                        company.departmentLabel.trim(),
                      if (company.siret.trim().isNotEmpty)
                        'SIRET ${company.siret.trim()}',
                      if (company.phone.trim().isNotEmpty) company.phone.trim(),
                    ];
                    return ListTile(
                      selected: selected,
                      selectedTileColor: const Color(0xFFE8EDFF),
                      title: Text(company.name),
                      subtitle: subtitleParts.isEmpty
                          ? null
                          : Text(subtitleParts.join(' • ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        setState(() {
                          _selectedCompanyId = company.id;
                        });
                        await _loadContactsForSelectedCompany();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Personnes demandeuses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedCompanyId == null
                      ? null
                      : () => _showContactDialog(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher une personne',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: _loadingContacts
                      ? null
                      : _loadContactsForSelectedCompany,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Lancer la recherche',
                ),
              ),
              onSubmitted: (_) => _loadContactsForSelectedCompany(),
            ),
            const SizedBox(height: 12),
            if (_loadingContacts)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_contactsError != null)
              Expanded(child: Center(child: Text('Erreur: $_contactsError')))
            else if (_contacts.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Aucune personne demandeuse trouvée.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _contacts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    final subtitleParts = <String>[
                      if (contact.civility.trim().isNotEmpty)
                        contact.civility.trim(),
                      if (contact.position.trim().isNotEmpty)
                        contact.position.trim(),
                      if (contact.countryLabel.trim().isNotEmpty)
                        contact.countryLabel.trim(),
                      if (contact.departmentLabel.trim().isNotEmpty)
                        contact.departmentLabel.trim(),
                      if (contact.email.trim().isNotEmpty) contact.email.trim(),
                      if (contact.phone.trim().isNotEmpty) contact.phone.trim(),
                      if (contact.personalPhone.trim().isNotEmpty)
                        contact.personalPhone.trim(),
                      if (contact.mobile.trim().isNotEmpty)
                        contact.mobile.trim(),
                      if (contact.fax.trim().isNotEmpty) contact.fax.trim(),
                    ];
                    return ListTile(
                      title: Text(contact.displayName),
                      subtitle: subtitleParts.isEmpty
                          ? null
                          : Text(subtitleParts.join(' • ')),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showContactDialog(contact: contact),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Modifier',
                          ),
                          IconButton(
                            onPressed: () => _deleteContact(contact),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Désactiver',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDetailsCard(ClientSummary company) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    company.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showCompanyDialog(company: company),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteCompany(company),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Désactiver'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 16.0;
                final maxWidth = constraints.maxWidth;
                final columns = maxWidth >= 1180
                    ? 3
                    : (maxWidth >= 760 ? 2 : 1);
                final itemWidth =
                    (maxWidth - (spacing * (columns - 1))) / columns;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: spacing,
                      runSpacing: 0,
                      children: [
                        _buildInfoTile(
                          'Alias',
                          company.alias,
                          width: itemWidth,
                        ),
                        _buildInfoTile(
                          'Code postal',
                          company.zip,
                          width: itemWidth,
                        ),
                        _buildInfoTile('Ville', company.town, width: itemWidth),
                        _buildInfoTile(
                          'Pays',
                          company.countryLabel,
                          width: itemWidth,
                        ),
                        _buildInfoTile(
                          'Département',
                          company.departmentLabel,
                          width: itemWidth,
                        ),
                        _buildInfoTile(
                          'Téléphone',
                          company.phone,
                          width: itemWidth,
                        ),
                        _buildInfoTile('Fax', company.fax, width: itemWidth),
                        _buildInfoTile(
                          'Email',
                          company.email,
                          width: itemWidth,
                        ),
                        _buildInfoTile(
                          'Site web',
                          company.website,
                          width: itemWidth,
                        ),
                        _buildInfoTile(
                          'SIREN',
                          company.siren,
                          width: itemWidth,
                        ),
                        _buildInfoTile(
                          'SIRET',
                          company.siret,
                          width: itemWidth,
                        ),
                      ],
                    ),
                    _buildInfoLine('Adresse', company.address),
                    _buildInfoLine('Note publique', company.notePublic),
                    _buildInfoLine('Note privée', company.notePrivate),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPanel({bool compact = false}) {
    final company = _selectedCompany;
    if (company == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sélectionnez une société demandeuse pour gérer ses contacts.',
            ),
          ),
        ),
      );
    }

    if (compact) {
      return Column(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: _buildCompanyDetailsCard(company),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 420, child: _buildContactsSection()),
        ],
      );
    }

    return Column(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: _buildCompanyDetailsCard(company),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildContactsSection()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.userRights.canManageMissions() &&
        !widget.userRights.isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sociétés et contacts')),
        body: const Center(
          child: Text('Vous n\'avez pas les droits pour accéder à cette page.'),
        ),
      );
    }

    final spacing = ResponsiveHelper.getSpacing(context);
    final bool compact = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      appBar: AppBar(title: const Text('Sociétés et contacts')),
      body: ResponsiveContainer(
        child: Column(
          children: [
            Expanded(
              child: compact
                  ? ListView(
                      padding: EdgeInsets.only(top: spacing * 0.5),
                      children: [
                        SizedBox(height: 320, child: _buildCompaniesPanel()),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.78,
                          child: _buildDetailsPanel(compact: true),
                        ),
                      ],
                    )
                  : Padding(
                      padding: EdgeInsets.only(top: spacing * 0.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 360, child: _buildCompaniesPanel()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDetailsPanel()),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            const BrandFooter(),
          ],
        ),
      ),
    );
  }
}
