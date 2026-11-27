import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/text/html_text.dart';

/// A quote from Sahih al-Bukhari or Sahih Muslim backing a step.
class Evidence {
  const Evidence({required this.refAr, required this.refEn, required this.text});

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        refAr: j['ar'] as String,
        refEn: j['en'] as String,
        text: j['text'] as String,
      );

  final String refAr; // "رواه مسلم (1218)"
  final String refEn; // "Sahih Muslim 1218"
  final String text;
}

/// One rite: what to do, when, its supplications and its evidence.
class ManasikStep {
  const ManasikStep({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.whenAr,
    required this.whenEn,
    required this.pointsAr,
    required this.pointsEn,
    required this.duas,
    required this.evidence,
  });

  factory ManasikStep.fromJson(Map<String, dynamic> j) => ManasikStep(
        id: j['id'] as String,
        titleAr: j['titleAr'] as String,
        titleEn: j['titleEn'] as String,
        whenAr: (j['whenAr'] as String?) ?? '',
        whenEn: (j['whenEn'] as String?) ?? '',
        pointsAr: (j['pointsAr'] as List).cast<String>(),
        pointsEn: (j['pointsEn'] as List).cast<String>(),
        duas: ((j['duas'] as List?) ?? const []).cast<int>(),
        evidence: [
          for (final e in (j['evidence'] as List? ?? const []))
            Evidence.fromJson(e as Map<String, dynamic>),
        ],
      );

  final String id;
  final String titleAr, titleEn, whenAr, whenEn;
  final List<String> pointsAr, pointsEn;

  /// Hisn al-Muslim chapter numbers (hisnmuslim.com/api).
  final List<int> duas;
  final List<Evidence> evidence;
}

/// Umrah, or one of the three ways of doing Hajj.
class ManasikGuide {
  const ManasikGuide({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.introAr,
    required this.introEn,
    required this.steps,
  });

  factory ManasikGuide.fromJson(Map<String, dynamic> j) => ManasikGuide(
        id: j['id'] as String,
        titleAr: j['titleAr'] as String,
        titleEn: j['titleEn'] as String,
        introAr: j['introAr'] as String,
        introEn: j['introEn'] as String,
        steps: [
          for (final s in (j['steps'] as List)) ManasikStep.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String id, titleAr, titleEn, introAr, introEn;
  final List<ManasikStep> steps;
}

/// The whole guide, shipped with the app (assets/manasik/manasik.json).
class ManasikBook {
  const ManasikBook({
    required this.guides,
    required this.info,
    required this.jabir,
    required this.sourceAr,
    required this.sourceEn,
  });

  final List<ManasikGuide> guides;

  /// Reference cards (types of Hajj, Miqat points, pillars, ...). Same shape
  /// as a step.
  final List<ManasikStep> info;

  /// Jabir's full description of the Prophet's Hajj (Muslim 1218).
  final Evidence jabir;
  final String sourceAr, sourceEn;

  static ManasikBook? _cached;

  static Future<ManasikBook> load() async {
    final ready = _cached;
    if (ready != null) return ready;
    final j = jsonDecode(await rootBundle.loadString('assets/manasik/manasik.json'))
        as Map<String, dynamic>;
    final source = j['source'] as Map<String, dynamic>;
    return _cached = ManasikBook(
      guides: [
        for (final g in (j['guides'] as List)) ManasikGuide.fromJson(g as Map<String, dynamic>),
      ],
      info: [
        for (final s in (j['info'] as List)) ManasikStep.fromJson(s as Map<String, dynamic>),
      ],
      jabir: Evidence.fromJson(j['jabir'] as Map<String, dynamic>),
      sourceAr: source['ar'] as String,
      sourceEn: source['en'] as String,
    );
  }
}

// ------------------------------------------------------------ Hisn al-Muslim

/// One supplication from Hisn al-Muslim.
class HisnDua {
  const HisnDua({
    required this.arabic,
    required this.translation,
    required this.transliteration,
    required this.repeat,
  });

  final String arabic;
  final String translation;
  final String transliteration;
  final int repeat;
}

/// A Hisn al-Muslim chapter ("كيف يلبي المحرم ...") with its supplications.
class HisnChapter {
  const HisnChapter({required this.titleEn, required this.duas});

  final String titleEn;
  final List<HisnDua> duas;
}

/// Loads Hisn al-Muslim chapters from its official API (hisnmuslim.com).
/// The English file has the Arabic text, the translation and a
/// transliteration together. Each chapter is saved on the phone after the
/// first download.
class HisnRepository {
  HisnRepository._();
  static final instance = HisnRepository._();

  final _memory = <int, HisnChapter>{};
  final _pending = <int, Future<HisnChapter>>{};

  Future<HisnChapter> chapter(int id) {
    final ready = _memory[id];
    if (ready != null) return Future.value(ready);
    // (a block, not "=> _pending.remove(id)": remove returns this same future,
    // and whenComplete would then wait for it, forever)
    return _pending[id] ??= _load(id).whenComplete(() {
      _pending.remove(id);
    });
  }

  Future<HisnChapter> _load(int id) async {
    final file = _file(id);
    if (file != null && await file.exists()) {
      try {
        return _memory[id] = _parse(await file.readAsString());
      } catch (_) {
        await file.delete().catchError((_) => file);
      }
    }
    final r = await http
        .get(Uri.parse('https://www.hisnmuslim.com/api/en/$id.json'))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('Server error (${r.statusCode})');
    final body = utf8.decode(r.bodyBytes);
    final result = _parse(body);
    try {
      await file?.writeAsString(body);
    } catch (_) {}
    return _memory[id] = result;
  }

  static HisnChapter _parse(String body) {
    // the files start with a byte-order mark
    final j = jsonDecode(body.replaceFirst('﻿', '')) as Map<String, dynamic>;
    final entry = j.entries.first;
    String clean(Object? s) => htmlToText('${s ?? ''}');
    final duas = [
      for (final d in (entry.value as List))
        HisnDua(
          arabic: clean((d as Map)['ARABIC_TEXT']),
          translation: clean(d['TRANSLATED_TEXT']),
          transliteration: clean(d['LANGUAGE_ARABIC_TRANSLATED_TEXT']),
          repeat: int.tryParse('${d['REPEAT']}') ?? 1,
        ),
    ];
    if (duas.isEmpty) throw const FormatException('Empty chapter');
    return HisnChapter(titleEn: entry.key, duas: duas);
  }

  File? _file(int id) {
    try {
      return File('${Directory.systemTemp.path}/hisn_en_${id}_v1.json');
    } catch (_) {
      return null;
    }
  }
}

/// Arabic titles of the Hisn al-Muslim chapters the guide uses.
const hisnTitlesAr = <int, String>{
  96: 'دعاء السفر',
  105: 'ذكر الرجوع من السفر',
  115: 'التلبية',
  116: 'التكبير عند الحجر الأسود',
  117: 'الدعاء بين الركن اليماني والحجر الأسود',
  118: 'الذكر على الصفا والمروة',
  119: 'الدعاء يوم عرفة',
  120: 'الذكر عند المشعر الحرام',
  121: 'التكبير عند رمي الجمار',
};
