import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_view.dart';
import '../audio/quran_audio_controller.dart';
import '../audio/reciter_sheet.dart';
import 'data/quran_repository.dart';
import 'data/surah.dart';

enum _Filter { all, meccan, medinan }

/// Quran tab: reciter, then all 114 surahs with search and a Meccan / Medinan filter.
class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = QuranRepository();
  final _searchController = TextEditingController();

  late Future<List<Surah>> _future = _repo.getSurahs();
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _future = _repo.getSurahs());

  List<Surah> _apply(List<Surah> all) {
    final q = Surah.normalize(_query);
    final number = int.tryParse(_query.trim());
    return all.where((s) {
      if (_filter == _Filter.meccan && !s.isMeccan) return false;
      if (_filter == _Filter.medinan && s.isMeccan) return false;
      if (q.isEmpty) return true;
      if (number != null && s.number == number) return true;
      return s.searchKey.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quran',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '114 surahs',
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
          ),
        ),

        // reciter (above the search bar)
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: ReciterCard(),
        ),

        // search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search surah name or number',
              hintStyle: TextStyle(color: p.muted),
              prefixIcon: Icon(Icons.search_rounded, color: p.muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: p.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: border(p.border),
              enabledBorder: border(p.border),
              focusedBorder: border(primary, 1.5),
            ),
          ),
        ),

        // filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == _Filter.all,
                onTap: () => setState(() => _filter = _Filter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Meccan',
                selected: _filter == _Filter.meccan,
                onTap: () => setState(() => _filter = _Filter.meccan),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Medinan',
                selected: _filter == _Filter.medinan,
                onTap: () => setState(() => _filter = _Filter.medinan),
              ),
            ],
          ),
        ),

        // list
        Expanded(
          child: FutureBuilder<List<Surah>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return ErrorView(
                  title: "Couldn't load the surahs",
                  onRetry: _retry,
                );
              }

              final items = _apply(snapshot.data!);
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No surah found',
                    style: TextStyle(color: p.muted, fontSize: 15),
                  ),
                );
              }

              return ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 12,
                  color: p.border,
                ),
                itemBuilder: (context, index) {
                  final surah = items[index];
                  return _SurahTile(
                    surah: surah,
                    onTap: () => context.go('/quran/surah/${surah.number}'),
                    onPlay: () {
                      final audio = QuranAudioController.instance;
                      if (audio.surah?.number == surah.number) {
                        audio.togglePlay();
                      } else {
                        audio.playSurah(surah);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ filter chip

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final shape = StadiumBorder(
      side: BorderSide(color: selected ? scheme.primary : p.border),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : p.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 40,
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- surah row

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.onTap,
    required this.onPlay,
  });

  final Surah surah;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _NumberBadge(number: surah.number),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        surah.englishName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        surah.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      surah.arabicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.arabic(
                        size: 22,
                        height: 1.4,
                        color: primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ListenableBuilder(
                  listenable: QuranAudioController.instance,
                  builder: (context, _) {
                    final audio = QuranAudioController.instance;
                    final current = audio.surah?.number == surah.number;
                    final playing = current && audio.playing;
                    final busy = current && audio.loading && !audio.playing;
                    final scheme = Theme.of(context).colorScheme;
                    return IconButton(
                      tooltip: playing ? 'Pause' : 'Listen',
                      onPressed: onPlay,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            current ? scheme.primary : p.surfaceAlt,
                        foregroundColor:
                            current ? scheme.onPrimary : scheme.onSurface,
                        fixedSize: const Size(40, 40),
                      ),
                      icon: busy
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Eight-point star with the surah number inside.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: p.primarySoft,
          shape: const StarBorder(
            points: 8,
            innerRadiusRatio: 0.82,
            pointRounding: 0.3,
            valleyRounding: 0.1,
          ),
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.onPrimarySoft,
            ),
          ),
        ),
      ),
    );
  }
}
