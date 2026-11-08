import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A place in the Quran: a surah and the mushaf page you were on.
@immutable
class SavedPage {
  const SavedPage({
    required this.surahNumber,
    required this.surahName,
    required this.arabicName,
    required this.page,
    required this.juz,
    required this.savedAt,
  });

  final int surahNumber;
  final String surahName; // English, e.g. "Al-Baqara"
  final String arabicName;
  final int page; //          mushaf page, 1-604
  final int juz;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'surahNumber': surahNumber,
        'surahName': surahName,
        'arabicName': arabicName,
        'page': page,
        'juz': juz,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory SavedPage.fromJson(Map<String, dynamic> json) => SavedPage(
        surahNumber: (json['surahNumber'] as num).toInt(),
        surahName: (json['surahName'] ?? '') as String,
        arabicName: (json['arabicName'] ?? '') as String,
        page: (json['page'] as num).toInt(),
        juz: (json['juz'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['savedAt'] as num).toInt(),
        ),
      );
}

/// Bookmarks + "last read" position, saved on the phone.
/// Screens listen to it, so the Saved tab and the Home card update by themselves.
class BookmarkStore extends ChangeNotifier {
  BookmarkStore._();

  static final BookmarkStore instance = BookmarkStore._();

  static const _bookmarksKey = 'bookmarks_v1';
  static const _lastReadKey = 'last_read_v1';

  SharedPreferences? _prefs;
  List<SavedPage> _bookmarks = const [];
  SavedPage? _lastRead;

  /// Newest first.
  List<SavedPage> get bookmarks => _bookmarks;

  /// The page you were reading last (saved automatically).
  SavedPage? get lastRead => _lastRead;

  bool isSaved(int surahNumber, int page) =>
      _bookmarks.any((b) => b.surahNumber == surahNumber && b.page == page);

  /// Call once before runApp.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      final loaded = <SavedPage>[];
      for (final raw in prefs.getStringList(_bookmarksKey) ?? const <String>[]) {
        final page = _decode(raw);
        if (page != null) loaded.add(page);
      }
      _bookmarks = loaded;

      final last = prefs.getString(_lastReadKey);
      _lastRead = last == null ? null : _decode(last);
    } catch (_) {
      // Saved data is a bonus: the app still works without it.
    }
  }

  SavedPage? _decode(String raw) {
    try {
      return SavedPage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves the page, or removes it if it was already saved.
  /// Returns true when the page is saved after the call.
  Future<bool> toggle(SavedPage page) async {
    final existing = _bookmarks.indexWhere(
      (b) => b.surahNumber == page.surahNumber && b.page == page.page,
    );
    if (existing != -1) {
      _bookmarks = [..._bookmarks]..removeAt(existing);
    } else {
      _bookmarks = [page, ..._bookmarks];
    }
    notifyListeners();
    await _persistBookmarks();
    return existing == -1;
  }

  Future<void> remove(SavedPage page) async {
    _bookmarks = _bookmarks
        .where((b) => !(b.surahNumber == page.surahNumber && b.page == page.page))
        .toList();
    notifyListeners();
    await _persistBookmarks();
  }

  Future<void> setLastRead(SavedPage page) async {
    final same = _lastRead != null &&
        _lastRead!.surahNumber == page.surahNumber &&
        _lastRead!.page == page.page;
    if (same) return;
    _lastRead = page;
    notifyListeners();
    try {
      await _prefs?.setString(_lastReadKey, jsonEncode(page.toJson()));
    } catch (_) {}
  }

  Future<void> _persistBookmarks() async {
    try {
      await _prefs?.setStringList(
        _bookmarksKey,
        [for (final b in _bookmarks) jsonEncode(b.toJson())],
      );
    } catch (_) {}
  }
}
