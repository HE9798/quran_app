import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Finds which surah a mushaf page belongs to (needed to open the reader at
/// a page). Uses Al-Quran Cloud: /page/{n}/quran-uthmani, saved after the
/// first time. If there is no internet, a built-in table of surah start pages
/// is used.
class KhatmaRepository {
  static const _key = 'khatma_page_surah_v1';
  static final _memory = <int, int>{};

  Future<int> surahForPage(int page) async {
    final cached = _memory[page];
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = jsonDecode(prefs.getString(_key) ?? '{}') as Map<String, dynamic>;
      final hit = saved['$page'];
      if (hit is int) return _memory[page] = hit;
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/page/$page/quran-uthmani'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        final ayahs = data['ayahs'] as List<dynamic>;
        final surah = (ayahs.first as Map<String, dynamic>)['surah'] as Map<String, dynamic>;
        final number = (surah['number'] as num).toInt();
        _memory[page] = number;
        try {
          final saved = jsonDecode(prefs.getString(_key) ?? '{}') as Map<String, dynamic>;
          saved['$page'] = number;
          await prefs.setString(_key, jsonEncode(saved));
        } catch (_) {}
        return number;
      }
    } catch (_) {
      // use the table below
    }
    return _fromTable(page);
  }

  /// Surah that is on [page], from the first page of each surah.
  static int _fromTable(int page) {
    var surah = 1;
    for (var i = 0; i < _startPages.length; i++) {
      if (_startPages[i] <= page) surah = i + 1;
    }
    return surah;
  }

  // Madinah mushaf (604 pages): page where each surah (1..114) starts.
  static const _startPages = [
    1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267,
    282, 293, 305, 312, 322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411,
    415, 418, 428, 434, 440, 446, 453, 458, 467, 477, 483, 489, 496, 499, 502,
    507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549, 551,
    553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578,
    580, 582, 583, 585, 586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595,
    595, 596, 596, 597, 597, 598, 598, 599, 599, 600, 600, 601, 601, 601, 602,
    602, 602, 603, 603, 603, 604, 604, 604,
  ];
}
