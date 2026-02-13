// lib/services/game_search_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'vendor_game_service.dart'; // uses GameModel + ApiException

class GameSearchPageResult {
  final List<GameModel> games;
  final int totalElements;
  final bool last;

  GameSearchPageResult({
    required this.games,
    required this.totalElements,
    required this.last,
  });
}

class GameSearchService {
  GameSearchService._();
  static final GameSearchService instance = GameSearchService._();

  static const String _base =
      "https://walletservice.bettbit.com/api/wallet/games/game-search";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟩 [GameSearchService] $msg");
  }

  String _safePreview(String s, {int max = 300}) {
    if (s.length <= max) return s;
    return "${s.substring(0, max)}... (len=${s.length})";
  }

  // ✅ IMPORTANT:
  // Search API returns `imageSquare` / `imageLandscape`
  // Normal list model expects `displayImageUrl` (commonly)
  // So we "adapt" the JSON BEFORE calling GameModel.fromJson.
  Map<String, dynamic> _adaptSearchJsonToGameModel(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);

    final img = (m["imageSquare"] ?? m["imageLandscape"] ?? "").toString();

    // inject best-known fields used by normal UI/model
    m["displayImageUrl"] = (m["displayImageUrl"] ?? img).toString();
    m["display_image_url"] = (m["display_image_url"] ?? img).toString();

    // keep vendor/game/category names stable
    m["gameName"] = (m["gameName"] ?? m["name"] ?? "").toString();
    m["gameCode"] = (m["gameCode"] ?? m["code"] ?? "").toString();
    m["vendorCode"] = (m["vendorCode"] ?? m["vendor"] ?? "").toString();

    // categoryCode should exist already, but keep fallback
    m["categoryCode"] = (m["categoryCode"] ?? m["category"] ?? "").toString();

    return m;
  }

  Future<GameSearchPageResult> searchGames({
    required String query,
    required String countryCode,
    int page = 0,
    int size = 24,
  }) async {
    final q = query.trim();
    final cc = countryCode.trim().isEmpty ? "IN" : countryCode.trim();

    if (q.isEmpty) {
      _log("searchGames() skipped: empty query");
      return GameSearchPageResult(games: [], totalElements: 0, last: true);
    }

    final encoded = Uri.encodeComponent(q);

    final uri = Uri.parse("$_base/$encoded").replace(
      queryParameters: {
        "countryCode": cc,
        "page": page.toString(),
        "size": size.toString(),
      },
    );

    _log("➡️ GET $uri");
    _log("   query='$q' countryCode='$cc' page=$page size=$size");

    http.Response res;
    try {
      res = await http.get(
        uri,
        headers: const {
          "Accept": "application/json, text/plain, */*",
        },
      );
    } catch (e) {
      _log("❌ Network error: $e");
      throw ApiException("Network error while searching games.");
    }

    _log("✅ status=${res.statusCode}");
    if (kDebugMode) _log("📦 body: ${_safePreview(res.body)}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException("Game search failed (${res.statusCode}).");
    }

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (e) {
      _log("❌ JSON parse error: $e");
      throw ApiException("Invalid response from game search API.");
    }

    final List content = (data["content"] as List?) ?? [];
    _log("📄 content.length=${content.length}");

    final games = <GameModel>[];
    for (final item in content) {
      try {
        final raw = Map<String, dynamic>.from(item as Map);
        final adapted = _adaptSearchJsonToGameModel(raw);
        final g = GameModel.fromJson(adapted);
        games.add(g);
      } catch (e) {
        _log("⚠️ skip game item parse error: $e");
      }
    }

    final totalElements = (data["totalElements"] as int?) ??
        (data["total_elements"] as int?) ??
        games.length;

    final last = (data["last"] as bool?) ??
        (data["isLast"] as bool?) ??
        (games.length < size);

    _log("🎮 parsed games=${games.length} totalElements=$totalElements last=$last");

    return GameSearchPageResult(
      games: games,
      totalElements: totalElements,
      last: last,
    );
  }
}
