import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import '../models/track.dart';

/// Un deck del DJ: reproductor independiente con tempo, cue y hot cues.
class DjDeck extends ChangeNotifier {
  final String name;
  final ap.AudioPlayer _p = ap.AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  Track? track;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double rate = 1.0; // tempo: 0.5 a 1.5
  double fader = 1.0; // volumen del canal
  Duration? cuePoint;
  final List<Duration?> hotCues = [null, null, null];
  double bpm = 0; // 0 = desconocido (se marca con TAP)
  final List<int> _taps = [];

  DjDeck(this.name) {
    _init();
  }

  double get effectiveBpm => bpm * rate;

  Future<void> _init() async {
    try {
      await _p.setReleaseMode(ap.ReleaseMode.stop);
      // Que dos decks suenen a la vez sin pelearse por el foco de audio.
      await _p.setAudioContext(ap.AudioContext(
        android: ap.AudioContextAndroid(audioFocus: ap.AndroidAudioFocus.none),
      ));
    } catch (_) {}
    _subs.add(_p.onPositionChanged.listen((d) {
      position = d;
      notifyListeners();
    }));
    _subs.add(_p.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    }));
    _subs.add(_p.onPlayerStateChanged.listen((s) {
      playing = s == ap.PlayerState.playing;
      notifyListeners();
    }));
    _subs.add(_p.onPlayerComplete.listen((_) {
      playing = false;
      position = Duration.zero;
      notifyListeners();
    }));
  }

  Future<void> load(Track t) async {
    try {
      await _p.stop();
    } catch (_) {}
    track = t;
    position = Duration.zero;
    duration = Duration(milliseconds: t.durationMs);
    cuePoint = null;
    for (var i = 0; i < hotCues.length; i++) {
      hotCues[i] = null;
    }
    bpm = 0;
    playing = false;
    notifyListeners();
    final src = (t.local && t.path != null)
        ? ap.DeviceFileSource(t.path!)
        : ap.UrlSource(t.uri);
    await _p.setSource(src);
    await _p.setPlaybackRate(rate);
  }

  Future<void> toggle() async {
    if (track == null) return;
    if (playing) {
      await _p.pause();
    } else {
      if (position == Duration.zero) await _p.seek(Duration.zero);
      await _p.resume();
    }
  }

  Future<void> seek(Duration d) => _p.seek(d);

  Future<void> seekFrac(double f) => _p
      .seek(Duration(milliseconds: (duration.inMilliseconds * f).round()));

  Future<void> setRate(double r) async {
    rate = r.clamp(0.5, 1.5).toDouble();
    notifyListeners();
    await _p.setPlaybackRate(rate);
  }

  Future<void> setVolume(double v) =>
      _p.setVolume(v.clamp(0.0, 1.0).toDouble());

  void setFader(double v) {
    fader = v;
    notifyListeners();
  }

  /// CUE clásico: sonando = vuelve al punto cue y pausa; en pausa = fija el cue aquí.
  Future<void> cue() async {
    if (track == null) return;
    if (playing) {
      await _p.pause();
      await _p.seek(cuePoint ?? Duration.zero);
    } else {
      cuePoint = position;
      notifyListeners();
    }
  }

  Future<void> hotCue(int i) async {
    if (track == null) return;
    final c = hotCues[i];
    if (c == null) {
      hotCues[i] = position;
      notifyListeners();
    } else {
      await _p.seek(c);
    }
  }

  void clearHotCue(int i) {
    hotCues[i] = null;
    notifyListeners();
  }

  void tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_taps.isNotEmpty && now - _taps.last > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length >= 3) {
      var sum = 0;
      for (var i = 1; i < _taps.length; i++) {
        sum += _taps[i] - _taps[i - 1];
      }
      final avg = sum / (_taps.length - 1);
      bpm = (60000 / avg).clamp(60.0, 200.0).toDouble();
    }
    notifyListeners();
  }

  void setBpm(double v) {
    bpm = v < 0 ? 0 : v;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p.dispose();
    super.dispose();
  }
}
