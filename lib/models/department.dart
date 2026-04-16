class Department {
  final int id;
  final String label;
  final String? code;

  Department({required this.id, required this.label, this.code});

  factory Department.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'] ?? json['rowid'];
    final intId = idValue is int
        ? idValue
        : int.tryParse(idValue?.toString() ?? '') ?? 0;
    return Department(
      id: intId,
      label: (json['label'] ?? '').toString(),
      code: json['code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'code': code};
  }
}
