import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'data/khatma_store.dart';

/// دعاء ختم القرآن. Opens when a khatma is completed (and from the Khatma
/// page at any time).
///
/// No supplication for completing the Quran is authentically reported from
/// the Prophet ﷺ, so the page shows, in this order:
///  1. what is authentic: Anas ibn Malik gathering his family to make dua
///  2. the well-known khatm dua, clearly marked as NOT from the Prophet ﷺ
///     (its common attribution to Ibn Taymiyyah is not established either)
///  3. authentic supplications from the Quran and the Sunnah
/// The Muslim narrations were checked word for word against Sahih Muslim.
class KhatmaDuaScreen extends StatelessWidget {
  const KhatmaDuaScreen({super.key, this.justCompleted = false});

  /// Opened right after finishing a khatma: shows the congratulations.
  final bool justCompleted;

  static const _athar = _Dua(
    arabic: 'كَانَ أَنَسُ بْنُ مَالِكٍ رَضِيَ اللَّهُ عَنْهُ إِذَا خَتَمَ الْقُرْآنَ جَمَعَ أَهْلَهُ وَوَلَدَهُ فَدَعَا لَهُمْ',
    english: 'When Anas ibn Malik (may Allah be pleased with him) completed the Quran, '
        'he would gather his family and children and make dua for them.',
    refAr: 'رواه الدارمي في سننه بإسناد صحيح',
    refEn: 'Sunan al-Darimi, with an authentic chain',
  );

  static const _popular = _Dua(
    arabic: 'اللَّهُمَّ ارْحَمْنِي بِالْقُرْآنِ، وَاجْعَلْهُ لِي إِمَامًا وَنُورًا وَهُدًى وَرَحْمَةً، '
        'اللَّهُمَّ ذَكِّرْنِي مِنْهُ مَا نَسِيتُ، وَعَلِّمْنِي مِنْهُ مَا جَهِلْتُ، '
        'وَارْزُقْنِي تِلَاوَتَهُ آنَاءَ اللَّيْلِ وَأَطْرَافَ النَّهَارِ، '
        'وَاجْعَلْهُ لِي حُجَّةً يَا رَبَّ الْعَالَمِينَ',
    english: 'O Allah, have mercy on me through the Quran, and make it for me a guide, a light, '
        'guidance and mercy. O Allah, remind me of what I have forgotten of it, teach me what I '
        'do not know of it, grant me its recitation through the hours of the night and the ends '
        'of the day, and make it a proof for me, O Lord of the worlds.',
    refAr: '',
    refEn: '',
  );

