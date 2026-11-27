import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum SourceKind { tafsir, translation }

/// One tafsir or translation the reader can show under a verse.
///
/// [key] says where the text comes from:
///  - `builtin:...` already inside the surah download (Al-Quran Cloud), so it
///    shows at once, also offline: Al-Muyassar and Saheeh International
///  - `qc:<id>`    Quran.com API (Quran Foundation), resource id
///  - `aqc:<id>`   Al-Quran Cloud (Islamic Network), edition identifier
@immutable
class TextSource {
  const TextSource({
    required this.key,
    required this.kind,
    required this.nameEn,
    required this.nameAr,
    required this.author,
    required this.languageEn,
    required this.languageAr,
    this.rtl = false,
  });

  final String key;
  final SourceKind kind;
  final String nameEn;
  final String nameAr;
  final String author;
  final String languageEn; // "Arabic", "English", "Urdu" ...
  final String languageAr; // "العربية", "الإنجليزية" ... (English when unknown)
  final bool rtl; //          written right to left (Arabic, Urdu, Kurdish ...)

  bool get isArabic => languageEn.toLowerCase() == 'arabic';
  String name(bool arabicUi) => arabicUi && nameAr.isNotEmpty ? nameAr : nameEn;
  String language(bool arabicUi) => arabicUi && languageAr.isNotEmpty ? languageAr : languageEn;

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind.name,
        'en': nameEn,
        'ar': nameAr,
        'author': author,
        'lang': languageEn,
        'langAr': languageAr,
        'rtl': rtl,
      };

  factory TextSource.fromJson(Map<String, dynamic> j) => TextSource(
        key: j['key'] as String,
        kind: SourceKind.values.byName(j['kind'] as String),
        nameEn: j['en'] as String,
        nameAr: (j['ar'] as String?) ?? '',
        author: (j['author'] as String?) ?? '',
        languageEn: j['lang'] as String,
        languageAr: (j['langAr'] as String?) ?? '',
        rtl: (j['rtl'] as bool?) ?? false,
      );
}

/// The list of tafsirs and translations, and which one the user picked for
/// each tab. The lists come live from Quran.com (Quran Foundation) and are
/// saved on the phone; they are refreshed once a week.
class ReadingSources extends ChangeNotifier {
  ReadingSources._();
  static final instance = ReadingSources._();

  static const _qc = 'https://api.quran.com/api/v4';
  static const _kCatalog = 'reading_sources_v3';
  static const _kFetched = 'reading_sources_fetched_v3';
  static const _kTafsir = 'reading_tafsir_v1';
  static const _kTranslation = 'reading_translation_v1';

  // ---- always there (no download needed for the first two)
  static const muyassar = TextSource(
    key: 'builtin:muyassar',
    kind: SourceKind.tafsir,
    nameEn: 'Al-Muyassar',
    nameAr: 'التفسير الميسر',
    author: 'King Fahd Quran Complex',
    languageEn: 'Arabic',
    languageAr: 'العربية',
    rtl: true,
  );
  static const sahih = TextSource(
    key: 'builtin:sahih',
    kind: SourceKind.translation,
    nameEn: 'Saheeh International',
    nameAr: 'صحيح إنترناشيونال',
    author: 'Saheeh International',
    languageEn: 'English',
    languageAr: 'الإنجليزية',
  );
  // Al-Quran Cloud has al-Jalalayn, which Quran.com does not
  static const jalalayn = TextSource(
    key: 'aqc:ar.jalalayn',
    kind: SourceKind.tafsir,
    nameEn: 'Tafsir al-Jalalayn',
    nameAr: 'تفسير الجلالين',
    author: 'Jalal ad-Din al-Mahalli & Jalal ad-Din as-Suyuti',
    languageEn: 'Arabic',
    languageAr: 'العربية',
    rtl: true,
  );

  // Quran.com ids that duplicate the built-in ones (not listed twice)
  static const _dupes = {'qc:16', 'qc:20'}; // Muyassar, Saheeh International

  // Quran.com's author field for these is a short label ("Saddi", "Baghawy"):
  // their full names instead
  static const _authors = {
    'qc:14': "Isma'il ibn Kathir",
    'qc:15': 'Muhammad ibn Jarir al-Tabari',
    'qc:90': 'Muhammad ibn Ahmad al-Qurtubi',
    'qc:91': "Abd al-Rahman al-Sa'di",
    'qc:93': 'Muhammad Sayyid Tantawi',
    'qc:94': "al-Husayn ibn Mas'ud al-Baghawi",
  };

  // the big Arabic tafsirs first, in this order (then the rest)
  static const _tafsirOrder = [
    'builtin:muyassar', 'qc:91', 'qc:14', 'qc:15', 'qc:90', 'qc:94', 'qc:93', 'aqc:ar.jalalayn',
  ];

  List<TextSource> tafsirs = const [muyassar, jalalayn];
  List<TextSource> translations = const [sahih];
  String _tafsirKey = muyassar.key;
  String _translationKey = sahih.key;
  bool _loaded = false;
  Future<void>? _refreshing;

  TextSource get tafsir => _find(tafsirs, _tafsirKey) ?? muyassar;
  TextSource get translation => _find(translations, _translationKey) ?? sahih;
  TextSource chosen(SourceKind kind) => kind == SourceKind.tafsir ? tafsir : translation;
  List<TextSource> listOf(SourceKind kind) => kind == SourceKind.tafsir ? tafsirs : translations;

