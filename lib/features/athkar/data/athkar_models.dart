import 'package:flutter/foundation.dart';

enum AthkarSet {
  morning('Morning', 'أذكار الصباح'),
  evening('Evening', 'أذكار المساء');

  const AthkarSet(this.label, this.arabic);

  final String label;
  final String arabic;
}

/// One dhikr: its Arabic text and how many times it is repeated.
@immutable
class Dhikr {
  const Dhikr({
    required this.text,
    required this.repeat,
    this.source,
    this.virtue,
  });

  final String text;

  /// How many times to say it (1 or more).
  final int repeat;

  /// Where it is reported from, e.g. "صحيح البخاري". Optional.
  final String? source;

  /// The reward or a note about it. Optional.
  final String? virtue;

  /// The first few words, used as the short title in the list.
  String get title {
    final words = text.split(RegExp(r'\s+'));
    return words.length <= 5 ? text : '${words.take(5).join(' ')}…';
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'repeat': repeat,
        'source': source,
        'virtue': virtue,
      };

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
        text: json['text'] as String,
        repeat: (json['repeat'] as num).toInt(),
        source: json['source'] as String?,
        virtue: json['virtue'] as String?,
      );
}
