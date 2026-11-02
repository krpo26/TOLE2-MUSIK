import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';
import '../services/local_library.dart';
import '../widgets/track_list_view.dart';

enum SortMode { titulo, artista, reciente }

class SongsTab extends StatefulWidget {
  const SongsTab({super.key});
  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab>
    with AutomaticKeepAliveClientMixin {
  String _q = '';
  SortMode _sort = SortMode.titulo;

  @override
  bool get wantKeepAlive => true;

  List<Track> _filtered(List<Track> all) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Track>.from(all)
        : all
            .where((t) =>
                t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.album.toLowerCase().contains(q))
            .toList();
    switch (_sort) {
      case SortMode.titulo:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortMode.artista:
        list.sort((a, b) {
          final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SortMode.reciente:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }
    return list;
  }

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
        if (lib.denied) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Se necesita permiso para leer tu música'),
              const SizedBox(height: 12),
              FilledButton(onPressed: lib.load, child: const Text('Dar permiso')),
              TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Abrir ajustes de la app')),
            ]),
          );
        }
        if (lib.error != null) {
          return Center(child: Text('Error: ${lib.error}'));
        }
        final list = _filtered(lib.tracks);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar canción, artista o álbum',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              PopupMenuButton<SortMode>(
                icon: const Icon(Icons.sort),
                tooltip: 'Ordenar',
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: SortMode.titulo, child: Text('Por título')),
                  PopupMenuItem(value: SortMode.artista, child: Text('Por artista')),
                  PopupMenuItem(value: SortMode.reciente, child: Text('Más recientes')),
                ],
              ),
            ]),
          ),
          PlayAllBar(tracks: list),
          Expanded(
            child: RefreshIndicator(
              onRefresh: lib.load,
              child: TrackListView(tracks: list, withBanners: true),
            ),
          ),
        ]);
      },
    );
  }
}
