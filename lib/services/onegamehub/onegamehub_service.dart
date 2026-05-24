import 'dart:convert';
import 'package:http/http.dart' as http;

class OneGameHubService {
  static const String _baseUrl = 'https://walletservice.bettbit.com/games/launch';

  Future<String> launchGame({
    required String gameCode,
    required String playerId,
    required String currency,
    required String userName,
  }) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "gameCode": gameCode,
        "playerId": playerId,
        "currency": currency,
        "userName": userName,
        "demo": false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('1GameHub launch failed: ${response.body}');
    }

    final data = jsonDecode(response.body);

    final launchUrl = data['payload']?['launchUrl']?.toString() ?? '';

    if (launchUrl.isEmpty) {
      throw Exception('1GameHub launch URL not found.');
    }

    return launchUrl;
  }
}