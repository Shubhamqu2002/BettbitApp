import 'dart:convert';
import 'package:http/http.dart' as http;

import 'deposit_models.dart';

class DepositService {
  final String baseUrl;

  DepositService({
    this.baseUrl = 'https://walletservice.nexxorra.com',
  });

  /// GET https://walletservice.nexxorra.com/country-selection/deposit/{country}
  /// Returns BOTH: BILLBLEND + GPT (if present)
  Future<DepositMethodsResponse> fetchDepositMethods(String countryCode) async {
    final uri = Uri.parse('$baseUrl/country-selection/deposit/$countryCode');

    final res = await http.get(uri, headers: {
      'accept': 'application/json',
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to load deposit methods (${res.statusCode})');
    }

    final body = jsonDecode(res.body);

    final billblendList =
        (body is Map<String, dynamic>) ? body['BILLBLEND'] : null;
    final gptList = (body is Map<String, dynamic>) ? body['GPT'] : null;

    final billblend = (billblendList is List)
        ? billblendList
            .map((e) =>
                DepositMethod.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <DepositMethod>[];

    final gpt = (gptList is List)
        ? gptList
            .map((e) =>
                DepositMethod.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <DepositMethod>[];

    return DepositMethodsResponse(
      billblend: billblend,
      gpt: gpt,
    );
  }

  /// Backward-compatible (if you still call this from somewhere else)
  Future<List<DepositMethod>> fetchBillblendDepositMethods(
      String countryCode) async {
    final resp = await fetchDepositMethods(countryCode);
    return resp.billblend;
  }
}
