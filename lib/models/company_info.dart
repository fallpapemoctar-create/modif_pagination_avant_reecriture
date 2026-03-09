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
}
