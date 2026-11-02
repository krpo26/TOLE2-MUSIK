import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/player_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list_view.dart';
import '../widgets/track_tile.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LocalStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final names = store.playlistNames;
        return ListView(children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Nueva lista'),
            onTap: () async {
              final n = await promptName(context);
              if (n != null) await store.createPlaylist(n);
            },
          ),
          for (final n in names)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(n),
              subtitle: Text('${store.playlist(n).length} canciones'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, '¿Borrar la lista "$n"?')) {
                    await store.deletePlaylist(n);
                  }
                },
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlaylistScreen(name: n)),
              ),
            ),
          if (names.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no tienes listas.\nCrea una o agrega canciones desde el menú ⋮ de cada tema.',
                textAlign: TextAlign.center,
              ),
            ),
        ]);
      },
    );
  }
}

class PlaylistScreen extends StatelessWidget {
  final String name;
  const PlaylistScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final store = LocalStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final tracks = store.playlist(name);
          if (tracks.isEmpty) {
            return const Center(child: Text('Lista vacía'));
          }
          return Column(children: [
            PlayAllBar(tracks: tracks),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('Desliza una canción hacia la izquierda para quitarla',
                  style: TextStyle(fontSize: 11)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (_, i) {
                  final t = tracks[i];
                  return Dismissible(
                    key: ValueKey('${name}_${t.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => store.removeFromPlaylist(name, t),
                    child: TrackTile(
                      track: t,
                      onTap: () => PlayerService.instance.playList(tracks, i),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
    );
  }
}

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: LocalStore.instance,
        builder: (_, __) {
          final favs = LocalStore.instance.favorites;
          if (favs.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aún no hay favoritos.\nUsa el menú ⋮ de una canción o el corazón en "Reproduciendo".',
                  textAlign: TextAlign.center),
            ));
          }
          return Column(children: [
            PlayAllBar(tracks: favs),
            Expanded(child: TrackListView(tracks: favs)),
          ]);
        },
      );
}
