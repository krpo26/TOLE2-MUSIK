import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/player_service.dart';
import '../widgets/artwork.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.instance.player;
    return Scaffold(
      appBar: AppBar(title: const Text('Cola de reproducción')),
      body: StreamBuilder<SequenceState?>(
        stream: p.sequenceStateStream,
        builder: (_, snap) {
          final seq = snap.data?.sequence ?? const <IndexedAudioSource>[];
          final cur = snap.data?.currentIndex;
          if (seq.isEmpty) {
            return const Center(child: Text('La cola está vacía'));
          }
          return ReorderableListView.builder(
            itemCount: seq.length,
            onReorder: (o, n) {
              if (n > o) n -= 1;
              p.moveAudioSource(o, n);
            },
            itemBuilder: (_, i) {
              final tag = seq[i].tag;
              final item = tag is MediaItem ? tag : null;
              return ListTile(
                key: ValueKey('q_${item?.id}_$i'),
                selected: i == cur,
                leading: Artwork(
                  local: item?.extras?['local'] == true,
                  localId: (item?.extras?['localId'] as num?)?.toInt(),
                  size: 44,
                ),
                title: Text(item?.title ?? 'Audio',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item?.artist ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => p.removeAudioSourceAt(i),
                ),
                onTap: () => p.seek(Duration.zero, index: i),
              );
            },
          );
        },
      ),
    );
  }
}