  static const _authentic = [
    _Dua(
      arabic: 'رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ',
      english: 'Our Lord, accept this from us. You are the All-Hearing, the All-Knowing.',
      refAr: 'سورة البقرة: ١٢٧',
      refEn: 'Quran 2:127',
    ),
    _Dua(
      arabic: 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن لَّدُنكَ رَحْمَةً إِنَّكَ أَنتَ الْوَهَّابُ',
      english: 'Our Lord, do not let our hearts swerve after You have guided us, and grant us '
          'mercy from Yourself. You are the Giver.',
      refAr: 'سورة آل عمران: ٨',
      refEn: 'Quran 3:8',
    ),
    _Dua(
      arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      english: 'Our Lord, give us good in this world and good in the Hereafter, and protect us '
          'from the punishment of the Fire.',
      refAr: 'سورة البقرة: ٢٠١',
      refEn: 'Quran 2:201',
    ),
    _Dua(
      arabic: 'اللَّهُمَّ إِنِّي عَبْدُكَ، ابْنُ عَبْدِكَ، ابْنُ أَمَتِكَ، نَاصِيَتِي بِيَدِكَ، مَاضٍ فِيَّ حُكْمُكَ، '
          'عَدْلٌ فِيَّ قَضَاؤُكَ، أَسْأَلُكَ بِكُلِّ اسْمٍ هُوَ لَكَ، سَمَّيْتَ بِهِ نَفْسَكَ، أَوْ عَلَّمْتَهُ أَحَدًا '
          'مِنْ خَلْقِكَ، أَوْ أَنْزَلْتَهُ فِي كِتَابِكَ، أَوِ اسْتَأْثَرْتَ بِهِ فِي عِلْمِ الْغَيْبِ عِنْدَكَ، '
          'أَنْ تَجْعَلَ الْقُرْآنَ رَبِيعَ قَلْبِي، وَنُورَ صَدْرِي، وَجِلَاءَ حُزْنِي، وَذَهَابَ هَمِّي',
      english: 'O Allah, I am Your servant, son of Your servant, son of Your maidservant. My '
          'forelock is in Your hand, Your judgement upon me is done, and Your decree upon me is '
          'just. I ask You by every name that is Yours, by which You named Yourself, or taught to '
          'any of Your creation, or revealed in Your Book, or kept with Yourself in the knowledge '
          'of the unseen, to make the Quran the spring of my heart, the light of my chest, the '
          'removal of my sadness and the end of my worry.',
      refAr: 'رواه أحمد (٣٧١٢)، وصححه الألباني',
      refEn: 'Musnad Ahmad 3712, graded authentic by al-Albani',
    ),
    _Dua(
      arabic: 'اللَّهُمَّ أَصْلِحْ لِي دِينِيَ الَّذِي هُوَ عِصْمَةُ أَمْرِي، وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا '
          'مَعَاشِي، وَأَصْلِحْ لِي آخِرَتِي الَّتِي فِيهَا مَعَادِي، وَاجْعَلِ الْحَيَاةَ زِيَادَةً لِي فِي كُلِّ '
          'خَيْرٍ، وَاجْعَلِ الْمَوْتَ رَاحَةً لِي مِنْ كُلِّ شَرٍّ',
      english: 'O Allah, set right for me my religion, which is the safeguard of my affairs; set '
          'right for me my world, in which is my living; set right for me my Hereafter, to which '
          'is my return. Make life an increase for me in every good, and make death a rest for me '
          'from every evil.',
      refAr: 'رواه مسلم (٢٧٢٠)',
      refEn: 'Sahih Muslim 2720',
    ),
    _Dua(
      arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى',
      english: 'O Allah, I ask You for guidance, piety, chastity and sufficiency.',
      refAr: 'رواه مسلم (٢٧٢١)',
      refEn: 'Sahih Muslim 2721',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final count = KhatmaStore.instance.completedCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr('Back', 'رجوع'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/khatma'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Completing the Quran', 'دعاء ختم القرآن'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  Text(
                    context.tr('What is authentic, and what to say', 'ما ثبت عند الختم وما يُدعى به'),
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (justCompleted) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_stories_rounded, size: 40, color: p.onPrimarySoft),
                const SizedBox(height: 8),
                Text(
                  context.tr('Khatma completed', 'تمت الختمة'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.onPrimarySoft),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('May Allah accept it from you.', 'تقبّل الله منك.'),
                  style: TextStyle(fontSize: 15, color: p.onPrimarySoft),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.tr('Khatmas completed: $count', 'الختمات المكتملة: ${context.n(count)}'),
                    style: TextStyle(fontSize: 13, color: p.onPrimarySoft.withValues(alpha: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 1 - what is authentic
        _Heading(context.tr('What the Companions did', 'ما ثبت عن الصحابة')),
        Text(
          context.tr(
            'No specific supplication for completing the Quran is authentically reported from the '
                'Prophet ﷺ. What is reported is that the Companions made dua at that time, and the '
                'scholars considered it a moment when dua is hoped to be answered.',
            'لم يثبت عن النبي ﷺ دعاءٌ مخصوص لختم القرآن، والثابت أن الصحابة كانوا يدعون عند الختم، '
                'وعدّه العلماء من مواطن رجاء الإجابة.',
          ),
          style: TextStyle(fontSize: 14, height: 1.6, color: p.muted),
        ),
        const SizedBox(height: 10),
        const _DuaCard(dua: _athar),
        const SizedBox(height: 24),

        // 2 - the well-known one, clearly labelled
        _Heading(context.tr('A well-known khatm dua', 'دعاء مشهور عند الختم')),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    'A general dua, not a narration from the Prophet ﷺ. Its common attribution to '
                        'Ibn Taymiyyah is not established. It may be said as any dua, without '
                        'believing it to be a Sunnah.',
                    'دعاءٌ عام وليس من كلام النبي ﷺ، ونسبته المشهورة إلى ابن تيمية لا تثبت. '
                        'يُدعى به كسائر الأدعية دون اعتقاد أنه سنة.',
                  ),
                  style: TextStyle(fontSize: 13, height: 1.5, color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _DuaCard(dua: _popular),
        const SizedBox(height: 24),

        // 3 - authentic supplications
        _Heading(context.tr('From the Quran and the Sunnah', 'أدعية من القرآن والسنة')),
        for (final d in _authentic) ...[
          _DuaCard(dua: d),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        if (justCompleted)
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => context.go('/khatma'),
              child: Text(
                context.tr('Start a new khatma', 'ابدأ ختمة جديدة'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dua {
  const _Dua({required this.arabic, required this.english, required this.refAr, required this.refEn});
  final String arabic, english, refAr, refEn;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

/// Arabic text (always right to left), the translation in English, and the source.
class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.dua});
  final _Dua dua;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ar = context.isArabic;
    final ref = ar ? dua.refAr : dua.refEn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dua.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: AppTheme.arabic(size: 20, height: 1.9),
          ),
          if (!ar) ...[
            const SizedBox(height: 8),
            Text(dua.english, style: TextStyle(fontSize: 14, height: 1.5, color: p.muted)),
          ],
          if (ref.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(ref, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted)),
          ],
        ],
      ),
    );
  }
}
