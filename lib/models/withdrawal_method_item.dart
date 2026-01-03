class WithdrawalMethodItem {
  final String provider; // BILLBLEND / GPT / etc (top-level key)
  final String countryName;
  final String withdrawalKey; // IMPS / UPI / etc
  final String withdrawalMethod; // Tab/Tile name
  final String methodCode; // UPI / BANK_TRANSFER_INR / etc
  final double minWithdrawal;
  final double maxWithdrawal;
  final String? groupId;
  final String? imageUrl;

  WithdrawalMethodItem({
    required this.provider,
    required this.countryName,
    required this.withdrawalKey,
    required this.withdrawalMethod,
    required this.methodCode,
    required this.minWithdrawal,
    required this.maxWithdrawal,
    required this.groupId,
    required this.imageUrl,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory WithdrawalMethodItem.fromJson(String provider, Map<String, dynamic> json) {
    return WithdrawalMethodItem(
      provider: provider,
      countryName: (json['countryName'] ?? '').toString(),
      withdrawalKey: (json['withdrawalKey'] ?? '').toString(),
      withdrawalMethod: (json['withdrawalMethod'] ?? '').toString(),
      methodCode: (json['methodCode'] ?? '').toString(),
      minWithdrawal: _toDouble(json['minWithdrawal']),
      maxWithdrawal: _toDouble(json['maxWithdrawal']),
      groupId: json['groupId']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}
