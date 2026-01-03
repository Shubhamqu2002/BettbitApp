import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/withdrawal_method_item.dart';

class WithdrawalMethodsService {
  static const String _root = "https://walletservice.bettbit.com";

  Future<List<WithdrawalMethodItem>> fetchWithdrawalMethods({
    required String countryCode,
  }) async {
    final cc = countryCode.trim().isEmpty ? "IN" : countryCode.trim();
    final url = Uri.parse("$_root/country-selection/withdrawal/$cc");

    final res = await http.get(url).timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Failed to load withdrawal methods (${res.statusCode})");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! Map) {
      return [];
    }

    final List<WithdrawalMethodItem> items = [];

    decoded.forEach((provider, list) {
      if (list is List) {
        for (final it in list) {
          if (it is Map<String, dynamic>) {
            items.add(WithdrawalMethodItem.fromJson(provider.toString(), it));
          } else if (it is Map) {
            items.add(
              WithdrawalMethodItem.fromJson(
                provider.toString(),
                Map<String, dynamic>.from(it),
              ),
            );
          }
        }
      }
    });

    // Sort: BILLBLEND then GPT then others (optional)
    items.sort((a, b) {
      int w(String p) {
        if (p.toUpperCase() == "BILLBLEND") return 0;
        if (p.toUpperCase() == "GPT") return 1;
        return 2;
      }

      final wa = w(a.provider);
      final wb = w(b.provider);
      if (wa != wb) return wa.compareTo(wb);
      return a.withdrawalMethod.toLowerCase().compareTo(b.withdrawalMethod.toLowerCase());
    });

    return items;
  }
}
