import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_init.dart';
import '../services/local_library.dart';
import '../services/settings_service.dart';
import '../widgets/mini_player.dart';
import 'albums_screen.dart';
import 'cloud_tab.dart';
import 'equalizer_screen.dart';
import 'folders_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';
import 'songs_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    LocalLibrary.instance.load();
    // Permite mostrar los controles en la notificación (Android 13+).
    Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TOLE2'),
          actions: [
            IconButton(
              icon: const Icon(Icons.equalizer),
              tooltip: 'Ecualizador',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EqualizerScreen())),
            ),
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
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.music_note), text: 'Canciones'),
              Tab(icon: Icon(Icons.folder), text: 'Carpetas'),
              Tab(icon: Icon(Icons.album), text: 'Álbumes'),
              Tab(icon: Icon(Icons.person), text: 'Artistas'),
              Tab(icon: Icon(Icons.queue_music), text: 'Listas'),
              Tab(icon: Icon(Icons.favorite), text: 'Favoritos'),
              Tab(icon: Icon(Icons.cloud), text: 'Nube'),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [
              SongsTab(),
              FoldersTab(),
              AlbumsTab(),
              ArtistsTab(),
              PlaylistsTab(),
              FavoritesTab(),
              CloudTab(),
            ]),
          ),
        ]),
        bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      ),
    );
  }
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
