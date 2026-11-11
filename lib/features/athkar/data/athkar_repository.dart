import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../hadith/data/hadith_models.dart' show normalizeArabic;
import 'athkar_models.dart';

/// Morning and evening athkar from free public sources.
///
/// The sources are tried in this order until one gives both lists:
///  1. azkar-api by nawafalqari (a JSON file on GitHub)
///  2. Hisn al-Muslim, chapter 27 "أذكار الصباح والمساء" (hisnmuslim.com)
///
/// Whatever the source, the result is saved on the phone in one simple format,
/// so the app works offline after the first download.
class AthkarRepository {
  AthkarRepository._();
  static final instance = AthkarRepository._();

  static const _sources = [
    'https://raw.githubusercontent.com/nawafalqari/azkar-api/main/azkar.json',
    'https://www.hisnmuslim.com/api/ar/27.json',
  ];

  final _client = http.Client();
  Map<AthkarSet, List<Dhikr>>? _memory;
  Future<Map<AthkarSet, List<Dhikr>>>? _pending;

  Future<Map<AthkarSet, List<Dhikr>>> loadAll() {
    final ready = _memory;
    if (ready != null) return Future.value(ready);
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<Map<AthkarSet, List<Dhikr>>> _load() async {
    final file = _cacheFile();

    if (file != null && await file.exists()) {
      try {
        final saved = _fromCache(await file.readAsString());
        if (saved != null) return _memory = saved;
      } catch (_) {
        await file.delete().catchError((_) => file);
      }
    }

    Object? lastError;
    for (final url in _sources) {
      try {
        final response =
            await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw Exception('Server error (${response.statusCode})');
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final result = _split(json);
        if (result == null) throw const FormatException('No morning/evening lists');
        await _save(file, result);
        return _memory = result;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not load athkar');
  }

  // ---------------------------------------------------------- reading data

  /// Finds the morning and evening lists in whatever shape the source uses:
  ///  - {"أذكار الصباح": [ {...}, ... ], "أذكار المساء": [ ... ]}
  ///  - [ {"title": "أذكار الصباح", "content": [ {...} ]}, ... ]
  ///  - one list of items that each have a "category"
  /// A single combined list ("أذكار الصباح والمساء") is used for both.
  Map<AthkarSet, List<Dhikr>>? _split(Object? json) {
    final categories = <String, List<Dhikr>>{};

    void add(String category, Object? raw) {
      if (raw is! Map) return;
      final dhikr = _dhikr(raw);
      if (dhikr != null) (categories[category] ??= []).add(dhikr);
    }

    void addAll(String category, Object? items) {
      if (items is! List) return;
      for (final item in items) {
        // an item may carry its own category (one flat list)
        final own = item is Map ? item['category'] : null;
        add(own is String && own.isNotEmpty ? own : category, item);
      }
    }

    Object? innerList(Map value) =>
        value['content'] ?? value['array'] ?? value['data'] ?? value['items'];

    if (json is Map) {
      json.forEach((key, value) {
        if (value is List) {
          addAll('$key', value);
        } else if (value is Map) {
          addAll('$key', innerList(value));
        }
      });
    } else if (json is List) {
      for (final entry in json) {
        if (entry is! Map) continue;
        final name = '${entry['title'] ?? entry['category'] ?? entry['name'] ?? ''}';
        final inner = innerList(entry);
        if (inner is List) {
          addAll(name, inner);
        } else {
          add(name, entry);
        }
      }
    }

    List<Dhikr>? morning, evening, both;
    categories.forEach((name, items) {
      final n = normalizeArabic(name);
      final hasMorning = n.contains('الصباح');
      final hasEvening = n.contains('المساء');
      if (hasMorning && hasEvening) {
        both ??= items;
      } else if (hasMorning) {
        morning ??= items;
      } else if (hasEvening) {
        evening ??= items;
      }
    });

    final m = morning ?? (both == null ? null : _forPeriod(both!, AthkarSet.morning));
    final e = evening ?? (both == null ? null : _forPeriod(both!, AthkarSet.evening));
    if (m == null || e == null || m.isEmpty || e.isEmpty) return null;
    return {AthkarSet.morning: m, AthkarSet.evening: e};
  }

  /// From a combined list, removes the athkar that are only for the other
  /// time of day ("أمسينا وأمسى الملك لله" in the morning, and so on).
  List<Dhikr> _forPeriod(List<Dhikr> all, AthkarSet set) {
    final wrongStarts = set == AthkarSet.morning
        ? ['امسينا', 'اللهم بك امسينا', 'اللهم ما امسي بي']
        : ['اصبحنا', 'اللهم بك اصبحنا', 'اللهم ما اصبح بي'];
    final kept = [
      for (final d in all)
        if (!wrongStarts.any(normalizeArabic(d.text).startsWith)) d,
    ];
    return kept.isEmpty ? all : kept;
  }

  Dhikr? _dhikr(Map raw) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = raw[key];
        if (value == null) continue;
        final text = '$value'.replaceAll('\r', '').trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final text = pick(['content', 'zekr', 'text', 'ARABIC_TEXT', 'arabic', 'dhikr']);
    if (text == null) return null;

    var repeat = 1;
    final rawCount = raw['count'] ?? raw['repeat'] ?? raw['REPEAT'] ?? raw['times'];
    if (rawCount is num) {
      repeat = rawCount.toInt();
    } else if (rawCount != null) {
      final match = RegExp(r'\d+').firstMatch('$rawCount');
      if (match != null) repeat = int.parse(match.group(0)!);
    }
    repeat = repeat.clamp(1, 1000);

    return Dhikr(
      text: text,
      repeat: repeat,
      source: pick(['reference', 'source']),
      virtue: pick(['description', 'bless', 'virtue']),
    );
  }

  // ----------------------------------------------------------- saved copy

  File? _cacheFile() {
    try {
      return File('${Directory.systemTemp.path}/athkar_v1.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(File? file, Map<AthkarSet, List<Dhikr>> data) async {
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        for (final entry in data.entries)
          entry.key.name: [for (final d in entry.value) d.toJson()],
      }));
    } catch (_) {}
  }

  Map<AthkarSet, List<Dhikr>>? _fromCache(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final result = <AthkarSet, List<Dhikr>>{};
    for (final set in AthkarSet.values) {
      final list = json[set.name] as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      result[set] = [
        for (final item in list) Dhikr.fromJson(item as Map<String, dynamic>),
      ];
    }
    return result;
  }
}
