import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/local_library.dart';
import '../services/player_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list_view.dart';
import '../widgets/track_tile.dart';

String rootOf(String dir) {
  final m = RegExp(r'^/storage/emulated/\d+').firstMatch(dir) ??
      RegExp(r'^/storage/[^/]+').firstMatch(dir);
  return m?.group(0) ?? '/';
}

String rootName(String r) => r.startsWith('/storage/emulated')
    ? 'Almacenamiento interno'
    : (r == '/' ? 'Raíz' : 'Tarjeta SD');

/// Contenido de una carpeta: subcarpetas + canciones directas.
class FolderView extends StatelessWidget {
  final String path;
  final List<Track> all;
  const FolderView({super.key, required this.path, required this.all});

  @override
  Widget build(BuildContext context) {
    final prefix = path.endsWith('/') ? path : '$path/';
    final inside = all
        .where((t) => t.folder == path || t.folder.startsWith(prefix))
        .toList()
      ..sort((a, b) =>
          (a.path ?? '').toLowerCase().compareTo((b.path ?? '').toLowerCase()));
    if (inside.isEmpty) return const Center(child: Text('Carpeta vacía'));
    final direct = inside.where((t) => t.folder == path).toList();
    final counts = <String, int>{};
    for (final t in inside) {
      if (t.folder == path) continue;
      final first = t.folder.substring(prefix.length).split('/').first;
      counts[first] = (counts[first] ?? 0) + 1;
    }
    final subs = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final primary = Theme.of(context).colorScheme.primary;

    return ListView.builder(
      itemCount: 1 + subs.length + direct.length,
      itemBuilder: (_, i) {
        if (i == 0) return PlayAllBar(tracks: inside);
        if (i <= subs.length) {
          final name = subs[i - 1];
          return ListTile(
            leading: Icon(Icons.folder, color: primary, size: 36),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${counts[name]} canciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      FolderScreen(path: '$prefix$name', all: all)),
            ),
          );
        }
        final idx = i - 1 - subs.length;
        return TrackTile(
          track: direct[idx],
          onTap: () => PlayerService.instance.playList(direct, idx),
        );
      },
    );
  }
}

/// Pantalla de una carpeta (se puede volver atrás con el botón Atrás).
class FolderScreen extends StatelessWidget {
  final String path;
  final List<Track> all;
  final String? title;
  const FolderScreen({super.key, required this.path, required this.all, this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title ?? baseName(path))),
        body: FolderView(path: path, all: all),
        bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      );
}

class FoldersTab extends StatefulWidget {
  const FoldersTab({super.key});
  @override
  State<FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends State<FoldersTab>
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
        final all = lib.tracks.where((t) => t.path != null).toList();
        if (all.isEmpty) return const Center(child: Text('Sin carpetas con audios'));
        final roots = <String>{for (final t in all) rootOf(t.folder)}.toList()
          ..sort();
        if (roots.length == 1) {
          return FolderView(path: roots.first, all: all);
        }
        return ListView(children: [
          for (final r in roots)
            ListTile(
              leading: const Icon(Icons.sd_storage, size: 32),
              title: Text(rootName(r)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FolderScreen(path: r, all: all, title: rootName(r))),
              ),
            ),
        ]);
      },
    );
  }
}
