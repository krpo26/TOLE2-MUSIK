import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';
import '../services/local_store.dart';
import '../services/player_service.dart';
import 'artwork.dart';
import 'dialogs.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  const TrackTile({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dur = track.durationMs > 0
        ? ' · ${fmtDuration(Duration(milliseconds: track.durationMs))}'
        : '';
    return StreamBuilder<SequenceState?>(
      stream: PlayerService.instance.player.sequenceStateStream,
      builder: (_, snap) {
        final cur = snap.data?.currentSource?.tag;
        final playing = cur is MediaItem && cur.id == track.id;
        return ListTile(
          leading: Artwork(local: track.local, localId: track.localId),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: playing
                ? TextStyle(color: cs.primary, fontWeight: FontWeight.bold)
                : null,
          ),
          subtitle: Text('${track.artist}$dur',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showTrackOptions(context, track),
          ),
          onTap: onTap,
          onLongPress: () => showTrackOptions(context, track),
        );
      },
    );
  }
}

Future<void> showTrackOptions(BuildContext context, Track t) async {
  final m = ScaffoldMessenger.of(context);
  final svc = PlayerService.instance;
  final store = LocalStore.instance;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.playlist_play),
          title: const Text('Reproducir siguiente'),
          onTap: () async {
            Navigator.pop(ctx);
            final ok = await svc.playNext(t);
            m.showSnackBar(SnackBar(
                content: Text(ok ? 'Sonará a continuación' : 'Ya está en la cola')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.queue_music),
          title: const Text('Agregar a la cola'),
          onTap: () async {
            Navigator.pop(ctx);
            final ok = await svc.addToQueue(t);
            m.showSnackBar(SnackBar(
                content: Text(ok ? 'Agregada a la cola' : 'Ya está en la cola')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.playlist_add),
          title: const Text('Agregar a una lista'),
          onTap: () {
            Navigator.pop(ctx);
            pickPlaylist(context, t);
          },
        ),
        ListTile(
          leading: Icon(store.isFav(t.id) ? Icons.favorite : Icons.favorite_border),
          title: Text(store.isFav(t.id)
              ? 'Quitar de favoritos'
              : 'Agregar a favoritos'),
          onTap: () {
            Navigator.pop(ctx);
            store.toggleFav(t);
          },
        ),
      ]),
    ),
  );
}

Future<void> pickPlaylist(BuildContext context, Track t) async {
  final store = LocalStore.instance;
  final m = ScaffoldMessenger.of(context);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Agregar a lista'),
      children: [
        for (final n in store.playlistNames)
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n), child: Text(n)),
        SimpleDialogOption(
          onPressed: () async {
            final nn = await promptName(ctx);
            if (nn != null && ctx.mounted) Navigator.pop(ctx, nn);
          },
          child: const Row(children: [
            Icon(Icons.add),
            SizedBox(width: 8),
            Text('Nueva lista…'),
          ]),
        ),
      ],
    ),
  );
  if (name == null) return;
  await store.addToPlaylist(name, t);
  m.showSnackBar(SnackBar(content: Text('Agregada a "$name"')));
}
