import 'package:flutter/foundation.dart';

/// A reciter (sheikh). [id] is the audio edition on Al-Quran Cloud,
/// e.g. "ar.alafasy".
@immutable
class Reciter {
  const Reciter({
    required this.id,
    required this.name,
    required this.englishName,
  });

  final String id;
  final String name; //        Arabic: مشاري راشد العفاسي
  final String englishName; // Mishary Rashid Alafasy

  /// Two letters for the round avatar: "MA".
  String get initials {
    final words = englishName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .toList();
    if (words.isEmpty) return '؟';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'englishName': englishName,
      };

  factory Reciter.fromJson(Map<String, dynamic> json) => Reciter(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        englishName: (json['englishName'] ?? '') as String,
      );

  @override
  bool operator ==(Object other) => other is Reciter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Used when the list cannot be downloaded (no internet the first time).
  static const alafasy = Reciter(
    id: 'ar.alafasy',
    name: 'مشاري راشد العفاسي',
    englishName: 'Mishary Rashid Alafasy',
  );

  static const fallbackList = <Reciter>[
    alafasy,
    Reciter(
      id: 'ar.husary',
      name: 'محمود خليل الحصري',
      englishName: 'Mahmoud Khalil Al-Husary',
    ),
    Reciter(
      id: 'ar.minshawi',
      name: 'محمد صديق المنشاوي',
      englishName: 'Mohamed Siddiq El-Minshawi',
    ),
    Reciter(
      id: 'ar.hudhaify',
      name: 'علي بن عبد الرحمن الحذيفي',
      englishName: 'Ali Al-Hudhaify',
    ),
    Reciter(
      id: 'ar.muhammadjibreel',
      name: 'محمد جبريل',
      englishName: 'Muhammad Jibreel',
    ),
  ];
}
