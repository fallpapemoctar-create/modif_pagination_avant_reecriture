class Interpreter {
  final int id;
  final String numero;
  final String nom;
  final String prenom;
  final String email;
  final String telMobile;
  final String telDomicile;
  final String languesParlees;
  final String adresse;
  final String codePostal;
  final String ville;
  final String pays;
  final int? fkCountry;
  final String? countryCode;
  final String? countryIso;
  final String commentaires;
  final String status;
  final String displayName;

  Interpreter({
    required this.id,
    required this.numero,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telMobile,
    required this.telDomicile,
    required this.languesParlees,
    required this.adresse,
    required this.codePostal,
    required this.ville,
    required this.pays,
    this.fkCountry,
    this.countryCode,
    this.countryIso,
    required this.commentaires,
    required this.status,
    required this.displayName,
  });

  factory Interpreter.fromJson(Map<String, dynamic> json) {
    // Accept multiple possible key styles from older and newer APIs
    final telMobile = json['Tel_Mobile'] ?? json['tel_mobile'] ?? json['tel'] ?? '';
    final telDomicile = json['Tel_domicile'] ?? json['tel_domicile'] ?? '';
    final nom = (json['Nom'] ?? json['lastname'] ?? '').toString();
    final prenom = (json['Prenom'] ?? json['firstname'] ?? '').toString();
    final display = (json['display_name'] ?? '').toString().trim();
    final dynamic fkCountrySource = json['fk_country'] ?? json['country_id'];
    final int? fkCountry = fkCountrySource is int
      ? fkCountrySource
      : int.tryParse(fkCountrySource?.toString() ?? '');
    final pays = (json['Pays'] ?? json['pays'] ?? json['country_label'] ?? json['country'] ?? '')
      .toString();
    final countryCode = json['country_code'] ?? json['country_iso'];

    return Interpreter(
      id: (json['id_tble_annuaire_interpretes'] ?? json['id']) is int
          ? (json['id_tble_annuaire_interpretes'] ?? json['id']) as int
          : int.tryParse((json['id_tble_annuaire_interpretes'] ?? json['id']).toString()) ?? 0,
      numero: json['Numero'] ?? json['numero'] ?? '',
      nom: nom,
      prenom: prenom,
      email: (json['Email'] ?? json['email'] ?? '') as String,
      telMobile: telMobile,
      telDomicile: telDomicile,
      languesParlees: json['Langues_parlees'] ?? json['langues_parlees'] ?? '',
      adresse: json['Adresse'] ?? json['adresse'] ?? '',
      codePostal: json['Code_postal'] ?? json['code_postal'] ?? '',
      ville: json['Ville'] ?? json['ville'] ?? '',
      pays: pays,
      fkCountry: fkCountry,
      countryCode: countryCode?.toString(),
      countryIso: json['country_iso']?.toString(),
      commentaires: json['Commentaires'] ?? json['commentaires'] ?? '',
      status: (json['status'] ?? json['statut'] ?? json['Disponible'] ?? json['disponible'] ?? 'Disponible').toString(),
      displayName: display.isNotEmpty ? display : ('$nom $prenom').trim().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "rowid": id,
      "id_tble_annuaire_interpretes": id,
      "Numero": numero,
      "Nom": nom,
      "Prenom": prenom,
      "Email": email,
      "Tel_Mobile": telMobile,
      "Tel_domicile": telDomicile,
      "Langues_parlees": languesParlees,
      "Adresse": adresse,
      "Code_postal": codePostal,
      "Ville": ville,
      "Pays": pays,
      "pays": pays,
      "fk_country": fkCountry,
      "country_id": fkCountry,
      "country_code": countryCode,
      "country_iso": countryIso,
      "Commentaires": commentaires,
      "status": status,
      "selectdispo": status,
      "display_name": displayName,
    };
  }
}