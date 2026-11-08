import 'package:flutter/foundation.dart';

import 'surah.dart';

/// One verse with its Arabic text, translation and tafseer.
@immutable
class Ayah {
  const Ayah({
    required this.numberInSurah,
    required this.arabic,
    required this.translation,
    required this.tafseer,
    required this.page,
    required this.juz,
  });

  final int numberInSurah;

  /// Uthmani Arabic text (the Bismillah is removed from verse 1, see below).
  final String arabic;

  /// English: Saheeh International
  final String translation;

  /// Arabic: Tafsir Al-Muyassar. Empty when it could not be loaded.
  final String tafseer;

  final int page;
  final int juz;

  static const _bismillahKey = 'بسماللهالرحمنالرحيم';

  /// The API puts the Bismillah in front of verse 1 of every surah except
  /// Al-Fatihah (where it IS verse 1) and At-Tawbah. We show it as a
  /// separate header instead, so it is removed from the verse text here.
  static String _withoutBismillah(String text) {
    final words = text.trim().split(' ');
    if (words.length <= 4) return text;
    final start = Surah.normalize(words.take(4).join(' '));
    return start == _bismillahKey ? words.skip(4).join(' ') : text;
  }

  factory Ayah.fromEditions({
    required int surahNumber,
    required Map<String, dynamic> arabic,
    Map<String, dynamic>? translation,
    Map<String, dynamic>? tafseer,
  }) {
    final number = (arabic['numberInSurah'] as num).toInt();
    var text = (arabic['text'] ?? '') as String;
    if (number == 1 && surahNumber != 1) text = _withoutBismillah(text);

    return Ayah(
      numberInSurah: number,
      arabic: text,
      translation: (translation?['text'] ?? '') as String,
      tafseer: (tafseer?['text'] ?? '') as String,
      page: (arabic['page'] as num?)?.toInt() ?? 0,
      juz: (arabic['juz'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A surah together with all of its verses.
@immutable
class SurahDetail {
  const SurahDetail({required this.surah, required this.ayahs});

  final Surah surah;
  final List<Ayah> ayahs;

  /// Al-Fatihah has it as verse 1, At-Tawbah has none.
  bool get showBismillah => surah.number != 1 && surah.number != 9;

  bool get hasTafseer => ayahs.any((a) => a.tafseer.isNotEmpty);
}
