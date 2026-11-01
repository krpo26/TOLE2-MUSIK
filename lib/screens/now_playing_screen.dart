import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/player_service.dart';
import '../widgets/artwork.dart';

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final svc = PlayerService.instance;
    final p = svc.player;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Reproduciendo'),
          backgroundColor: Colors.transparent),
      body: StreamBuilder<SequenceState?>(
        stream: p.sequenceStateStream,
        builder: (_, snap) {
          final item = snap.data?.currentSource?.tag;
          if (item is! MediaItem) {
            return const Center(child: Text('Nada en reproducción'));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Artwork(
                  local: item.extras?['local'] == true,
                  localId: item.extras?['localId'] as int?,
                  size: 280),
              const SizedBox(height: 32),
              Text(item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(item.artist ?? '',
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              StreamBuilder(
                stream: svc.progress,
                builder: (_, s) {
                  final pos = s.data?.pos ?? Duration.zero;
                  final dur = s.data?.dur ?? Duration.zero;
                  final max = dur.inMilliseconds.toDouble();
                  return Column(children: [
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
                          children: [Text(_fmt(pos)), Text(_fmt(dur))]),
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                StreamBuilder<bool>(
                  stream: p.shuffleModeEnabledStream,
                  builder: (_, s) => IconButton(
                    icon: Icon(Icons.shuffle,
                        color: (s.data ?? false)
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white54),
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
                          color: m == LoopMode.off
                              ? Colors.white54
                              : Theme.of(context).colorScheme.primary),
                      onPressed: () =>
                          p.setLoopMode(LoopMode.values[(m.index + 1) % 3]),
                    );
                  },
                ),
              ]),
              const Spacer(),
            ]),
          );
        },
      ),
    );
  }
}
