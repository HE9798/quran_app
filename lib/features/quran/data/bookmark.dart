import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Where I stopped": one saved page of the Quran.
@immutable
class Bookmark {
  const Bookmark({
    required this.surah,
    required this.surahName,
    required this.page,
    required this.juz,
  });

  final int surah;
  final String surahName;

  /// Page number in the Madinah Mushaf (1 - 604).
  final int page;
  final int juz;

  bool isPage(int surah, int page) => this.surah == surah && this.page == page;

  Map<String, dynamic> toJson() => {
        'surah': surah,
        'surahName': surahName,
        'page': page,
        'juz': juz,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        surah: (json['surah'] as num).toInt(),
        surahName: (json['surahName'] ?? '') as String,
        page: (json['page'] as num).toInt(),
        juz: (json['juz'] as num?)?.toInt() ?? 0,
      );
}

/// Keeps the saved page on the phone and tells every screen when it changes
/// (the reader's bookmark icon and the "Continue reading" card on Home).
class BookmarkStore {
  BookmarkStore._();

  static final BookmarkStore instance = BookmarkStore._();

  static const _key = 'last_page_bookmark_v1';

  final ValueNotifier<Bookmark?> current = ValueNotifier<Bookmark?>(null);

  Future<void>? _loading;

  /// Reads the saved page once. Safe to call many times.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        current.value =
            Bookmark.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // a damaged or missing value just means "nothing saved"
    }
  }

  Future<void> save(Bookmark bookmark) async {
    await ensureLoaded();
    current.value = bookmark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(bookmark.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    await ensureLoaded();
    current.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
