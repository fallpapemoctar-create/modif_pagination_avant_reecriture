class Country {
  final int id;
  final String label;
  final String? code;
  final String? codeIso;

  Country({
    required this.id,
    required this.label,
    this.code,
    this.codeIso,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'] ?? json['rowid'];
    final intId = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '') ?? 0;
    return Country(
      id: intId,
      label: (json['label'] ?? '').toString(),
      code: json['code']?.toString(),
      codeIso: json['code_iso']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'code': code,
      'code_iso': codeIso,
    };
  }
}
