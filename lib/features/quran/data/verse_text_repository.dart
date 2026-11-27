import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/text/html_text.dart' as html_text;

import 'reading_sources.dart';
import 'surah_detail.dart';

/// The text of a tafsir or translation for one verse.
class VerseText {
  const VerseText(this.text, {this.covers = const []});

  final String text;

  /// The verses this passage explains ("2:8", "2:9"). Some tafsirs explain a
  /// few verses together; then every one of them shows the same passage.
  final List<String> covers;
}

/// Loads tafsir and translation text from the sources in [ReadingSources]
/// and saves it on the phone (the app's cache folder; the system may clear
/// it, which only means it is downloaded again).
///
///  - tafsir from Quran.com: one verse at a time (some are very long, e.g.
///    al-Tabari), saved per surah as it is read
///  - translations from Quran.com, al-Jalalayn from Al-Quran Cloud: a whole
///    surah at once (small)
class VerseTextRepository {
  VerseTextRepository._();
  static final instance = VerseTextRepository._();

  static const _qc = 'https://api.quran.com/api/v4';
  static const _aqc = 'https://api.alquran.cloud/v1';

  // memory copies: source key + surah -> verse number -> text
  final _verses = <String, Map<String, VerseText>>{};
  final _lists = <String, List<String>>{};

  Future<VerseText> load(TextSource source, int surah, Ayah ayah) async {
    final verse = ayah.numberInSurah;
    switch (source.key) {
      case 'builtin:muyassar':
        return VerseText(ayah.tafseer);
      case 'builtin:sahih':
        return VerseText(ayah.translation);
    }
    if (source.key.startsWith('aqc:')) {
      final list = await _aqcSurah(source.key.substring(4), surah);
      return VerseText(verse - 1 < list.length ? list[verse - 1] : '');
    }
    final id = source.key.substring(3); // qc:<id>
    if (source.kind == SourceKind.translation) {
      final list = await _qcTranslation(id, surah);
      return VerseText(verse - 1 < list.length ? list[verse - 1] : '');
    }
    return _qcTafsir(id, surah, verse);
  }

  // ------------------------------------------------------- Quran.com tafsir
  Future<VerseText> _qcTafsir(String id, int surah, int verse) async {
    final cacheKey = 'tafsir_qc${id}_$surah';
    final map = _verses[cacheKey] ??= await _readMap(cacheKey);
    final hit = map['$verse'];
    if (hit != null) return hit;

    final body = await _get('$_qc/tafsirs/$id/by_ayah/$surah:$verse');
    final t = (jsonDecode(body) as Map<String, dynamic>)['tafsir'] as Map<String, dynamic>;
    final covers = ((t['verses'] as Map?)?.keys.cast<String>().toList() ?? <String>[])
      ..sort((a, b) => _verseNo(a).compareTo(_verseNo(b)));
    final result = VerseText(htmlToText((t['text'] as String?) ?? ''), covers: covers);
    // the same passage serves every verse it covers
    map['$verse'] = result;
    for (final k in covers) {
      if (k.startsWith('$surah:')) map['${_verseNo(k)}'] = result;
    }
    await _writeMap(cacheKey, map);
    return result;
  }

  static int _verseNo(String key) => int.tryParse(key.split(':').last) ?? 0;

  // ------------------------------------------------- Quran.com translations
  Future<List<String>> _qcTranslation(String id, int surah) async {
    final cacheKey = 'translation_qc${id}_$surah';
    final mem = _lists[cacheKey] ??= await _readList(cacheKey);
    if (mem.isNotEmpty) return mem;
    final body = await _get('$_qc/quran/translations/$id?chapter_number=$surah');
    final list = [
      for (final t in ((jsonDecode(body) as Map<String, dynamic>)['translations'] as List))
        htmlToText(((t as Map)['text'] as String?) ?? '', dropFootnotes: true),
    ];
    if (list.isEmpty) throw const FormatException('Empty translation');
    _lists[cacheKey] = list;
    await _writeList(cacheKey, list);
    return list;
  }

  // ---------------------------------------------------- Al-Quran Cloud surah
  Future<List<String>> _aqcSurah(String edition, int surah) async {
    final cacheKey = 'aqc_${edition}_$surah';
    final mem = _lists[cacheKey] ??= await _readList(cacheKey);
    if (mem.isNotEmpty) return mem;
    final body = await _get('$_aqc/surah/$surah/$edition');
    final data = (jsonDecode(body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final list = [
      for (final a in (data['ayahs'] as List)) (((a as Map)['text'] as String?) ?? '').trim(),
    ];
    if (list.isEmpty) throw const FormatException('Empty surah');
    _lists[cacheKey] = list;
    await _writeList(cacheKey, list);
    return list;
  }

  // -------------------------------------------------------------- HTML text
  /// Quran.com sends tafsir as HTML (paragraphs, headings, quoted verses) and
  /// translations with footnote numbers (`<sup foot_note=..>1</sup>`). This
  /// turns it into plain text with paragraph breaks.
  static String htmlToText(String html, {bool dropFootnotes = false}) =>
      html_text.htmlToText(html, dropFootnotes: dropFootnotes);

  // ------------------------------------------------------------------ cache
  File? _file(String key) {
    try {
      final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      return File('${Directory.systemTemp.path}/${safe}_v2.json'); // v2: escaped quotes cleaned
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, VerseText>> _readMap(String key) async {
    final f = _file(key);
    try {
      if (f != null && await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return {
          for (final e in j.entries)
            e.key: VerseText(
              (e.value as Map)['t'] as String,
              covers: ((e.value as Map)['c'] as List?)?.cast<String>() ?? const [],
            ),
        };
      }
    } catch (_) {}
    return {};
  }

  Future<void> _writeMap(String key, Map<String, VerseText> map) async {
    try {
      await _file(key)?.writeAsString(jsonEncode({
        for (final e in map.entries) e.key: {'t': e.value.text, 'c': e.value.covers},
      }));
    } catch (_) {}
  }

  Future<List<String>> _readList(String key) async {
    final f = _file(key);
    try {
      if (f != null && await f.exists()) {
        return (jsonDecode(await f.readAsString()) as List).cast<String>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _writeList(String key, List<String> list) async {
    try {
      await _file(key)?.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  static Future<String> _get(String url) async {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return utf8.decode(r.bodyBytes); // keeps Arabic text correct
  }
}
