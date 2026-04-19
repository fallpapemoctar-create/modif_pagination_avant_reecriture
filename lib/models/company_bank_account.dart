import 'company_info.dart';

class CompanyBankAccount {
  final int id;
  final bool isDefault;
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

  const CompanyBankAccount({
    required this.id,
    required this.isDefault,
    required this.bankLabel,
    required this.bankName,
    required this.bankCode,
    required this.bankBranchCode,
    required this.bankAccountNumber,
    required this.bankRibKey,
    required this.bankBic,
    required this.bankIban,
    required this.bankDomiciliation,
    required this.bankAccountHolder,
    required this.bankOwnerAddress,
    required this.bankOwnerPostalCode,
    required this.bankOwnerCity,
  });

  factory CompanyBankAccount.fromJson(Map<String, dynamic> json) {
    return CompanyBankAccount(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse((json['id'] ?? '').toString()) ?? 0,
      isDefault:
          json['isDefault'] == true ||
          (json['isDefault'] ?? '').toString() == '1',
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

  String get dropdownLabel {
    final label = bankLabel.trim();
    final bank = bankName.trim();
    if (label.isEmpty && bank.isEmpty) {
      return 'Compte $id';
    }
    if (label.isEmpty || label.toUpperCase() == bank.toUpperCase()) {
      return bank.isEmpty ? label : bank;
    }
    if (bank.isEmpty) {
      return label;
    }
    return '$label - $bank';
  }

  bool matchesCompanyInfo(CompanyInfo info) {
    final normalizedIban = _normalizeCompact(bankIban);
    if (normalizedIban.isNotEmpty &&
        normalizedIban == _normalizeCompact(info.bankIban)) {
      return true;
    }
    final normalizedBic = _normalizeLoose(bankBic);
    final normalizedNumber = _normalizeCompact(bankAccountNumber);
    if (normalizedBic.isNotEmpty &&
        normalizedBic == _normalizeLoose(info.bankBic) &&
        normalizedNumber.isNotEmpty &&
        normalizedNumber == _normalizeCompact(info.bankAccountNumber)) {
      return true;
    }
    final normalizedLabel = _normalizeLoose(bankLabel);
    if (normalizedLabel.isNotEmpty &&
        normalizedLabel == _normalizeLoose(info.bankLabel)) {
      return true;
    }
    return false;
  }

  CompanyInfo applyTo(CompanyInfo info) {
    return info.copyWith(
      bankLabel: bankLabel,
      bankName: bankName,
      bankCode: bankCode,
      bankBranchCode: bankBranchCode,
      bankAccountNumber: bankAccountNumber,
      bankRibKey: bankRibKey,
      bankBic: bankBic,
      bankIban: bankIban,
      bankDomiciliation: bankDomiciliation,
      bankAccountHolder: bankAccountHolder,
      bankOwnerAddress: bankOwnerAddress,
      bankOwnerPostalCode: bankOwnerPostalCode,
      bankOwnerCity: bankOwnerCity,
    );
  }

  static String _normalizeLoose(String value) {
    return value.trim().toUpperCase();
  }

  static String _normalizeCompact(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
  }
}
