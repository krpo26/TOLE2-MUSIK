import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import 'track_tile.dart';

/// Botones "Reproducir" y "Aleatorio" para una lista.
class PlayAllBar extends StatelessWidget {
  final List<Track> tracks;
  const PlayAllBar({super.key, required this.tracks});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Reproducir'),
              onPressed: tracks.isEmpty
                  ? null
                  : () => PlayerService.instance
                      .playList(tracks, 0, shuffle: false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.shuffle),
              label: const Text('Aleatorio'),
              onPressed: tracks.isEmpty
                  ? null
                  : () => PlayerService.instance.playList(
                      tracks, Random().nextInt(tracks.length),
                      shuffle: true),
            ),
          ),
        ]),
      );
}

/// Lista de canciones; opcionalmente intercala las imágenes de "Personalizar".
class TrackListView extends StatelessWidget {
  final List<Track> tracks;
  final bool withBanners;
  const TrackListView({super.key, required this.tracks, this.withBanners = false});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const Center(child: Text('Sin audios'));
    final s = SettingsService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) {
        final useBanners = withBanners && s.showBanners && s.banners.isNotEmpty;
        final n = s.bannerEvery;
        final count =
            useBanners ? tracks.length + tracks.length ~/ n : tracks.length;
        return ListView.builder(
          itemCount: count,
          itemBuilder: (_, p) {
            if (useBanners && (p + 1) % (n + 1) == 0) {
              final idx = ((p + 1) ~/ (n + 1) - 1) % s.banners.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Image.file(File(s.banners[idx]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              );
            }
            final i = useBanners ? p - (p + 1) ~/ (n + 1) : p;
            return TrackTile(
              track: tracks[i],
              onTap: () => PlayerService.instance.playList(tracks, i),
            );
          },
        );
      },
    );
  }
}
