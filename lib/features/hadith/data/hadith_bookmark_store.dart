import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hadith_models.dart';

/// A hadith the user saved. The text is kept too, so the Saved tab works
/// without internet.
@immutable
class SavedHadith {
  const SavedHadith({
    required this.id,
    required this.label,
    required this.text,
    required this.savedAt,
  });

  final String id; //    "bukhari:1"
  final String label; // "صحيح البخاري · 1"
  final String text;
  final DateTime savedAt;

  factory SavedHadith.from(Hadith hadith) => SavedHadith(
        id: hadith.id,
        label: hadith.label,
        text: hadith.text,
        savedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'text': text,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory SavedHadith.fromJson(Map<String, dynamic> json) => SavedHadith(
        id: json['id'] as String,
        label: (json['label'] ?? '') as String,
        text: (json['text'] ?? '') as String,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['savedAt'] as num).toInt(),
        ),
      );
}

/// Saved hadiths, kept on the phone. Screens listen to it.
class HadithBookmarkStore extends ChangeNotifier {
  HadithBookmarkStore._();
  static final instance = HadithBookmarkStore._();

  static const _key = 'hadith_bookmarks_v1';

  SharedPreferences? _prefs;
  List<SavedHadith> _items = const [];

  /// Newest first.
  List<SavedHadith> get items => _items;

  bool isSaved(String id) => _items.any((h) => h.id == id);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final loaded = <SavedHadith>[];
      for (final raw in prefs.getStringList(_key) ?? const <String>[]) {
        try {
          loaded.add(
            SavedHadith.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
      _items = loaded;
    } catch (_) {}
  }

  /// Saves the hadith, or removes it when it was already saved.
  Future<bool> toggle(Hadith hadith) async {
    final saved = isSaved(hadith.id);
    if (saved) {
      await removeById(hadith.id);
    } else {
      _items = [SavedHadith.from(hadith), ..._items];
      notifyListeners();
      await _persist();
    }
    return !saved;
  }

  Future<void> removeById(String id) async {
    _items = _items.where((h) => h.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setStringList(
        _key,
        [for (final h in _items) jsonEncode(h.toJson())],
      );
    } catch (_) {}
  }
}
