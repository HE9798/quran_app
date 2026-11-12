import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quran/data/quran_repository.dart';
import '../quran/data/surah.dart';
import 'data/audio_repository.dart';
import 'data/reciter.dart';

/// The one audio player of the app. The reader, the Listening tab, the mini
/// player and the full player all use this, so they always agree.
///
/// A surah is played as a list of verses (one mp3 per verse). That is what
/// allows starting from a chosen verse and following the verse that is
/// being recited.
class QuranAudioController extends ChangeNotifier {
  QuranAudioController._();
  static final instance = QuranAudioController._();

  static const _reciterKey = 'reciter_v1';
  static const speeds = [0.75, 1.0, 1.25, 1.5];

  final _player = AudioPlayer();
  final _audio = AudioRepository();
  final _quran = QuranRepository();

  bool _ready = false;
  int _token = 0; // newest play request wins
  bool _completionHandled = false;

  // ------------------------------------------------------------- state

  Reciter reciter = Reciter.alafasy;
  List<Reciter> reciters = Reciter.fallbackList;
  bool recitersLoaded = false;

  /// The surah that is loaded (playing or paused). Null = nothing.
  Surah? surah;

  /// The verse being recited (1-based).
  int ayah = 1;

  bool playing = false;
  bool loading = false;
  bool repeatAyah = false;
  double speed = 1.0;

  /// Set when something failed. Screens show a message, then call [clearError].
  Object? error;

  bool get isActive => surah != null;
  bool isPlayingSurah(int number) => surah?.number == number && playing;

  // ------------------------------------------------------------- setup

  /// Call once at start (reads the saved reciter, listens to the player).
  Future<void> init() async {
    if (_ready) return;
    _ready = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_reciterKey);
      if (saved != null) {
        reciter = Reciter.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {}

    _player.currentIndexStream.listen((index) {
      if (index != null && surah != null && ayah != index + 1) {
        ayah = index + 1;
        notifyListeners();
      }
    });

    _player.playerStateStream.listen((state) {
      final nowLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      final changed = playing != state.playing || loading != nowLoading;
      playing = state.playing;
      loading = nowLoading;
      if (changed) notifyListeners();

      if (state.processingState == ProcessingState.completed) {
        _onFinished();
      }
    });

    // playback errors (no internet in the middle of a verse, ...)
    _player.playbackEventStream.listen((_) {}, onError: (Object e, _) {
      error = e;
      notifyListeners();
    });
  }

  /// Downloads the list of reciters (saved after the first time).
  Future<void> loadReciters() async {
    if (recitersLoaded) return;
    try {
      reciters = await _audio.getReciters();
      recitersLoaded = true;
      // the saved reciter may carry names from an older list: refresh them
      final match = reciters.where((r) => r.id == reciter.id);
      if (match.isNotEmpty) reciter = match.first;
    } catch (_) {
      reciters = Reciter.fallbackList;
    }
    notifyListeners();
  }

  // ----------------------------------------------------------- control

  /// Plays [target] from verse [startAyah] to the end, in the chosen voice.
  Future<void> playSurah(Surah target, {int startAyah = 1}) async {
    final token = ++_token;
    _completionHandled = false;
    error = null;
    surah = target;
    ayah = startAyah.clamp(1, target.ayahCount);
    loading = true;
    notifyListeners();

    try {
      final urls = await _audio.getSurahUrls(target.number, reciter.id);
      if (token != _token) return; // another request started meanwhile

      await _player.setAudioSources(
        [for (final url in urls) AudioSource.uri(Uri.parse(url))],
        initialIndex: (ayah - 1).clamp(0, urls.length - 1),
      );
      if (token != _token) return;

      await _player.setSpeed(speed);
      await _player.setLoopMode(repeatAyah ? LoopMode.one : LoopMode.off);
      unawaited(_player.play()); // completes only when playback stops
    } catch (e) {
      if (token != _token) return;
      error = e;
      loading = false;
      playing = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (surah == null) return;
    if (_player.playing) {
      await _player.pause();
    } else if (_player.processingState == ProcessingState.completed ||
        _player.processingState == ProcessingState.idle) {
      await playSurah(surah!, startAyah: 1);
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> seekToAyah(int number) async {
    if (surah == null) return;
    await _player.seek(Duration.zero, index: (number - 1).clamp(0, surah!.ayahCount - 1));
  }

  Future<void> nextAyah() async {
    if (surah != null && ayah < surah!.ayahCount) await seekToAyah(ayah + 1);
  }

  Future<void> previousAyah() async {
    if (surah != null && ayah > 1) await seekToAyah(ayah - 1);
  }

  Future<void> nextSurah() => _goToSurah((surah?.number ?? 0) + 1);

  Future<void> previousSurah() => _goToSurah((surah?.number ?? 2) - 1);

  Future<void> _goToSurah(int number) async {
    if (number < 1 || number > 114) return;
    try {
      final all = await _quran.getSurahs();
      final target = all.firstWhere((s) => s.number == number);
      await playSurah(target);
    } catch (e) {
      error = e;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _token++;
    await _player.stop();
    surah = null;
    playing = false;
    loading = false;
    notifyListeners();
  }

  Future<void> setReciter(Reciter value) async {
    if (value == reciter) return;
    reciter = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_reciterKey, jsonEncode(value.toJson()));
    } catch (_) {}
    // already listening: continue from the same verse with the new voice
    final current = surah;
    if (current != null) await playSurah(current, startAyah: ayah);
  }

  Future<void> cycleSpeed() async {
    final next = speeds[(speeds.indexOf(speed) + 1) % speeds.length];
    speed = next;
    notifyListeners();
    await _player.setSpeed(next);
  }

  Future<void> toggleRepeatAyah() async {
    repeatAyah = !repeatAyah;
    notifyListeners();
    await _player.setLoopMode(repeatAyah ? LoopMode.one : LoopMode.off);
  }

  void reportError(Object e) {
    error = e;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  /// A surah ended: go on with the next one (stops after surah 114).
  void _onFinished() {
    if (_completionHandled) return;
    _completionHandled = true;
    final current = surah;
    if (current != null && current.number < 114) {
      _goToSurah(current.number + 1);
    } else {
      playing = false;
      notifyListeners();
    }
  }
}
