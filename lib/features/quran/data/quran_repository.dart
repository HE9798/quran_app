import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'surah.dart';
import 'surah_detail.dart';

/// Loads Quran data from the free Al-Quran Cloud API
/// (https://api.alquran.cloud) and keeps a saved copy on the phone.
class QuranRepository {
  QuranRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.alquran.cloud/v1';
  static const _listCacheKey = 'surah_list_v1';

  // Edition identifiers on Al-Quran Cloud
  static const _arabic = 'quran-uthmani'; //  Uthmani script
  static const _translation = 'en.sahih'; //  Saheeh International
  static const _tafseer = 'ar.muyassar'; //   Tafsir Al-Muyassar

  // ------------------------------------------------------------ surah list

  /// The 114 surahs. Never changes, so it is saved after the first download.
  Future<List<Surah>> getSurahs() async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(_listCacheKey);
    if (cached != null) {
      try {
        return _parseList(cached);
      } catch (_) {
        await prefs.remove(_listCacheKey); // damaged copy, download again
      }
    }

    final body = await _get('$_base/surah');
    final surahs = _parseList(body);
    await prefs.setString(_listCacheKey, body);
    return surahs;
  }

  List<Surah> _parseList(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    final surahs = data
        .map((e) => Surah.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    if (surahs.isEmpty) throw const FormatException('Empty surah list');
    return surahs;
  }

  // ---------------------------------------------------------- surah verses

  /// All verses of one surah: Arabic + English translation + Arabic tafseer
  /// in a single request. The result is saved in the app's cache folder
  /// (files, not SharedPreferences, because a long surah is large).
  Future<SurahDetail> getSurahDetail(int number) async {
    final file = _cacheFile(number);

    if (file != null && await file.exists()) {
      try {
        return _parseDetail(number, await file.readAsString());
      } catch (_) {
        await file.delete().catchError((_) => file); // damaged, download again
      }
    }

    try {
      final body = await _get('$_base/surah/$number/editions/'
          '$_arabic,$_translation,$_tafseer');
      final detail = _parseDetail(number, body);
      await _save(file, body);
      return detail;
    } catch (_) {
      // If only the tafseer edition is the problem, still let people read.
      final body = await _get('$_base/surah/$number/editions/'
          '$_arabic,$_translation');
      return _parseDetail(number, body); // not saved: tafseer is missing
    }
  }

  SurahDetail _parseDetail(int number, String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final editions = (json['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    // Find a list of verses by edition name; null if that edition is absent.
    List<Map<String, dynamic>>? ayahsOf(String identifier) {
      for (final e in editions) {
        final edition = e['edition'] as Map<String, dynamic>?;
        if (edition?['identifier'] == identifier) {
          return (e['ayahs'] as List<dynamic>).cast<Map<String, dynamic>>();
        }
      }
      return null;
    }

    final arabic = ayahsOf(_arabic);
    if (arabic == null || arabic.isEmpty) {
      throw const FormatException('Arabic text missing');
    }
    final translation = ayahsOf(_translation);
    final tafseer = ayahsOf(_tafseer);

    final ayahs = <Ayah>[
      for (var i = 0; i < arabic.length; i++)
        Ayah.fromEditions(
          surahNumber: number,
          arabic: arabic[i],
          translation:
              translation != null && i < translation.length ? translation[i] : null,
          tafseer: tafseer != null && i < tafseer.length ? tafseer[i] : null,
        ),
    ];

    return SurahDetail(
      surah: Surah.fromJson(editions.first),
      ayahs: ayahs,
    );
  }

  // ----------------------------------------------------------------- utils

  Future<String> _get(String url) async {
    final response =
        await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }
    return utf8.decode(response.bodyBytes); // keeps the Arabic text correct
  }

  /// The app's cache folder. The system may clear it, which only means the
  /// surah is downloaded again.
  File? _cacheFile(int number) {
    try {
      return File('${Directory.systemTemp.path}/surah_${number}_v1.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(File? file, String body) async {
    if (file == null) return;
    try {
      await file.writeAsString(body);
    } catch (_) {
      // saving is only a speed-up, never fail the screen because of it
    }
  }
}
