import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../hadith/data/hadith_models.dart' show normalizeArabic;

/// The topics a dua can have (the chips on the page). Same keys as
/// tool/build_duas.py.
const duaTopics = [
  'forgiveness', 'guidance', 'protection', 'hardship', 'family',
  'goodness', 'praise', 'occasions',
];

/// A dua from the Quran: the words of the dua cut from its verse(s).
class QuranDua {
  QuranDua({
    required this.arabic,
    required this.english,
    required this.surah,
    required this.from,
    required this.to,
    required this.surahAr,
    required this.surahEn,
    required this.topic,
  });

  factory QuranDua.fromJson(Map<String, dynamic> j) => QuranDua(
        arabic: j['ar'] as String,
        english: j['en'] as String,
        surah: j['surah'] as int,
        from: j['from'] as int,
        to: j['to'] as int,
        surahAr: j['surahAr'] as String,
        surahEn: j['surahEn'] as String,
        topic: j['topic'] as String,
      );

  final String arabic, english, surahAr, surahEn, topic;

  /// Arabic without harakat, the English and the surah names, for search.
  late final String searchKey = normalizeArabic('$arabic $surahAr سورة $english $surahEn');
  final int surah, from, to;

  /// "2:201" or "20:25-28"
  String get verses => from == to ? '$from' : '$from-$to';
}

/// A dua from Sahih al-Bukhari or Sahih Muslim.
class HadithDua {
  HadithDua({
    required this.arabic,
    required this.english,
    required this.book,
    required this.number,
    required this.titleAr,
    required this.titleEn,
    required this.topic,
  });

  factory HadithDua.fromJson(Map<String, dynamic> j) => HadithDua(
        arabic: j['ar'] as String,
        english: j['en'] as String,
        book: j['book'] as String,
        number: j['number'] as int,
        titleAr: (j['titleAr'] as String?) ?? '',
        titleEn: (j['titleEn'] as String?) ?? '',
        topic: j['topic'] as String,
      );

  final String arabic, english, book, titleAr, titleEn, topic;

  /// Arabic without harakat, the English and the titles, for search.
  late final String searchKey = normalizeArabic('$arabic $titleAr $english $titleEn');
  final int number;

  bool get isBukhari => book == 'bukhari';
}

/// The duas shipped with the app (assets/dua/duas.json, made by
/// tool/build_duas.py from the Quran and hadith APIs).
class DuaBook {
  const DuaBook({
    required this.quran,
    required this.hadith,
    required this.sourceAr,
    required this.sourceEn,
  });

  final List<QuranDua> quran;
  final List<HadithDua> hadith;
  final String sourceAr, sourceEn;

  static DuaBook? _cached;

  static Future<DuaBook> load() async {
    final ready = _cached;
    if (ready != null) return ready;
    final j = jsonDecode(await rootBundle.loadString('assets/dua/duas.json'))
        as Map<String, dynamic>;
    final source = j['source'] as Map<String, dynamic>;
    return _cached = DuaBook(
      quran: [
        for (final d in (j['quran'] as List)) QuranDua.fromJson(d as Map<String, dynamic>),
      ],
      hadith: [
        for (final d in (j['hadith'] as List)) HadithDua.fromJson(d as Map<String, dynamic>),
      ],
      sourceAr: source['ar'] as String,
      sourceEn: source['en'] as String,
    );
  }
}
