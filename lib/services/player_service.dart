import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'local_store.dart';
import 'settings_service.dart';

class PlayerService {
  PlayerService._();
  static final instance = PlayerService._();

  /// Máximo de canciones en la cola: colas de miles de temas hacen fallar el servicio de audio.
  static const int maxQueue = 300;

  final equalizer = AndroidEqualizer();
  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
  );

  /// Reproduce una lista desde [index]. [shuffle]: null = no cambia el modo.
  Future<void> playList(List<Track> tracks, int index, {bool? shuffle}) async {
    if (tracks.isEmpty) return;
    _userStarted = true;
    _lastRecorded = null;
    var list = tracks;
    var start = index.clamp(0, tracks.length - 1).toInt();
    if (tracks.length > maxQueue) {
      if (shuffle == true) {
        list = (List<Track>.from(tracks)..shuffle()).take(maxQueue).toList();
        start = 0;
      } else {
        final from = max(0, start - 50);
        final to = min(tracks.length, from + maxQueue);
        list = tracks.sublist(from, to);
        start = start - from;
      }
    }
    try {
      await player.setAudioSources(
        list.map((t) => t.toSource()).toList(),
        initialIndex: start,
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

  // ---------- Efectos, historial y sesión ----------
  /// Volumen general (modo Winamp). El fundido se aplica sobre este valor.
  double master = 1.0;
  void setMaster(double m) {
    master = m.clamp(0.0, 1.0).toDouble();
    player.setVolume(_lastVol * master);
  }

  int _errors = 0;
  bool _effectsStarted = false;
  bool _userStarted = false;
  double _lastVol = 1.0;
  bool _lastSkip = false;
  String? _lastRecorded;

  void startEffects() {
    if (_effectsStarted) return;
    _effectsStarted = true;
    final s = SettingsService.instance;

    // Fundido de entrada y salida
    player.positionStream.listen((pos) {
      var v = 1.0;
      final fade = s.fadeSeconds;
      if (fade > 0 && player.playing) {
        final f = fade * 1000;
        final p = pos.inMilliseconds;
        final dur = player.duration?.inMilliseconds ?? 0;
        if (p < f) v = p / f;
        if (dur > 0 && dur - p < f) v = min(v, (dur - p) / f);
        v = v.clamp(0.0, 1.0).toDouble();
      }
      if ((v - _lastVol).abs() > 0.02 || (v == 1.0 && _lastVol != 1.0)) {
        _lastVol = v;
        player.setVolume(v * master);
      }
    });

    // Saltar silencios
    void applySkip() {
      if (s.skipSilence != _lastSkip) {
        _lastSkip = s.skipSilence;
        player.setSkipSilenceEnabled(s.skipSilence).catchError((_) {});
      }
    }

    s.addListener(applySkip);
    applySkip();

    // Si una pista falla (archivo dañado o formato no soportado), salta a la siguiente
    // en vez de detener toda la reproducción.
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) async {
      debugPrint('Error de reproducción: $e');
      if (_errors >= 8) return;
      _errors++;
      try {
        if (player.hasNext) {
          await player.seekToNext();
          unawaited(player.play());
        }
      } catch (_) {}
    });
    player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.ready) _errors = 0;
    });

    // Historial y recordar la sesión
    player.currentIndexStream.listen((_) {
      _saveSession();
      _maybeRecord();
    });
    player.playingStream.listen((playing) {
      if (!playing) _saveSession();
      _maybeRecord();
    });
    Timer.periodic(const Duration(seconds: 15), (_) {
      if (player.playing) _saveSession();
    });
  }

  void _maybeRecord() {
    if (!player.playing) return;
    final i = player.currentIndex;
    final seq = player.sequence;
    if (i == null || i >= seq.length) return;
    final t = Track.fromSource(seq[i]);
    if (t == null || t.id == _lastRecorded) return;
    _lastRecorded = t.id;
    LocalStore.instance.recordPlay(t);
  }

  Future<void> _saveSession() async {
    try {
      final seq = player.sequence;
      if (seq.isEmpty) return;
      final ids = seq
          .map((s) => s.tag is MediaItem ? (s.tag as MediaItem).id : '')
          .toList();
      final p = await SharedPreferences.getInstance();
      await p.setStringList('last_ids', ids);
      await p.setInt('last_index', player.currentIndex ?? 0);
      await p.setInt('last_pos', player.position.inMilliseconds);
    } catch (_) {}
  }

  bool _restored = false;

  /// Deja lista (en pausa) la última cola, donde se quedó la reproducción.
  Future<void> restoreLast(List<Track> library) async {
    if (_restored) return;
    _restored = true;
    try {
      if (_userStarted || player.sequence.isNotEmpty) return;
      final p = await SharedPreferences.getInstance();
      final ids = p.getStringList('last_ids');
      if (ids == null || ids.isEmpty) return;
      final byId = {for (final t in library) t.id: t};
      final idx = p.getInt('last_index') ?? 0;
      final cur = idx >= 0 && idx < ids.length ? ids[idx] : null;
      final tracks = <Track>[
        for (final id in ids)
          if (byId[id] != null) byId[id]!
      ];
      if (tracks.isEmpty) return;
      var start = cur == null ? 0 : tracks.indexWhere((t) => t.id == cur);
      if (start < 0) start = 0;
      if (_userStarted) return;
      await player.setAudioSources(
        tracks.map((t) => t.toSource()).toList(),
        initialIndex: start,
        initialPosition: Duration(milliseconds: p.getInt('last_pos') ?? 0),
      );
      unawaited(_restoreEq());
    } catch (_) {}
  }

  Stream<({Duration pos, Duration dur})> get progress => Rx.combineLatest2(
        player.positionStream,
        player.durationStream,
        (p, d) => (pos: p, dur: d ?? Duration.zero),
      );
}
