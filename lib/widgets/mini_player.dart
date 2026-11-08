import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../screens/now_playing_screen.dart';
import '../services/player_service.dart';
import 'artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final svc = PlayerService.instance;
    final p = svc.player;
    return StreamBuilder<SequenceState?>(
      stream: p.sequenceStateStream,
      builder: (_, snap) {
        final item = snap.data?.currentSource?.tag;
        if (item is! MediaItem) return const SizedBox.shrink();
        return InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NowPlayingScreen())),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              StreamBuilder(
                stream: svc.progress,
                builder: (_, s) {
                  final dur = s.data?.dur.inMilliseconds ?? 0;
                  final pos = s.data?.pos.inMilliseconds ?? 0;
                  return LinearProgressIndicator(
                    value: dur > 0 ? (pos / dur).clamp(0.0, 1.0).toDouble() : 0,
                    minHeight: 2,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Artwork(
                      local: item.extras?['local'] == true,
                      localId: (item.extras?['localId'] as num?)?.toInt()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(item.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12)),
                        ]),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: p.playerStateStream,
                    builder: (_, s) => IconButton(
                      icon: Icon((s.data?.playing ?? false)
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: () =>
                          (s.data?.playing ?? false) ? p.pause() : p.play(),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: p.seekToNext),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
