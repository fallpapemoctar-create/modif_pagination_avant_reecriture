class Mission {
  final int id;
  final String firstname;
  final String lastname;

  Mission({
    required this.id,
    required this.firstname,
    required this.lastname,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: int.tryParse(json['nominterprete'].toString()) ?? 0,
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "nominterprete": id,
      "firstname": firstname,
      "lastname": lastname,
    };
  }
}