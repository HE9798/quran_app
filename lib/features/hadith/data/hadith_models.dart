import 'package:flutter/foundation.dart';

/// The three books we show. [editionId] is the name of the Arabic edition in
/// the free hadith API (https://github.com/fawazahmed0/hadith-api).
enum HadithBook {
  nawawi('ara-nawawi', 'الأربعون النووية'),
  bukhari('ara-bukhari', 'صحيح البخاري'),
  muslim('ara-muslim', 'صحيح مسلم');

  const HadithBook(this.editionId, this.title);

  final String editionId;
  final String title;
}

/// Makes Arabic text comparable for search: removes the harakat (tashkeel)
/// and the tatweel, and unifies the different forms of alef, yaa and taa.
String normalizeArabic(String input) {
  return input
      .replaceAll(RegExp(r'[ً-ٰٟـ]'), '')
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .toLowerCase();
}

@immutable
class Hadith {
  const Hadith({
    required this.book,
    required this.number,
    required this.text,
    required this.section,
    required this.grade,
    required this.searchKey,
  });

  final HadithBook book;

  /// The number shown to the reader, e.g. "1" (kept as text: a few
  /// hadiths in the data have numbers like "1.1").
  final String number;

  /// Arabic text.
  final String text;

  /// Chapter ("kitab") number inside the book. 0 = none.
  final int section;

  /// "صحيح", "حسن", ... or null when the data has no grade.
  final String? grade;

  /// [text] normalized for searching (computed once when loading).
  final String searchKey;

  /// "صحيح البخاري · 1"
  String get label => '${book.title} · $number';

  /// Key used to save the bookmark.
  String get id => '${book.name}:$number';
}

@immutable
class HadithSection {
  const HadithSection({
    required this.number,
    required this.name,
    required this.count,
  });

  final int number;
  final String name; // "كتاب بدء الوحي"
  final int count; //   hadiths inside
}

/// A whole book: all hadiths plus its chapters.
class HadithCollection {
  HadithCollection({
    required this.book,
    required this.hadiths,
    required this.sections,
  }) : _bySection = {} {
    for (final h in hadiths) {
      (_bySection[h.section] ??= []).add(h);
    }
  }

  final HadithBook book;
  final List<Hadith> hadiths;
  final List<HadithSection> sections;
  final Map<int, List<Hadith>> _bySection;

  List<Hadith> inSection(int number) => _bySection[number] ?? const [];

  /// Hadiths whose text contains every word typed (diacritics ignored).
  /// Returns at most [limit] results.
  List<Hadith> search(String query, {int limit = 100}) {
    final words = normalizeArabic(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final results = <Hadith>[];
    for (final h in hadiths) {
      if (words.every(h.searchKey.contains)) {
        results.add(h);
        if (results.length >= limit) break;
      }
    }
    return results;
  }
}
