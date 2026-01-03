class DepositMethodsResponse {
  final List<DepositMethod> billblend;
  final List<DepositMethod> gpt;

  DepositMethodsResponse({
    required this.billblend,
    required this.gpt,
  });
}

class DepositMethod {
  final String countryName;
  final String depositKey; // e.g. UPI / PHONE_PE
  final String depositMethod; // e.g. UPI / PHONE_PE / Nagad
  final double minDeposit;
  final double maxDeposit;
  final String groupId;
  final String imageUrl;

  DepositMethod({
    required this.countryName,
    required this.depositKey,
    required this.depositMethod,
    required this.minDeposit,
    required this.maxDeposit,
    required this.groupId,
    required this.imageUrl,
  });

  factory DepositMethod.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

    return DepositMethod(
      countryName: (json['countryName'] ?? '').toString(),
      depositKey: (json['depositKey'] ?? '').toString(),
      depositMethod: (json['depositMethod'] ?? '').toString(),
      minDeposit: toD(json['minDeposit']),
      maxDeposit: toD(json['maxDeposit']),
      groupId: (json['groupId'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
    );
  }
}
