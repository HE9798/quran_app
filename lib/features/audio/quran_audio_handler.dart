import 'dart:ui' show Brightness, Color, PlatformDispatcher;

import 'package:audio_service/audio_service.dart';

import '../../core/settings/app_settings.dart';
import 'quran_audio_controller.dart';

/// Starts the media notification. Call once, after the settings are loaded.
Future<void> initQuranMediaNotification() async {
  final s = AppSettings.instance;
  final dark = s.followDevice
      ? PlatformDispatcher.instance.platformBrightness == Brightness.dark
      : s.darkMode;

  await AudioService.init(
    builder: () => QuranAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'quran_audio_playback',
      androidNotificationChannelName: 'Quran audio',
      // paused = the notification can be swiped away (which stops playback)
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      // same colours as the prayer notification: cream (light) / green (dark)
      notificationColor:
          dark ? const Color(0xFF12685E) : const Color(0xFFF7EBD4),
    ),
  );
}

/// Shows a SURAH as one "track" (like a song in a music app): its name, the
/// reciter and play / pause. Previous and next go to the previous and next
/// surah, not to another verse. Swiping the notification away stops playback.
class QuranAudioHandler extends BaseAudioHandler {
  QuranAudioHandler() {
    _player.addListener(_sync);
    AppSettings.instance.addListener(_sync);
    _sync();
  }

  final _player = QuranAudioController.instance;
  String? _shownKey;

  void _sync() {
    final surah = _player.surah;
    if (surah == null) {
      _shownKey = null;
      mediaItem.add(null);
      playbackState.add(PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      return;
    }

    final arabic = AppSettings.instance.isArabic;
    final key = '${surah.number}|${_player.reciter.id}|$arabic';
    if (key != _shownKey) {
      _shownKey = key;
      mediaItem.add(MediaItem(
        id: key,
        title: arabic ? 'سورة ${surah.arabicName}' : surah.englishName,
        artist: arabic ? _player.reciter.name : _player.reciter.englishName,
        album: arabic ? 'ورد اليوم' : 'Werd of the Day',
      ));
    }

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _player.loading
          ? AudioProcessingState.loading
          : AudioProcessingState.ready,
      playing: _player.playing,
      speed: _player.speed,
    ));
  }

  @override
  Future<void> play() async {
    if (!_player.playing) await _player.togglePlay();
  }

  @override
  Future<void> pause() async {
    if (_player.playing) await _player.togglePlay();
  }

  @override
  Future<void> skipToNext() => _player.nextSurah();

  @override
  Future<void> skipToPrevious() => _player.previousSurah();

  /// Also called when the notification is swiped away.
  @override
  Future<void> stop() => _player.stop();
}
