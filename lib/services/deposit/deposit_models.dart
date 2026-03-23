class DepositMethodsResponse {
  final List<DepositMethod> billblend;
  final List<DepositMethod> gpt;
  final List<DepositMethod> passimpay;

  DepositMethodsResponse({
    required this.billblend,
    required this.gpt,
    required this.passimpay,
  });

  factory DepositMethodsResponse.fromJson(Map<String, dynamic> json) {
    List<DepositMethod> parseList(dynamic list) {
      if (list == null) return [];
      return (list as List)
          .map((e) => DepositMethod.fromJson(e))
          .toList();
    }

    return DepositMethodsResponse(
      billblend: parseList(json["BILLBLEND"]),
      gpt: parseList(json["GPT"]),
      passimpay: parseList(json["PASSIMPAY"]),
    );
  }
}

class DepositMethod {
  final String countryName;
  final String depositKey;
  final String depositMethod;
  final String methodCode;
  final double minDeposit;
  final double maxDeposit;
  final String? groupId;
  final String? imageUrl;

  DepositMethod({
    required this.countryName,
    required this.depositKey,
    required this.depositMethod,
    required this.methodCode,
    required this.minDeposit,
    required this.maxDeposit,
    this.groupId,
    this.imageUrl,
  });

  factory DepositMethod.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) =>
        v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

    return DepositMethod(
      countryName: (json['countryName'] ?? '').toString(),
      depositKey: (json['depositKey'] ?? '').toString(),
      depositMethod: (json['depositMethod'] ?? '').toString(),
      methodCode: (json['methodCode'] ?? '').toString(),
      minDeposit: toD(json['minDeposit']),
      maxDeposit: toD(json['maxDeposit']),
      groupId: json['groupId']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}