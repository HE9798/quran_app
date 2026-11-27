import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/text/html_text.dart';
import 'hadith_models.dart';

/// Loads whole books from the free hadith API by fawazahmed0
/// (https://github.com/fawazahmed0/hadith-api). It is served from a CDN and
/// needs no key. A book is downloaded once and then kept on the phone.
class HadithRepository {
  HadithRepository._();
  static final instance = HadithRepository._();

  final _client = http.Client();
  final _memory = <String, HadithCollection>{};
  final _pending = <String, Future<HadithCollection>>{};

  /// Two addresses for the same file: if the first is blocked or down, the
  /// second one is tried.
  static List<String> _urls(String edition) => [
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$edition.min.json',
        'https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/editions/$edition.min.json',
      ];

  /// The book in Arabic or in English. If the English edition can't be
  /// loaded, the Arabic one is shown instead of an error.
  /// Hadith are content, not interface: they are always shown in Arabic,
  /// whatever language the app is set to.
  Future<HadithCollection> load(HadithBook book, {bool arabic = true}) =>
      _loadEdition(book, true);

  Future<HadithCollection> _loadEdition(HadithBook book, bool arabic) {
    final key = book.edition(arabic);
    final ready = _memory[key];
    if (ready != null) return Future.value(ready);
    // Two screens asking for the same book share one download.
    return _pending[key] ??= _load(book, arabic).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<HadithCollection> _load(HadithBook book, bool arabic) async {
    final edition = book.edition(arabic);
    // books shipped with the app
    if (edition.startsWith('asset:')) {
      final body = await rootBundle.loadString(edition.substring(6));
      return _memory[edition] =
          await compute(_parse, [body, book.name, arabic ? 'ar' : 'en']);
    }
    final file = _cacheFile(edition);

    if (file != null && await file.exists()) {
      try {
        final collection = await compute(_parse, [
          await file.readAsString(),
          book.name,
          arabic ? 'ar' : 'en',
        ]);
        return _memory[edition] = collection;
      } catch (_) {
        await file.delete().catchError((_) => file); // damaged, download again
      }
    }

    Object? lastError;
    for (final url in _urls(edition)) {
      try {
        final response = await _client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 90));
        if (response.statusCode != 200) {
          throw Exception('Server error (${response.statusCode})');
        }
        final body = utf8.decode(response.bodyBytes); // keeps Arabic correct
        final collection = await compute(_parse, [body, book.name, arabic ? 'ar' : 'en']);
        await _save(file, body);
        return _memory[edition] = collection;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not load $edition');
  }

  File? _cacheFile(String edition) {
    try {
      return File('${Directory.systemTemp.path}/hadith_${edition}_v1.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(File? file, String body) async {
    if (file == null) return;
    try {
      await file.writeAsString(body);
    } catch (_) {
      // saving only makes the next start faster
    }
  }
}

// -------------------------------------------------------------- parsing
// Runs in a background isolate (big books are several MB of JSON), so it is
// a top-level function and everything it returns is plain data.

HadithCollection _parse(List<String> args) {
  final book = HadithBook.values.byName(args[1]);
  final arabic = args[2] == 'ar';
  final json = jsonDecode(args[0]) as Map<String, dynamic>;
  final meta = (json['metadata'] as Map<String, dynamic>?) ?? const {};

  // chapter names: {"1": "كتاب بدء الوحي", ...}
  final names = <int, String>{};
  final rawNames = meta['section'];
  if (rawNames is Map) {
    rawNames.forEach((key, value) {
      final number = int.tryParse('$key');
      if (number != null) names[number] = '$value'.trim();
    });
  }

  // chapter ranges, used only when a hadith has no chapter of its own
  final ranges = <({int section, double first, double last})>[];
  final rawDetails = meta['section_details'];
  if (rawDetails is Map) {
    rawDetails.forEach((key, value) {
      final number = int.tryParse('$key');
      if (number == null || value is! Map) return;
      final first = _toDouble(value['hadithnumber_first']);
      final last = _toDouble(value['hadithnumber_last']);
      if (first != null && last != null) {
        ranges.add((section: number, first: first, last: last));
      }
    });
  }

  final hadiths = <Hadith>[];
  final counts = <int, int>{};
  for (final raw in (json['hadiths'] as List<dynamic>)) {
    if (raw is! Map) continue;
    // some ahadeeth carry HTML (e.g. <br> line breaks): plain text only
    final text = htmlToText('${raw['text'] ?? ''}');
    if (text.isEmpty) continue;

    final hadithNumber = raw['hadithnumber'];
    final arabicNumber = raw['arabicnumber'];
    final number = _numberLabel(
      (arabicNumber is num && arabicNumber != 0) ? arabicNumber : hadithNumber,
    );

    var section = 0;
    final reference = raw['reference'];
    if (reference is Map) section = int.tryParse('${reference['book']}') ?? 0;
    if (section == 0) {
      final n = _toDouble(hadithNumber);
      if (n != null) {
        for (final r in ranges) {
          if (n >= r.first && n <= r.last) {
            section = r.section;
            break;
          }
        }
      }
    }
    counts[section] = (counts[section] ?? 0) + 1;

    hadiths.add(Hadith(
      book: book,
      number: number,
      text: text,
      section: section,
      grade: _grade(raw['grades'], book, arabic),
      searchKey: normalizeArabic(text),
      label: '${book.titleFor(arabic)} · $number',
    ));
  }
  if (hadiths.isEmpty) throw const FormatException('No hadiths found');

  final sections = <HadithSection>[
    for (final entry in counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)))
      if (entry.key != 0 || names.isNotEmpty)
        HadithSection(
          number: entry.key,
          name: (names[entry.key] ?? '').isNotEmpty
              ? names[entry.key]!
              : (entry.key == 0
                  ? (arabic ? 'أحاديث أخرى' : 'Other hadiths')
                  : (arabic ? 'القسم ${entry.key}' : 'Section ${entry.key}')),
          count: entry.value,
        ),
  ];

  return HadithCollection(book: book, hadiths: hadiths, sections: sections);
}

double? _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

/// 12 -> "12", 12.1 -> "12.1"
String _numberLabel(Object? value) {
  if (value is num) {
    return value == value.truncate() ? '${value.truncate()}' : '$value';
  }
  return '${value ?? ''}';
}

/// Turns the grade given by the API into Arabic. The big two books are
/// agreed to be authentic, so they are marked "صحيح" when the API has none.
String? _grade(Object? grades, HadithBook book, bool arabic) {
  String g(String ar, String en) => arabic ? ar : en;
  if (grades is List) {
    for (final entry in grades) {
      final raw = (entry is Map ? '${entry['grade']}' : '$entry').toLowerCase();
      if (raw.contains('sahih') || raw.contains('صحيح')) return g('صحيح', 'Sahih');
      if (raw.contains('hasan') || raw.contains('حسن')) return g('حسن', 'Hasan');
      if (raw.contains('da') && raw.contains('if') || raw.contains('ضعيف')) {
        return g('ضعيف', "Da'if");
      }
    }
  }
  // the Forty books state their sources in the text itself
  return book.isForty ? null : g('صحيح', 'Sahih');
}
