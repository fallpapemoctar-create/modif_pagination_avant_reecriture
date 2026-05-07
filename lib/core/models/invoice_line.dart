class InvoiceLine {
  InvoiceLine({
    required this.designation,
    this.missionRef,
    double? unitPrice,
    double? quantity,
    double? tvaRate,
    double? discount,
    this.notes,
  })  : unitPrice = unitPrice ?? 0,
        quantity = quantity ?? 1,
        tvaRate = tvaRate ?? 0,
        discount = discount ?? 0;

  final String? missionRef;
  String designation;
  double unitPrice;
  double quantity;
  double tvaRate;
  /// Réduction en pourcentage (0–100). Ex: 10.0 = 10 %.
  double discount;
  String? notes;

  double get totalHt => _roundCurrency(unitPrice * quantity * (1 - discount / 100));
  double get unitPriceTtc => _roundCurrency(unitPrice * (1 + tvaRate / 100));
  double get totalTtc => _roundCurrency(totalHt * (1 + tvaRate / 100));

  InvoiceLine copy() => InvoiceLine(
        designation: designation,
        missionRef: missionRef,
        unitPrice: unitPrice,
        quantity: quantity,
        tvaRate: tvaRate,
        discount: discount,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'mission_ref': missionRef,
        'designation': designation,
        'unit_price_ht': unitPrice,
        'quantity': quantity,
        'tva_rate': tvaRate,
        'discount': discount,
        'total_ht': totalHt,
        'notes': notes,
      };

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    final missionRaw = json['mission_ref'] ?? json['missionRef'];
    final missionRef = missionRaw?.toString().trim();
    final designationValue = (json['designation'] ?? '').toString().trim();
    final notesValue = (json['notes'] ?? '').toString().trim();
    final unit = _parseDouble(json['unit_price_ht'] ?? json['unit_price']);
    final quantityValue = _parseDouble(json['quantity'], 1);
    final tva = _parseDouble(json['tva_rate']);
    final discountValue = _parseDouble(json['discount']);
    final storedTotalHt = _parseDouble(json['total_ht']);

    // If discount is 0 (or absent) but the stored total_ht differs from the
    // raw unit * qty, infer the discount from the stored total so that old
    // invoices (created before discount was persisted) still render correctly.
    double effectiveDiscount = discountValue < 0 ? 0 : discountValue;
    if (effectiveDiscount == 0 && unit > 0 && quantityValue > 0 && storedTotalHt > 0) {
      final rawTotal = unit * (quantityValue <= 0 ? 1.0 : quantityValue);
      if ((rawTotal - storedTotalHt).abs() > 0.001) {
        effectiveDiscount = ((1 - storedTotalHt / rawTotal) * 100)
            .clamp(0.0, 100.0);
      }
    }

    return InvoiceLine(
      designation: designationValue.isEmpty ? 'Ligne de facture' : designationValue,
      missionRef: missionRef?.isEmpty ?? true ? null : missionRef,
      unitPrice: unit,
      quantity: quantityValue <= 0 ? 1 : quantityValue,
      tvaRate: tva,
      discount: effectiveDiscount,
      notes: notesValue.isEmpty ? null : notesValue,
    );
  }

  static InvoiceLine fromMission(Map<String, dynamic> mission, {
    required double Function(Map<String, dynamic>) unitPriceResolver,
    required double Function(Map<String, dynamic>) lineTotalResolver,
    required String Function(Map<String, dynamic>) designationResolver,
  }) {
    final unit = unitPriceResolver(mission);
    final total = lineTotalResolver(mission);
    final qty = unit == 0 ? 1.0 : _roundCurrency(total / unit);
    final missionRef = (mission['reference_devis'] ?? mission['ref'] ?? mission['reference'])?.toString();
    return InvoiceLine(
      designation: designationResolver(mission),
      missionRef: missionRef?.trim().isEmpty ?? true ? null : missionRef!.trim(),
      unitPrice: unit == 0 ? total : unit,
      quantity: qty == 0 ? 1 : qty,
      tvaRate: _resolveTvaRate(mission),
    );
  }

  static double _resolveTvaRate(Map<String, dynamic> mission) {
    final entries = ['tva', 'tva_rate', 'tax_rate'];
    for (final key in entries) {
      final raw = mission[key];
      if (raw == null) continue;
      final value = double.tryParse(raw.toString().replaceAll(',', '.'));
      if (value != null) {
        return value;
      }
    }
    return 0;
  }

  static double _roundCurrency(double value) =>
      (value * 100).roundToDouble() / 100;

  static double _parseDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    final sanitized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(sanitized) ?? fallback;
  }
}
