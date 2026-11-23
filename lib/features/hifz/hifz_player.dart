import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/data/activity_reciters.dart';
import '../audio/data/audio_repository.dart';
import '../audio/quran_audio_controller.dart';

/// Plays one range of verses again and again for memorising. It has its own
/// player (so the normal Quran player is not touched) and uses the reciter
/// chosen for the Hifz (it follows the Quran player's until one is picked).
///
/// [rounds] = how many times the whole range is played.
/// [verseRepeats] = how many times each verse is played before the next one.
class HifzPlayer extends ChangeNotifier {
  HifzPlayer() {
    _player.currentIndexStream.listen((index) {
      if (index == null) return;
      final a = _from + index ~/ _verseRepeats;
      if (a != ayah) {
        ayah = a;
        notifyListeners();
      }
    });
    _player.playerStateStream.listen((state) {
      final nowLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (playing != state.playing || loading != nowLoading) {
        playing = state.playing;
        loading = nowLoading;
        notifyListeners();
      }
      if (state.processingState == ProcessingState.completed) _onCompleted();
    });
  }

  final _player = AudioPlayer();
  final _audio = AudioRepository();

  int _token = 0;
  int _from = 1;
  int _to = 1;
  int _surah = 1;
  int _verseRepeats = 1;
  bool _handled = false;

  bool playing = false;
  bool loading = false;
  bool finished = false;
  bool started = false;

  /// The verse being played now.
  int ayah = 1;

  /// Current round (1-based) and the total.
  int round = 1;
  int rounds = 1;

  Object? error;

  Future<void> start({
    required int surah,
    required int from,
    required int to,
    required int rounds,
    required int verseRepeats,
  }) async {
    final token = ++_token;
    _surah = surah;
    _from = from;
    _to = to;
    _verseRepeats = verseRepeats;
    this.rounds = rounds;
    round = 1;
    ayah = from;
    finished = false;
    started = true;
    error = null;
    loading = true;
    _handled = false;
    notifyListeners();

    try {
      // only one thing plays at a time
      final global = QuranAudioController.instance;
      if (global.playing) await global.togglePlay();

      await ActivityReciters.instance.load();
      final urls = await _audio.getSurahUrls(surah, ActivityReciters.instance.hifz.id);
      if (token != _token) return;
      final slice = urls.sublist(from - 1, to.clamp(from, urls.length));
      final sources = [
        for (final u in slice)
          for (var i = 0; i < verseRepeats; i++) AudioSource.uri(Uri.parse(u)),
      ];
      await _player.setAudioSources(sources);
      if (token != _token) return;
      await _player.setLoopMode(LoopMode.off);
      unawaited(_player.play());
    } catch (e) {
      if (token != _token) return;
      error = e;
      loading = false;
      playing = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (!started || finished) {
      await start(
        surah: _surah,
        from: _from,
        to: _to,
        rounds: rounds,
        verseRepeats: _verseRepeats,
      );
    } else if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> _onCompleted() async {
    if (_handled) return;
    _handled = true;
    if (round < rounds) {
      round += 1;
      notifyListeners();
      await _player.seek(Duration.zero, index: 0);
      _handled = false;
      unawaited(_player.play());
    } else {
      finished = true;
      playing = false;
      await _player.pause();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _token++;
    started = false;
    finished = false;
    playing = false;
    loading = false;
    await _player.stop();
    notifyListeners();
  }

  void clearError() {
    error = null;
  }

  @override
  void dispose() {
    _token++;
    _player.dispose();
    super.dispose();
  }
}
