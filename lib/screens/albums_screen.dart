import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/local_library.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list_view.dart';

/// Detalle de un álbum, artista o cualquier grupo de canciones.
class TrackGroupScreen extends StatelessWidget {
  final String title;
  final List<Track> tracks;
  const TrackGroupScreen({super.key, required this.title, required this.tracks});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(children: [
          PlayAllBar(tracks: tracks),
          Expanded(child: TrackListView(tracks: tracks)),
        ]),
        bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      );
}

Map<String, List<Track>> _group(List<Track> all, String Function(Track) key) {
  final m = <String, List<Track>>{};
  for (final t in all) {
    m.putIfAbsent(key(t), () => <Track>[]).add(t);
  }
  for (final l in m.values) {
    l.sort((a, b) =>
        (a.path ?? a.title).toLowerCase().compareTo((b.path ?? b.title).toLowerCase()));
  }
  return m;
}

class AlbumsTab extends StatefulWidget {
  const AlbumsTab({super.key});
  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lib = LocalLibrary.instance;
    return ListenableBuilder(
      listenable: lib,
      builder: (_, __) {
        if (lib.loading && !lib.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = _group(lib.tracks, (t) => t.album);
        final names = groups.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (names.isEmpty) return const Center(child: Text('Sin álbumes'));
        return ListView.builder(
          itemCount: names.length,
          itemBuilder: (_, i) {
            final n = names[i];
            final l = groups[n]!;
            return ListTile(
              leading: Artwork(local: true, localId: l.first.localId, size: 52),
              title: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${l.first.artist} · ${l.length} canciones',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TrackGroupScreen(title: n, tracks: l)),
              ),
            );
          },
        );
      },
    );
  }
}

class ArtistsTab extends StatefulWidget {
  const ArtistsTab({super.key});
  @override
  State<ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<ArtistsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lib = LocalLibrary.instance;
    return ListenableBuilder(
      listenable: lib,
      builder: (_, __) {
        if (lib.loading && !lib.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = _group(lib.tracks, (t) => t.artist);
        final names = groups.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (names.isEmpty) return const Center(child: Text('Sin artistas'));
        return ListView.builder(
          itemCount: names.length,
          itemBuilder: (_, i) {
            final n = names[i];
            final l = groups[n]!;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${l.length} canciones'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TrackGroupScreen(title: n, tracks: l)),
              ),
            );
          },
        );
      },
    );
  }
}
