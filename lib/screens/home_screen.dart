import 'dart:io';
import 'package:flutter/material.dart';
import '../app_init.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TOLE2'),
          actions: [
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Personalizar',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
        body: Column(children: [
          const _InitWarning(),
          ListenableBuilder(
            listenable: s,
            builder: (_, __) {
              final p = s.heroPath;
              if (p == null) return const SizedBox.shrink();
              return SizedBox(
                height: 150,
                width: double.infinity,
                child: Image.file(File(p),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              );
            },
          ),
          const TabBar(tabs: [
            Tab(icon: Icon(Icons.phone_android), text: 'Dispositivo'),
            Tab(icon: Icon(Icons.cloud), text: 'Nube'),
            Tab(icon: Icon(Icons.favorite), text: 'Favoritos'),
          ]),
          const Expanded(
            child: TabBarView(children: [
              _LocalTab(),
              _CloudTab(),
              _FavsTab(),
            ]),
          ),
        ]),
        bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  final List<Track> tracks;
  const _TrackList(this.tracks);

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const Center(child: Text('Sin audios'));
    final s = SettingsService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => StreamBuilder<Set<String>>(
        stream: LibraryService.favoriteIds(),
        builder: (_, fs) {
          final favs = fs.data ?? {};
          final useBanners = s.showBanners && s.banners.isNotEmpty;
          final n = s.bannerEvery;
          final count = useBanners ? tracks.length + tracks.length ~/ n : tracks.length;
          return ListView.builder(
            itemCount: count,
            itemBuilder: (_, p) {
              if (useBanners && (p + 1) % (n + 1) == 0) {
                final idx = ((p + 1) ~/ (n + 1) - 1) % s.banners.length;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: Image.file(File(s.banners[idx]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    ),
                  ),
                );
              }
              final i = useBanners ? p - (p + 1) ~/ (n + 1) : p;
              final t = tracks[i];
              final isFav = favs.contains(t.id);
              return ListTile(
                leading: Artwork(local: t.local, localId: t.localId),
                title: Text(t.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : null),
                  onPressed: () async {
                    final m = ScaffoldMessenger.of(context);
                    final ok = await LibraryService.toggleFavorite(t, isFav);
                    if (!ok) {
                      m.showSnackBar(const SnackBar(
                          content: Text('Favoritos necesita la nube configurada')));
                    }
                  },
                ),
                onTap: () => PlayerService.instance.playList(tracks, i),
              );
            },
          );
        },
      ),
    );
  }
}

class _LocalTab extends StatefulWidget {
  const _LocalTab();
  @override
  State<_LocalTab> createState() => _LocalTabState();
}

class _LocalTabState extends State<_LocalTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Track>?> _f = _load();
  Future<List<Track>?> _load() async => await LibraryService.ensurePermission()
      ? LibraryService.localTracks()
      : null;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Track>?>(
      future: _f,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.data == null) {
          return Center(
            child: FilledButton(
                onPressed: () => setState(() => _f = _load()),
                child: const Text('Dar permiso de audio')),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _f = _load()),
          child: _TrackList(s.data!),
        );
      },
    );
  }
}

class _CloudTab extends StatelessWidget {
  const _CloudTab();
  @override
  Widget build(BuildContext context) {
    if (!LibraryService.cloudReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nube no configurada.\nCompleta firebase_options.dart para usarla.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return _cloudBody(context);
  }

  Widget _cloudBody(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: StreamBuilder<List<Track>>(
          stream: LibraryService.cloudTracks(),
          builder: (_, s) => s.hasData
              ? _TrackList(s.data!)
              : const Center(child: CircularProgressIndicator()),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.upload),
          label: const Text('Subir audio'),
          onPressed: () async {
            final m = ScaffoldMessenger.of(context);
            m.showSnackBar(const SnackBar(content: Text('Subiendo…')));
            try {
              await LibraryService.uploadAudio();
              m.showSnackBar(const SnackBar(content: Text('Listo')));
            } catch (e) {
              m.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
        ),
      );
}

class _FavsTab extends StatelessWidget {
  const _FavsTab();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Track>>(
        stream: LibraryService.favorites(),
        builder: (_, s) => s.hasData
            ? _TrackList(s.data!)
            : const Center(child: CircularProgressIndicator()),
      );
}

class _InitWarning extends StatefulWidget {
  const _InitWarning();
  @override
  State<_InitWarning> createState() => _InitWarningState();
}

class _InitWarningState extends State<_InitWarning> {
  bool _closed = false;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: AppInit.warning,
        builder: (_, msg, __) {
          if (msg == null || _closed) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg, style: const TextStyle(fontSize: 12))),
              IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _closed = true)),
            ]),
          );
        },
      );
}