  static TextSource? _find(List<TextSource> list, String key) {
    for (final s in list) {
      if (s.key == key) return s;
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _tafsirKey = prefs.getString(_kTafsir) ?? _tafsirKey;
      _translationKey = prefs.getString(_kTranslation) ?? _translationKey;
      final raw = prefs.getString(_kCatalog);
      if (raw != null) _apply(raw);
      final fetched = DateTime.tryParse(prefs.getString(_kFetched) ?? '');
      final stale = fetched == null || DateTime.now().difference(fetched).inDays >= 7;
      if (stale) refresh(); // in the background
    } catch (_) {}
    notifyListeners();
  }

  /// Downloads the lists again (once at a time). Failing only keeps the old lists.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _get('$_qc/resources/tafsirs?language=ar'),
        _get('$_qc/resources/translations?language=ar'),
        _get('$_qc/resources/languages?language=ar'),
      ]);
      final languages = <String, ({String ar, bool rtl})>{};
      for (final l in (jsonDecode(results[2])['languages'] as List).cast<Map<String, dynamic>>()) {
        final en = (l['name'] as String).toLowerCase();
        final ar = ((l['translated_name'] as Map?)?['name'] as String?) ?? '';
        languages[en] = (ar: _hasArabicLetters(ar) ? ar : '', rtl: l['direction'] == 'rtl');
      }

      TextSource fromQc(Map<String, dynamic> r, SourceKind kind) {
        final langKey = (r['language_name'] as String).toLowerCase();
        final lang = languages[langKey];
        final translated = (r['translated_name'] as Map?)?['name'] as String? ?? '';
        return TextSource(
          key: 'qc:${r['id']}',
          kind: kind,
          nameEn: _latinName(r['name'] as String),
          nameAr: _hasArabicLetters(translated) ? _tidyArabic(translated) : '',
          author: _authors['qc:${r['id']}'] ?? ((r['author_name'] as String?) ?? '').trim(),
          languageEn: _capitalise(langKey.split(',').first.trim()), // "uighur, uyghur" -> "Uighur"
          languageAr: lang?.ar ?? '',
          rtl: lang?.rtl ?? langKey == 'arabic',
        );
      }

      final tafsirList = [
        muyassar,
        jalalayn,
        for (final r in (jsonDecode(results[0])['tafsirs'] as List).cast<Map<String, dynamic>>())
          fromQc(r, SourceKind.tafsir),
      ].where((s) => !_dupes.contains(s.key)).toList();
      final translationList = [
        sahih,
        for (final r in (jsonDecode(results[1])['translations'] as List).cast<Map<String, dynamic>>())
          fromQc(r, SourceKind.translation),
      ].where((s) => !_dupes.contains(s.key)).toList();
      if (tafsirList.length < 3 || translationList.length < 3) return; // something is off: keep the old lists

      final raw = jsonEncode({
        'tafsirs': [for (final s in tafsirList) s.toJson()],
        'translations': [for (final s in translationList) s.toJson()],
      });
      _apply(raw);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCatalog, raw);
      await prefs.setString(_kFetched, DateTime.now().toIso8601String());
      notifyListeners();
    } catch (_) {
      // offline or the server is down: the saved (or built-in) lists stay
    }
  }

  void _apply(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final t = [for (final e in (j['tafsirs'] as List)) TextSource.fromJson(e as Map<String, dynamic>)];
    final tr = [for (final e in (j['translations'] as List)) TextSource.fromJson(e as Map<String, dynamic>)];
    tafsirs = _sorted(t, _tafsirOrder, firstLanguage: 'Arabic');
    translations = _sorted(tr, const ['builtin:sahih'], firstLanguage: 'English');
  }

  /// Grouped by language: [firstLanguage] first (with [order] at its top),
  /// then the other languages A to Z.
  static List<TextSource> _sorted(List<TextSource> list, List<String> order, {required String firstLanguage}) {
    int rank(TextSource s) {
      final i = order.indexOf(s.key);
      return i == -1 ? order.length : i;
    }

    final out = [...list];
    out.sort((a, b) {
      final la = a.languageEn == firstLanguage ? '' : a.languageEn;
      final lb = b.languageEn == firstLanguage ? '' : b.languageEn;
      final c = la.compareTo(lb);
      if (c != 0) return c;
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase());
    });
    return out;
  }

  Future<void> select(TextSource source) async {
    if (source.kind == SourceKind.tafsir) {
      _tafsirKey = source.key;
    } else {
      _translationKey = source.key;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(source.kind == SourceKind.tafsir ? _kTafsir : _kTranslation, source.key);
    } catch (_) {}
  }

  /// Names as Quran.com sends them can carry Persian letters (ی ک), stretching
  /// marks (ـ) and direction marks; written the Arabic way here.
  static String _tidyArabic(String s) => s
      .replaceAll('‎', '')
      .replaceAll('‏', '')
      .replaceAll('ـ', '')
      .replaceAll('ی', 'ي')
      .replaceAll('ک', 'ك')
      .replaceAll('ابنِ', 'ابن')
      .trim();

  /// "السعدي Al-Sa'di" -> "Al-Sa'di": an English name with Arabic mixed in
  /// keeps the English part (the Arabic name is shown in the Arabic layout).
  static String _latinName(String s) {
    final t = s.trim();
    if (!_hasArabicLetters(t) || !RegExp(r'[A-Za-z]').hasMatch(t)) return t;
    return t.replaceAll(RegExp(r'[؀-ۿ‎‏]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _hasArabicLetters(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);
  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static Future<String> _get(String url) async {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return utf8.decode(r.bodyBytes);
  }
}
