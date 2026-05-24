import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'deposit_models.dart';

class DepositService {
  final String baseUrl;

  DepositService({
    this.baseUrl = 'https://walletservice.bettbit.com',
  });

  /// GET
  /// https://walletservice.bettbit.com/country-selection/deposit/{country}
  /// ?operatorCode=ZA3857&device=MOBILE
  ///
  /// Returns: BILLBLEND + GPT + PASSIMPAY (if present)
  Future<DepositMethodsResponse> fetchDepositMethods(
    String countryCode,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Get operatorCode from local storage
    final operatorCode = prefs.getString('platform_code') ?? '';

    final uri = Uri.parse(
      '$baseUrl/country-selection/deposit/$countryCode',
    ).replace(
      queryParameters: {
        'operatorCode': operatorCode,
        'device': 'MOBILE', // ✅ Hardcoded
      },
    );

    // ✅ API Request Log
    print('================ DEPOSIT API REQUEST ================');
    print('API URL => $uri');
    print('Operator Code => $operatorCode');
    print('Country Code => $countryCode');
    print('=====================================================');

    final res = await http.get(
      uri,
      headers: {
        'accept': 'application/json',
      },
    );

    // ✅ API Response Log
    print('================ DEPOSIT API RESPONSE ===============');
    print('Status Code => ${res.statusCode}');
    print('Response Body => ${res.body}');
    print('=====================================================');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Failed to load deposit methods (${res.statusCode})',
      );
    }

    final body = jsonDecode(res.body);

    final billblendList =
        (body is Map<String, dynamic>) ? body['BILLBLEND'] : null;

    final gptList =
        (body is Map<String, dynamic>) ? body['GPT'] : null;

    final passimpayList =
        (body is Map<String, dynamic>) ? body['PASSIMPAY'] : null;

    final billblend = (billblendList is List)
        ? billblendList
            .map(
              (e) => DepositMethod.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <DepositMethod>[];

    final gpt = (gptList is List)
        ? gptList
            .map(
              (e) => DepositMethod.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <DepositMethod>[];

    final passimpay = (passimpayList is List)
        ? passimpayList
            .map(
              (e) => DepositMethod.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <DepositMethod>[];

    return DepositMethodsResponse(
      billblend: billblend,
      gpt: gpt,
      passimpay: passimpay,
    );
  }

  /// Backward-compatible (if you still call this from somewhere else)
  Future<List<DepositMethod>> fetchBillblendDepositMethods(
    String countryCode,
  ) async {
    final resp = await fetchDepositMethods(countryCode);
    return resp.billblend;
  }

  /// Optional helper for GPT-only methods
  Future<List<DepositMethod>> fetchGptDepositMethods(
    String countryCode,
  ) async {
    final resp = await fetchDepositMethods(countryCode);
    return resp.gpt;
  }

  /// Optional helper for PASSIMPAY-only methods
  Future<List<DepositMethod>> fetchPassimpayDepositMethods(
    String countryCode,
  ) async {
    final resp = await fetchDepositMethods(countryCode);
    return resp.passimpay;
  }
}