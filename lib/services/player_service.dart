import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class PlayerService {
  PlayerService._();
  static final instance = PlayerService._();

  final equalizer = AndroidEqualizer();
  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
  );

  /// Reproduce una lista desde [index]. [shuffle]: null = no cambia el modo.
  Future<void> playList(List<Track> tracks, int index, {bool? shuffle}) async {
    if (tracks.isEmpty) return;
    try {
      await player.setAudioSources(
        tracks.map((t) => t.toSource()).toList(),
        initialIndex: index,
      );
      if (shuffle != null) {
        await player.setShuffleModeEnabled(shuffle);
        if (shuffle) await player.shuffle();
      }
      unawaited(player.play());
      unawaited(_restoreEq());
    } catch (e) {
      debugPrint('Error al reproducir: $e');
    }
  }

  bool _inQueue(String id) => player.sequence
      .any((s) => s.tag is MediaItem && (s.tag as MediaItem).id == id);

  /// false si la canción ya estaba en la cola.
  Future<bool> playNext(Track t) async {
    if (player.sequence.isEmpty) {
      await playList([t], 0);
      return true;
    }
    if (_inQueue(t.id)) return false;
    final i = (player.currentIndex ?? -1) + 1;
    await player.insertAudioSource(i, t.toSource());
    return true;
  }

  Future<bool> addToQueue(Track t) async {
    if (player.sequence.isEmpty) {
      await playList([t], 0);
      return true;
    }
    if (_inQueue(t.id)) return false;
    await player.addAudioSource(t.toSource());
    return true;
  }

  // ---------- Temporizador de apagado ----------
  Timer? _sleepTimer;
  final sleepEnd = ValueNotifier<DateTime?>(null);

  void setSleep(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepEnd.value = null;
    if (d == null) return;
    sleepEnd.value = DateTime.now().add(d);
    _sleepTimer = Timer(d, () {
      player.pause();
      sleepEnd.value = null;
    });
  }

  // ---------- Ecualizador (se recuerda entre sesiones) ----------
  bool _eqRestored = false;
  Future<void> _restoreEq() async {
    if (_eqRestored) return;
    _eqRestored = true;
    try {
      final p = await SharedPreferences.getInstance();
      final enabled = p.getBool('eq_enabled') ?? false;
      final gains = p.getStringList('eq_gains');
      final params =
          await equalizer.parameters.timeout(const Duration(seconds: 10));
      if (gains != null && gains.length == params.bands.length) {
        for (var i = 0; i < gains.length; i++) {
          await params.bands[i].setGain(double.tryParse(gains[i]) ?? 0);
        }
      }
      await equalizer.setEnabled(enabled);
    } catch (_) {}
  }

  Stream<({Duration pos, Duration dur})> get progress => Rx.combineLatest2(
        player.positionStream,
        player.durationStream,
        (p, d) => (pos: p, dur: d ?? Duration.zero),
      );
}
