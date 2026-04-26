// lib/core/models/quote.dart
// AMI v1.4 — Module Devis

import 'package:flutter/material.dart';

/// Ligne d'un devis.
class QuoteLine {
  int? id;
  int? draftId;
  String designation;
  String? missionRef;
  double unitPrice;
  double quantity;
  double tvaRate;

  /// Réduction en pourcentage (0–100). Ex: 10.0 = 10 %.
  double discount;
  String? notes;
  int sortOrder;

  QuoteLine({
    this.id,
    this.draftId,
    required this.designation,
    this.missionRef,
    double? unitPrice,
    double? quantity,
    double? tvaRate,
    double? discount,
    this.notes,
    int? sortOrder,
  })  : unitPrice = unitPrice ?? 0,
        quantity = quantity ?? 1,
        tvaRate = tvaRate ?? 20,
        discount = discount ?? 0,
        sortOrder = sortOrder ?? 0;

  double get totalHt =>
      double.parse((unitPrice * quantity * (1 - discount / 100)).toStringAsFixed(2));

  double get unitPriceTtc =>
      double.parse((unitPrice * (1 + tvaRate / 100)).toStringAsFixed(2));

  double get totalTtc =>
      double.parse((totalHt * (1 + tvaRate / 100)).toStringAsFixed(2));

  QuoteLine copy() => QuoteLine(
        id: id,
        draftId: draftId,
        designation: designation,
        missionRef: missionRef,
        unitPrice: unitPrice,
        quantity: quantity,
        tvaRate: tvaRate,
        discount: discount,
        notes: notes,
        sortOrder: sortOrder,
      );

  factory QuoteLine.fromJson(Map<String, dynamic> j) {
    return QuoteLine(
      id: _parseInt(j['id']),
      draftId: _parseInt(j['draft_id']),
      designation:
          (j['description'] ?? j['designation'] ?? 'Ligne').toString().trim(),
      missionRef: j['mission_ref']?.toString(),
      unitPrice: _parseDouble(j['unit_price']),
      quantity: _parseDouble(j['quantity'], 1),
      tvaRate: _parseDouble(j['tva_rate'], 20),
      discount: _parseDouble(j['discount']),
      notes: j['notes']?.toString(),
      sortOrder: _parseInt(j['sort_order']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'description': designation,
        if (missionRef != null && missionRef!.isNotEmpty)
          'mission_ref': missionRef,
        'unit_price': unitPrice,
        'quantity': quantity,
        'tva_rate': tvaRate,
        'discount': discount,
        'total_ht': totalHt,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'sort_order': sortOrder,
      };
}

/// Devis (entête + lignes).
class Quote {
  final int id;
  final int? clientId;
  final String? clientName;
  final int? missionId;
  final String? missionRef;
  final String? month;
  double totalHt;
  String status;
  String? dateValidUntil;
  String? notes;
  final String? sentAt;
  final String? convertedInvoiceNumber;
  final int? createdBy;
  final String? createdAt;
  final String? updatedAt;
  List<QuoteLine> lines;

  Quote({
    required this.id,
    this.clientId,
    this.clientName,
    this.missionId,
    this.missionRef,
    this.month,
    required this.totalHt,
    required this.status,
    this.dateValidUntil,
    this.notes,
    this.sentAt,
    this.convertedInvoiceNumber,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    List<QuoteLine>? lines,
  }) : lines = lines ?? [];

  /// Modifiable seulement si brouillon ou envoyé.
  bool get isEditable => status == 'draft' || status == 'sent';

  /// Peut être converti en facture.
  bool get canConvert => status == 'accepted';

  static String statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Brouillon';
      case 'sent':
        return 'Envoyé';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Rejeté';
      case 'expired':
        return 'Expiré';
      case 'accepted_converted':
        return 'Converti en facture';
      default:
        return s;
    }
  }

  static Color statusColor(String s) {
    switch (s) {
      case 'draft':
        return const Color(0xFF6B7280);
      case 'sent':
        return const Color(0xFF1D4ED8);
      case 'accepted':
        return const Color(0xFF15803D);
      case 'rejected':
        return const Color(0xFFB91C1C);
      case 'expired':
        return const Color(0xFFD97706);
      case 'accepted_converted':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF6B7280);
    }
  }

  factory Quote.fromJson(Map<String, dynamic> j) {
    final linesRaw = j['lines'] as List? ?? const [];
    return Quote(
      id: _parseInt(j['id']) ?? 0,
      clientId: _parseInt(j['client_id']),
      clientName: j['client_name']?.toString(),
      missionId: _parseInt(j['mission_id']),
      missionRef: j['mission_ref']?.toString(),
      month: j['month']?.toString(),
      totalHt: _parseDouble(j['total_ht']),
      status: (j['status'] ?? 'draft').toString(),
      dateValidUntil: j['date_valid_until']?.toString(),
      notes: j['notes']?.toString(),
      sentAt: j['sent_at']?.toString(),
      convertedInvoiceNumber: j['converted_invoice_number']?.toString(),
      createdBy: _parseInt(j['created_by']),
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
      lines: linesRaw
          .whereType<Map>()
          .map((l) => QuoteLine.fromJson(Map<String, dynamic>.from(l)))
          .toList(),
    );
  }
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double _parseDouble(dynamic v, [double def = 0]) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? def;
}
