import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../audio/data/activity_reciters.dart';
import '../audio/reciter_sheet.dart';
import '../quran/data/quran_repository.dart';
import '../quran/data/surah.dart';
import 'data/hifz_store.dart';

/// Memorisation (hifz): the ranges the user is learning and when each one
/// needs revising.
class HifzScreen extends StatelessWidget {
  const HifzScreen({super.key});

  String _status(BuildContext context, HifzStore store, HifzItem i) {
    if (i.revisions == 0) {
      return context.tr('New · start memorising', 'جديد · ابدأ الحفظ');
    }
    final d = store.daysUntilDue(i);
    if (d < 0) {
      return context.tr('Revision late by ${-d} days',
          'المراجعة متأخرة ${context.n(-d)} يوم');
    }
    if (d == 0) return context.tr('Due for revision today', 'موعد المراجعة اليوم');
    if (d == 1) return context.tr('Next revision tomorrow', 'المراجعة القادمة غدًا');
    return context.tr('Next revision in $d days',
        'المراجعة القادمة بعد ${context.n(d)} يوم');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final store = HifzStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.tr('Back', 'رجوع'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Memorisation', 'الحفظ'),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3),
                        ),
                        Text(
                          store.isEmpty
                              ? context.tr('Repeat, hide, test yourself',
                                  'كرّر، أخفِ النص، واختبر نفسك')
                              : context.tr(
                                  '${store.dueCount} due for revision today',
                                  '${context.n(store.dueCount)} للمراجعة اليوم'),
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: context.tr('Add verses', 'إضافة آيات'),
                    onPressed: () => _showAddSheet(context),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            // the voice used in memorisation sessions (its own choice)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ReciterCard(activity: ActivityReciters.hifzKey),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_outlined, size: 48, color: p.muted),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('Nothing to memorise yet',
                                  'لا يوجد شيء للحفظ بعد'),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                'Choose a surah and the verses you want to memorise. The app repeats them for you, hides the text so you can test yourself, and reminds you when to revise.',
                                'اختر سورة والآيات التي تريد حفظها. يكرّرها التطبيق لك، ويُخفي النص لتختبر نفسك، ويذكّرك بموعد المراجعة.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.muted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _showAddSheet(context),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(context.tr('Add verses', 'إضافة آيات')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final i = items[index];
                        final due = store.isDue(i);
                        return Material(
                          color: p.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                                color: due ? scheme.primary : p.border,
                                width: due ? 1.5 : 1),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.go('/hifz/${i.id}'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          i.title(context.isArabic, context.n),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _status(context, store, i),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: due ? scheme.primary : p.muted,
                                            fontWeight:
                                                due ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          i.isStrong
                                              ? context.tr(
                                                  'Strong · revised ${i.revisions} times',
                                                  'راسخ · روجع ${context.n(i.revisions)} مرة')
                                              : context.tr(
                                                  'Revised ${i.revisions} times',
                                                  'روجع ${context.n(i.revisions)} مرة'),
                                          style: TextStyle(fontSize: 12, color: p.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (_) => _confirmDelete(context, i),
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(context.tr('Remove', 'حذف')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, HifzItem i) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove this range?', 'حذف هذا الجزء؟')),
        content: Text(i.title(context.isArabic, context.n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Remove', 'حذف')),
          ),
        ],
      ),
    );
    if (yes == true) await HifzStore.instance.remove(i.id);
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final item = await showModalBottomSheet<HifzItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddSheet(),
    );
    if (item != null && context.mounted) context.go('/hifz/${item.id}');
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  List<Surah>? _surahs;
  Surah? _surah;
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '5');
  String? _error;

  @override
  void initState() {
    super.initState();
    QuranRepository().getSurahs().then((list) {
      if (!mounted) return;
      setState(() {
        _surahs = list;
        _pick(list.first);
      });
    }).catchError((_) {
      if (mounted) setState(() => _error = 'load');
    });
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _pick(Surah s) {
    _surah = s;
    _from.text = '1';
    _to.text = '${s.ayahCount < 5 ? s.ayahCount : 5}';
    _error = null;
  }

  Future<void> _save() async {
    final s = _surah;
    final from = int.tryParse(_from.text.trim());
    final to = int.tryParse(_to.text.trim());
    if (s == null ||
        from == null ||
        to == null ||
        from < 1 ||
        to < from ||
        to > s.ayahCount) {
      setState(() => _error = 'range');
      return;
    }
    final item = await HifzStore.instance.add(
      surah: s.number,
      surahEn: s.englishName,
      surahAr: s.arabicName,
      from: from,
      to: to,
    );
    if (mounted) Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final list = _surahs;
    final s = _surah;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('What do you want to memorise?', 'ماذا تريد أن تحفظ؟'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (list == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: _error == 'load'
                      ? Text(context.tr(
                          "Couldn't load the surahs. Check your internet connection.",
                          'تعذّر تحميل السور. تحقق من اتصالك بالإنترنت.'))
                      : const CircularProgressIndicator(),
                ),
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: s?.number,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.tr('Surah', 'السورة')),
                items: [
                  for (final x in list)
                    DropdownMenuItem(
                      value: x.number,
                      child: Text(
                        '${context.n(x.number)}. ${x.name(context.isArabic)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _pick(list.firstWhere((x) => x.number == v)));
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _from,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: context.tr('From verse', 'من الآية')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _to,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: context.tr('To verse', 'إلى الآية')),
                    ),
                  ),
                ],
              ),
              if (s != null) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr('This surah has ${s.ayahCount} verses',
                      'عدد آيات السورة ${context.n(s.ayahCount)}'),
                  style: TextStyle(
                      fontSize: 12, color: context.palette.muted),
                ),
              ],
              if (_error == 'range') ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('Check the verse numbers.', 'تحقق من أرقام الآيات.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(context.tr('Start', 'ابدأ')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
