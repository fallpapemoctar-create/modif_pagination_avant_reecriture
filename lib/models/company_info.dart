class CompanyInfo {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String postalCode;
  final String city;
  final String siret;
  final String phone;
  final String email;
  final String website;
  final String logoUrl;
  final String bankLabel;
  final String bankName;
  final String bankCode;
  final String bankBranchCode;
  final String bankAccountNumber;
  final String bankRibKey;
  final String bankBic;
  final String bankIban;
  final String bankDomiciliation;
  final String bankAccountHolder;
  final String bankOwnerAddress;
  final String bankOwnerPostalCode;
  final String bankOwnerCity;

  const CompanyInfo({
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.postalCode,
    required this.city,
    required this.siret,
    required this.phone,
    required this.email,
    required this.website,
    required this.logoUrl,
    this.bankLabel = '',
    this.bankName = '',
    this.bankCode = '',
    this.bankBranchCode = '',
    this.bankAccountNumber = '',
    this.bankRibKey = '',
    this.bankBic = '',
    this.bankIban = '',
    this.bankDomiciliation = '',
    this.bankAccountHolder = '',
    this.bankOwnerAddress = '',
    this.bankOwnerPostalCode = '',
    this.bankOwnerCity = '',
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    return CompanyInfo(
      name: (json['name'] ?? '').toString(),
      addressLine1: (json['addressLine1'] ?? '').toString(),
      addressLine2: (json['addressLine2'] ?? '').toString(),
      postalCode: (json['postalCode'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      siret: (json['siret'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      website: (json['website'] ?? '').toString(),
      logoUrl: (json['logoUrl'] ?? '').toString(),
      bankLabel: (json['bankLabel'] ?? '').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      bankCode: (json['bankCode'] ?? '').toString(),
      bankBranchCode: (json['bankBranchCode'] ?? '').toString(),
      bankAccountNumber: (json['bankAccountNumber'] ?? '').toString(),
      bankRibKey: (json['bankRibKey'] ?? '').toString(),
      bankBic: (json['bankBic'] ?? '').toString(),
      bankIban: (json['bankIban'] ?? '').toString(),
      bankDomiciliation: (json['bankDomiciliation'] ?? '').toString(),
      bankAccountHolder: (json['bankAccountHolder'] ?? '').toString(),
      bankOwnerAddress: (json['bankOwnerAddress'] ?? '').toString(),
      bankOwnerPostalCode: (json['bankOwnerPostalCode'] ?? '').toString(),
      bankOwnerCity: (json['bankOwnerCity'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'postalCode': postalCode,
      'city': city,
      'siret': siret,
      'phone': phone,
      'email': email,
      'website': website,
      'logoUrl': logoUrl,
      'bankLabel': bankLabel,
      'bankName': bankName,
      'bankCode': bankCode,
      'bankBranchCode': bankBranchCode,
      'bankAccountNumber': bankAccountNumber,
      'bankRibKey': bankRibKey,
      'bankBic': bankBic,
      'bankIban': bankIban,
      'bankDomiciliation': bankDomiciliation,
      'bankAccountHolder': bankAccountHolder,
      'bankOwnerAddress': bankOwnerAddress,
      'bankOwnerPostalCode': bankOwnerPostalCode,
      'bankOwnerCity': bankOwnerCity,
    };
  }

  CompanyInfo copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? city,
    String? siret,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    String? bankLabel,
    String? bankName,
    String? bankCode,
    String? bankBranchCode,
    String? bankAccountNumber,
    String? bankRibKey,
    String? bankBic,
    String? bankIban,
    String? bankDomiciliation,
    String? bankAccountHolder,
    String? bankOwnerAddress,
    String? bankOwnerPostalCode,
    String? bankOwnerCity,
  }) {
    return CompanyInfo(
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      siret: siret ?? this.siret,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      bankLabel: bankLabel ?? this.bankLabel,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      bankBranchCode: bankBranchCode ?? this.bankBranchCode,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankRibKey: bankRibKey ?? this.bankRibKey,
      bankBic: bankBic ?? this.bankBic,
      bankIban: bankIban ?? this.bankIban,
      bankDomiciliation: bankDomiciliation ?? this.bankDomiciliation,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      bankOwnerAddress: bankOwnerAddress ?? this.bankOwnerAddress,
      bankOwnerPostalCode: bankOwnerPostalCode ?? this.bankOwnerPostalCode,
      bankOwnerCity: bankOwnerCity ?? this.bankOwnerCity,
    );
  }

  static CompanyInfo fallback() {
    return const CompanyInfo(
      name: 'Planet Traduction',
      addressLine1: '13 chemin des Champcueil',
      addressLine2: '91220 Brétigny Sur Orge',
      postalCode: '91220',
      city: 'Brétigny Sur Orge',
      siret: '91282415800014',
      phone: '0178908756',
      email: 'contact@planettraduction.fr',
      website: 'https://planet-traduction.fr/',
      logoUrl: '',
      bankLabel: 'BP RIVES DE PARIS',
      bankName: 'BANQUE POPULAIRE RIVES DE PARIS',
      bankCode: '10207',
      bankBranchCode: '00067',
      bankAccountNumber: '24215114802',
      bankRibKey: '10',
      bankBic: 'CCBPFRPPMTG',
      bankIban: 'FR76 1020 7000 6724 2151 1480 210',
      bankDomiciliation: 'BPRIVES BRETIGNY (00067)',
      bankAccountHolder: 'ASS PLANET TRADUCTION',
      bankOwnerAddress: '13 CHEMIN DES CHAMPCUEILS',
      bankOwnerPostalCode: '91220',
      bankOwnerCity: 'BRETIGNY SUR ORGE',
    );
  }

  List<String> get addressLines {
    final lines = <String>[];
    if (addressLine1.trim().isNotEmpty) lines.add(addressLine1.trim());
    if (addressLine2.trim().isNotEmpty) lines.add(addressLine2.trim());
    final cityLine = [postalCode.trim(), city.trim()].where((p) => p.isNotEmpty).join(' ');
    if (cityLine.isNotEmpty) lines.add(cityLine);
    return lines;
  }

  bool get hasBankDetails =>
      bankLabel.trim().isNotEmpty ||
      bankName.trim().isNotEmpty ||
      bankAccountHolder.trim().isNotEmpty ||
      bankIban.trim().isNotEmpty ||
      bankBic.trim().isNotEmpty;

  String get bankOwnerCityLine => [
        bankOwnerPostalCode.trim(),
        bankOwnerCity.trim(),
      ].where((part) => part.isNotEmpty).join(' ');
}
