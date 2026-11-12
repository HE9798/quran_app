import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'reciter.dart';

/// Audio from Al-Quran Cloud (https://alquran.cloud), the same API as the
/// text. Every verse is a separate mp3 on its CDN (cdn.islamic.network),
/// which is what lets us start from any verse.
class AudioRepository {
  AudioRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.alquran.cloud/v1';
  static const _recitersKey = 'reciters_v1';

  final _urlCache = <String, List<String>>{};

  // -------------------------------------------------------------- reciters

  /// All verse-by-verse reciters. Saved after the first download; if that
  /// fails and nothing is saved, a short built-in list is used.
  Future<List<Reciter>> getReciters() async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(_recitersKey);
    if (cached != null) {
      try {
        final saved = _parseReciters(cached);
        if (saved.isNotEmpty) return saved;
      } catch (_) {
        await prefs.remove(_recitersKey);
      }
    }

    try {
      final body = await _get(
        '$_base/edition?format=audio&language=ar&type=versebyverse',
      );
      final list = _parseReciters(body);
      if (list.isNotEmpty) {
        await prefs.setString(_recitersKey, body);
        return list;
      }
    } catch (_) {
      // fall through to the built-in list
    }
    return Reciter.fallbackList;
  }

  List<Reciter> _parseReciters(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = (json['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    final list = <Reciter>[
      for (final e in data)
        if ((e['identifier'] as String?)?.isNotEmpty ?? false)
          Reciter(
            id: e['identifier'] as String,
            name: ((e['name'] ?? '') as String).trim(),
            englishName: ((e['englishName'] ?? '') as String).trim(),
          ),
    ];
    // the famous ones first, then the rest in the order of the API
    int rank(Reciter r) {
      final i = Reciter.fallbackList.indexOf(r);
      return i == -1 ? Reciter.fallbackList.length : i;
    }

    final sorted = [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted;
  }

  // ----------------------------------------------------------------- audio

  /// The mp3 address of every verse of [surah], in order, for [reciterId].
  Future<List<String>> getSurahUrls(int surah, String reciterId) async {
    final key = '$reciterId|$surah';
    final cached = _urlCache[key];
    if (cached != null) return cached;

    final body = await _get('$_base/surah/$surah/$reciterId');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final ayahs = (data['ayahs'] as List<dynamic>).cast<Map<String, dynamic>>();

    final urls = <String>[];
    for (final ayah in ayahs) {
      var url = ayah['audio'] as String?;
      if (url == null || url.isEmpty) {
        final secondary = ayah['audioSecondary'];
        if (secondary is List && secondary.isNotEmpty) {
          url = secondary.first as String?;
        }
      }
      if (url == null || url.isEmpty) {
        throw const FormatException('Missing audio address');
      }
      urls.add(url);
    }
    if (urls.isEmpty) throw const FormatException('No audio');
    return _urlCache[key] = urls;
  }

  Future<String> _get(String url) async {
    final response =
        await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }
    return utf8.decode(response.bodyBytes);
  }
}
