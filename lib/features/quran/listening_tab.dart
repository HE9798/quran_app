import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/error_view.dart';
import '../audio/quran_audio_controller.dart';
import '../audio/reciter_sheet.dart';
import 'data/quran_repository.dart';
import 'data/surah.dart';

/// "Listening" tab: pick a reciter, then play any surah.
class ListeningTab extends StatefulWidget {
  const ListeningTab({super.key});

  @override
  State<ListeningTab> createState() => _ListeningTabState();
}

class _ListeningTabState extends State<ListeningTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = QuranRepository();
  final _audio = QuranAudioController.instance;
  final _search = TextEditingController();

  late Future<List<Surah>> _future = _repo.getSurahs();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _audio.loadReciters();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Surah> _apply(List<Surah> all) {
    final q = Surah.normalize(_query);
    final number = int.tryParse(_query.trim());
    if (q.isEmpty) return all;
    return all
        .where((s) => (number != null && s.number == number) || s.searchKey.contains(q))
        .toList();
  }

  void _onTap(Surah s) {
    if (_audio.surah?.number == s.number) {
      _audio.togglePlay();
    } else {
      _audio.playSurah(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      children: [
        // reciter card
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ListenableBuilder(
            listenable: _audio,
            builder: (context, _) {
              final r = _audio.reciter;
              return Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: p.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showReciterSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          child: Text(r.initials,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reciter',
                                  style: TextStyle(fontSize: 12, color: p.muted)),
                              Text(
                                r.englishName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        Text('Change',
                            style: TextStyle(
                                color: primary, fontWeight: FontWeight.w700)),
                        Icon(Icons.keyboard_arrow_down_rounded, color: primary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search surah name or number',
              hintStyle: TextStyle(color: p.muted),
              prefixIcon: Icon(Icons.search_rounded, color: p.muted),
              filled: true,
              fillColor: p.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: border(p.border),
              enabledBorder: border(p.border),
              focusedBorder: border(primary, 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Surah>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || !snap.hasData) {
                return ErrorView(
                  onRetry: () => setState(() => _future = _repo.getSurahs()),
                );
              }
              final list = _apply(snap.data!);
              if (list.isEmpty) {
                return Center(
                  child: Text('No surah found', style: TextStyle(color: p.muted)),
                );
              }
              return ListenableBuilder(
                listenable: _audio,
                builder: (context, _) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _ListenTile(
                    surah: list[i],
                    audio: _audio,
                    onTap: () => _onTap(list[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ListenTile extends StatelessWidget {
  const _ListenTile({
    required this.surah,
    required this.audio,
    required this.onTap,
  });

  final Surah surah;
  final QuranAudioController audio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final current = audio.surah?.number == surah.number;
    final playing = current && audio.playing;
    final busy = current && audio.loading && !audio.playing;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: current ? p.primarySoft : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  onPressed: onTap,
                  tooltip: playing ? 'Pause' : 'Play',
                  style: IconButton.styleFrom(
                    backgroundColor: current ? scheme.primary : p.surfaceAlt,
                    foregroundColor:
                        current ? scheme.onPrimary : scheme.onSurface,
                  ),
                  icon: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Icon(playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${surah.number}. ${surah.englishName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current && audio.isActive
                          ? 'Verse ${audio.ayah} of ${surah.ayahCount}'
                          : '${surah.ayahCount} verses · ${surah.revelationType}',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              ),
              if (current)
                IconButton(
                  tooltip: 'Open player',
                  icon: const Icon(Icons.open_in_full_rounded, size: 20),
                  onPressed: () => context.go('/quran/player'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
