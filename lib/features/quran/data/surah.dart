import 'package:flutter/foundation.dart';

/// One surah from the Al-Quran Cloud API (GET /v1/surah).
@immutable
class Surah {
  const Surah({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.translation,
    required this.revelationType,
    required this.ayahCount,
  });

  final int number;

  /// Arabic name without the word "سورة", e.g. "ٱلْفَاتِحَةِ".
  final String arabicName;

  /// e.g. "Al-Faatiha"
  final String englishName;

  /// e.g. "The Opening"
  final String translation;

  /// "Meccan" or "Medinan"
  final String revelationType;

  final int ayahCount;

  bool get isMeccan => revelationType.toLowerCase().startsWith('mecc');

  /// Second line of a list row: "The Opening · Meccan · 7 verses"
  String get meta {
    final verses = ayahCount == 1 ? 'verse' : 'verses';
    return '$translation · $revelationType · $ayahCount $verses';
  }

  /// Lower-case text used by the search box (English + Arabic, no symbols).
  String get searchKey => normalize('$englishName $translation $arabicName');

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: (json['number'] as num).toInt(),
      arabicName: _removeSurahWord((json['name'] ?? '') as String),
      englishName: (json['englishName'] ?? '') as String,
      translation: (json['englishNameTranslation'] ?? '') as String,
      revelationType: (json['revelationType'] ?? '') as String,
      ayahCount: (json['numberOfAyahs'] as num?)?.toInt() ?? 0,
    );
  }

  // Arabic diacritics (harakat), tatweel
  static final _diacritics = RegExp(r'[ً-ٰٟۖ-ۭـ]');
  static final _alefs = RegExp(r'[ٱآأإ]');
  static final _notLetters = RegExp(r'[^a-z0-9ء-ي]');

  /// Makes text comparable: lower case, no diacritics, one kind of alef,
  /// and no spaces or punctuation. Works for English and Arabic.
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(_diacritics, '')
        .replaceAll(_alefs, 'ا')
        .replaceAll(_notLetters, '');
  }

  /// "سُورَةُ ٱلْفَاتِحَةِ" -> "ٱلْفَاتِحَةِ"
  static String _removeSurahWord(String name) {
    final i = name.indexOf(' ');
    if (i == -1) return name;
    final firstWord = name.substring(0, i).replaceAll(_diacritics, '');
    return firstWord == 'سورة' ? name.substring(i + 1).trim() : name;
  }
}
