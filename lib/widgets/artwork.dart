import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class Artwork extends StatelessWidget {
  final bool local;
  final int? localId;
  final double size;
  const Artwork({super.key, required this.local, this.localId, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.onSurface.withAlpha(25),
      child: Icon(local ? Icons.music_note : Icons.cloud_outlined,
          size: size * .5, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    if (!local || localId == null) {
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: QueryArtworkWidget(
        id: localId!,
        type: ArtworkType.AUDIO,
        artworkWidth: size,
        artworkHeight: size,
        artworkBorder: BorderRadius.zero,
        keepOldArtwork: true,
        nullArtworkWidget: fallback,
      ),
    );
  }
}
