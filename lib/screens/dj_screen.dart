import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/dj_deck.dart';
import '../services/local_library.dart';
import '../services/player_service.dart';
import '../widgets/artwork.dart';
import '../widgets/wave_seek_bar.dart';

class DjScreen extends StatefulWidget {
  const DjScreen({super.key});
  @override
  State<DjScreen> createState() => _DjScreenState();
}

class _DjScreenState extends State<DjScreen> {
  final a = DjDeck('A');
  final b = DjDeck('B');
  double _cf = 0; // crossfader: -1 (A) a 1 (B)
  Timer? _mix;

  @override
  void initState() {
    super.initState();
    PlayerService.instance.player.pause(); // el reproductor normal se pausa
    _apply();
  }

  @override
  void dispose() {
    _mix?.cancel();
    a.dispose();
    b.dispose();
    super.dispose();
  }

  void _apply() {
    final x = (_cf + 1) / 2 * (pi / 2); // curva de potencia constante
    a.setVolume(a.fader * cos(x));
    b.setVolume(b.fader * sin(x));
  }

  Future<void> _loadInto(DjDeck d) async {
    final t = await showModalBottomSheet<Track>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TrackPicker(),
    );
    if (t != null) {
      await d.load(t);
      _apply();
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _sync(DjDeck from, DjDeck to) {
    if (from.bpm <= 0 || to.bpm <= 0) {
      _snack('Marca el BPM de ambas pistas con TAP (3 toques o más).');
      return;
    }
    to.setRate(from.effectiveBpm / to.bpm);
  }

  void _autoMix(bool toB) {
    final target = toB ? b : a;
    final other = toB ? a : b;
    if (target.track == null) {
      _snack('Carga una pista en el deck de destino.');
      return;
    }
    if (!target.playing) target.toggle();
    _mix?.cancel();
    final goal = toB ? 1.0 : -1.0;
    const stepMs = 50;
    const totalMs = 8000;
    final step = (goal - _cf).abs() / (totalMs / stepMs);
    _mix = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      final next = _cf + (goal > _cf ? step : -step);
      final done = (goal - next).abs() < step * 1.01;
      setState(() => _cf = done ? goal : next);
      _apply();
      if (done) {
        t.cancel();
        if (other.playing) other.toggle();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('DJ virtual')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          _DeckCard(
            deck: a,
            color: Colors.cyanAccent,
            onLoad: () => _loadInto(a),
            onFader: (v) {
              a.setFader(v);
              _apply();
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Row(children: [
                  const Text('A', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      min: -1,
                      max: 1,
                      value: _cf,
                      onChanged: (v) {
                        _mix?.cancel();
                        setState(() => _cf = v);
                        _apply();
                      },
                    ),
                  ),
                  const Text('B', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.align_horizontal_center),
                    tooltip: 'Centrar',
                    onPressed: () {
                      _mix?.cancel();
                      setState(() => _cf = 0);
                      _apply();
                    },
                  ),
                ]),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  OutlinedButton(
                      onPressed: () => _sync(a, b), child: const Text('SYNC B→A')),
                  OutlinedButton(
                      onPressed: () => _sync(b, a), child: const Text('SYNC A→B')),
                  FilledButton.tonal(
                      onPressed: () => _autoMix(true),
                      child: const Text('AUTO MIX →B')),
                  FilledButton.tonal(
                      onPressed: () => _autoMix(false),
                      child: const Text('AUTO MIX ←A')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          _DeckCard(
            deck: b,
            color: Colors.pinkAccent,
            onLoad: () => _loadInto(b),
            onFader: (v) {
              b.setFader(v);
              _apply();
            },
          ),
          const SizedBox(height: 24),
        ]),
      );
}

class _DeckCard extends StatelessWidget {
  final DjDeck deck;
  final Color color;
  final VoidCallback onLoad;
  final ValueChanged<double> onFader;
  const _DeckCard(
      {required this.deck,
      required this.color,
      required this.onLoad,
      required this.onFader});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: deck,
        builder: (_, __) {
          final t = deck.track;
          final frac = deck.duration.inMilliseconds > 0
              ? (deck.position.inMilliseconds / deck.duration.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble()
              : 0.0;
          final pct = (deck.rate - 1) * 100;
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(6)),
                    child: Text('DECK ${deck.name}',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t?.title ?? 'Sin pista — toca "Cargar"',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                      '${fmtDuration(deck.position)} / ${fmtDuration(deck.duration)}',
                      style: const TextStyle(fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _Platter(playing: deck.playing, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: t == null
                        ? const SizedBox(height: 56)
                        : WaveSeekBar(
                            progress: frac,
                            seed: t.id,
                            onSeek: deck.seekFrac,
                          ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Cargar'),
                    onPressed: onLoad,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: deck.cue, child: const Text('CUE')),
                  const Spacer(),
                  IconButton.filled(
                    iconSize: 32,
                    style: IconButton.styleFrom(backgroundColor: color),
                    icon: Icon(deck.playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.black),
                    onPressed: deck.toggle,
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => deck.hotCue(i),
                          onLongPress: () => deck.clearHotCue(i),
                          child: Container(
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: deck.hotCues[i] != null
                                  ? color.withAlpha(70)
                                  : null,
                              border: Border.all(color: color),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(deck.hotCues[i] != null
                                ? 'HOT ${i + 1} · ${fmtDuration(deck.hotCues[i]!)}'
                                : 'HOT ${i + 1}'),
                          ),
                        ),
                      ),
                    ),
                ]),
                const Text('Toca un HOT vacío para fijarlo; mantén presionado para borrarlo.',
                    style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Row(children: [
                  const SizedBox(width: 44, child: Text('TEMPO', style: TextStyle(fontSize: 11))),
                  Expanded(
                    child: Slider(
                      min: 0.5,
                      max: 1.5,
                      value: deck.rate,
                      onChanged: deck.setRate,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt, size: 20),
                    tooltip: 'Tempo 0%',
                    onPressed: () => deck.setRate(1.0),
                  ),
                ]),
                Row(children: [
                  const SizedBox(width: 44, child: Text('VOL', style: TextStyle(fontSize: 11))),
                  Expanded(
                    child: Slider(value: deck.fader, onChanged: onFader),
                  ),
                ]),
                Row(children: [
                  FilledButton.tonal(onPressed: deck.tap, child: const Text('TAP BPM')),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => deck.setBpm(deck.bpm - 0.5),
                  ),
                  Text(deck.bpm > 0 ? deck.bpm.toStringAsFixed(1) : '--',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => deck.setBpm(deck.bpm + 0.5),
                  ),
                  const Spacer(),
                  if (deck.bpm > 0)
                    Text('${deck.effectiveBpm.toStringAsFixed(1)} BPM',
                        style: const TextStyle(fontSize: 12)),
                ]),
              ]),
            ),
          );
        },
      );
}

/// Plato que gira mientras suena el deck.
class _Platter extends StatefulWidget {
  final bool playing;
  final Color color;
  const _Platter({required this.playing, required this.color});
  @override
  State<_Platter> createState() => _PlatterState();
}

class _PlatterState extends State<_Platter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _Platter old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _c,
        child: Icon(Icons.album, size: 60, color: widget.color),
      );
}

class _TrackPicker extends StatefulWidget {
  const _TrackPicker();
  @override
  State<_TrackPicker> createState() => _TrackPickerState();
}

class _TrackPickerState extends State<_TrackPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = LocalLibrary.instance.tracks
        .where((t) =>
            t.path != null &&
            (q.isEmpty ||
                t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q)))
        .take(300)
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            autofocus: false,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar pista para el deck',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Sin resultados'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    return ListTile(
                      leading: Artwork(local: t.local, localId: t.localId),
                      title: Text(t.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artist,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(context, t),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
