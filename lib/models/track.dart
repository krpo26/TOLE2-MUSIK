import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

String fmtDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

String baseName(String p) {
  final i = p.lastIndexOf('/');
  return i >= 0 ? p.substring(i + 1) : p;
}

class Track {
  final String id, title, artist, uri, album;
  final String? path;
  final int durationMs, dateAdded;
  final bool local;
  final int? localId;
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.uri,
    this.album = '',
    this.path,
    this.durationMs = 0,
    this.dateAdded = 0,
    this.local = false,
    this.localId,
  });

  /// Carpeta que contiene el archivo ('' si no se conoce).
  String get folder {
    final p = path;
    if (p == null) return '';
    final i = p.lastIndexOf('/');
    return i <= 0 ? '' : p.substring(0, i);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'uri': uri,
        'album': album,
        'path': path,
        'durationMs': durationMs,
        'dateAdded': dateAdded,
        'local': local,
        'localId': localId,
      };

  factory Track.fromMap(Map<String, dynamic> m) => Track(
        id: m['id'] as String,
        title: m['title'] as String? ?? 'Sin título',
        artist: m['artist'] as String? ?? 'Desconocido',
        uri: m['uri'] as String,
        album: m['album'] as String? ?? '',
        path: m['path'] as String?,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        dateAdded: (m['dateAdded'] as num?)?.toInt() ?? 0,
        local: m['local'] as bool? ?? false,
        localId: (m['localId'] as num?)?.toInt(),
      );

  AudioSource toSource() => AudioSource.uri(
        Uri.parse(uri),
        tag: MediaItem(
          id: id,
          title: title,
          artist: artist,
          album: album.isEmpty ? null : album,
          duration:
              durationMs > 0 ? Duration(milliseconds: durationMs) : null,
          extras: {'local': local, 'localId': localId},
        ),
      );

  /// Reconstruye un Track desde lo que está sonando.
  static Track? fromSource(IndexedAudioSource? src) {
    final tag = src?.tag;
    if (src is! UriAudioSource || tag is! MediaItem) return null;
    return Track(
      id: tag.id,
      title: tag.title,
      artist: tag.artist ?? 'Desconocido',
      uri: src.uri.toString(),
      album: tag.album ?? '',
      durationMs: tag.duration?.inMilliseconds ?? 0,
      local: tag.extras?['local'] == true,
      localId: (tag.extras?['localId'] as num?)?.toInt(),
    );
  }
}
