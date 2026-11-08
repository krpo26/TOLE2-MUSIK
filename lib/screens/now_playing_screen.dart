import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';
import '../services/local_store.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../widgets/wave_seek_bar.dart';
import 'lyrics_screen.dart';
import '../widgets/artwork.dart';
import 'equalizer_screen.dart';
import 'queue_screen.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  Future<void> _sleepDialog(BuildContext context) async {
    final mins = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Temporizador de apagado'),
        children: [
          for (final m in [15, 30, 45, 60, 90])
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, m), child: Text('$m minutos')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('Desactivar')),
        ],
      ),
    );
    if (mins == null) return;
    PlayerService.instance
        .setSleep(mins == 0 ? null : Duration(minutes: mins));
  }

  Future<void> _speedDialog(BuildContext context) async {
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Velocidad'),
        children: [
          for (final s in [0.75, 1.0, 1.25, 1.5, 2.0])
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s), child: Text('${s}x')),
        ],
      ),
    );
    if (v != null) PlayerService.instance.player.setSpeed(v);
  }

  @override
  Widget build(BuildContext context) {
    final svc = PlayerService.instance;
    final p = svc.player;
    final cs = Theme.of(context).colorScheme;
    final dim = cs.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproduciendo'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Cola',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QueueScreen())),
          ),
        ],
      ),
      body: StreamBuilder<SequenceState?>(
        stream: p.sequenceStateStream,
        builder: (_, snap) {
          final item = snap.data?.currentSource?.tag;
          if (item is! MediaItem) {
            return const Center(child: Text('Nada en reproducción'));
          }
          final tr = Track.fromSource(snap.data?.currentSource);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Column(children: [
              Expanded(
                child: LayoutBuilder(builder: (_, c) {
                  final s = min(c.maxWidth, c.maxHeight).clamp(120.0, 320.0).toDouble();
                  return Center(
                    child: Artwork(
                      local: item.extras?['local'] == true,
                      localId: (item.extras?['localId'] as num?)?.toInt(),
                      size: s,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(item.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: dim)),
                      ]),
                ),
                ListenableBuilder(
                  listenable: LocalStore.instance,
                  builder: (_, __) {
                    final fav = tr != null && LocalStore.instance.isFav(tr.id);
                    return IconButton(
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                          color: fav ? Colors.redAccent : null),
                      onPressed:
                          tr == null ? null : () => LocalStore.instance.toggleFav(tr),
                    );
                  },
                ),
              ]),
              StreamBuilder(
                stream: svc.progress,
                builder: (_, s) {
                  final pos = s.data?.pos ?? Duration.zero;
                  final dur = s.data?.dur ?? Duration.zero;
                  final max = dur.inMilliseconds.toDouble();
                  final frac = max > 0
                      ? (pos.inMilliseconds / max).clamp(0.0, 1.0).toDouble()
                      : 0.0;
                  return Column(children: [
                    if (SettingsService.instance.waveformSeek)
                      WaveSeekBar(
                        progress: frac,
                        seed: item.id,
                        onSeek: (f) =>
                            p.seek(Duration(milliseconds: (f * max).round())),
                      )
                    else
                      Slider(
                        value: pos.inMilliseconds
                            .toDouble()
                            .clamp(0, max > 0 ? max : 1),
                        max: max > 0 ? max : 1,
                        onChanged: (v) =>
                            p.seek(Duration(milliseconds: v.round())),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtDuration(pos)),
                            Text(fmtDuration(dur)),
                          ]),
                    ),
                  ]);
                },
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                StreamBuilder<bool>(
                  stream: p.shuffleModeEnabledStream,
                  builder: (_, s) => IconButton(
                    icon: Icon(Icons.shuffle,
                        color: (s.data ?? false) ? cs.primary : dim),
                    onPressed: () async {
                      final on = !(s.data ?? false);
                      if (on) await p.shuffle();
                      await p.setShuffleModeEnabled(on);
                    },
                  ),
                ),
                IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: p.seekToPrevious),
                StreamBuilder<PlayerState>(
                  stream: p.playerStateStream,
                  builder: (_, s) {
                    final playing = s.data?.playing ?? false;
                    return IconButton.filled(
                      iconSize: 44,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: playing ? p.pause : p.play,
                    );
                  },
                ),
                IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next),
                    onPressed: p.seekToNext),
                StreamBuilder<LoopMode>(
                  stream: p.loopModeStream,
                  builder: (_, s) {
                    final m = s.data ?? LoopMode.off;
                    return IconButton(
                      icon: Icon(
                          m == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                          color: m == LoopMode.off ? dim : cs.primary),
                      onPressed: () =>
                          p.setLoopMode(LoopMode.values[(m.index + 1) % 3]),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(
                  tooltip: 'Letra',
                  icon: const Icon(Icons.lyrics),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LyricsScreen())),
                ),
                IconButton(
                  tooltip: 'Ecualizador',
                  icon: const Icon(Icons.equalizer),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EqualizerScreen())),
                ),
                ValueListenableBuilder<DateTime?>(
                  valueListenable: svc.sleepEnd,
                  builder: (_, end, __) => IconButton(
                    tooltip: 'Temporizador',
                    icon: Icon(Icons.bedtime,
                        color: end != null ? cs.primary : null),
                    onPressed: () => _sleepDialog(context),
                  ),
                ),
                StreamBuilder<double>(
                  stream: p.speedStream,
                  builder: (_, s) => TextButton(
                    onPressed: () => _speedDialog(context),
                    child: Text('${(s.data ?? 1.0)}x'),
                  ),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
