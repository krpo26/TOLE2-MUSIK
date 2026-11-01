import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class Track {
  final String id, title, artist, uri;
  final bool local;
  final int? localId;
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.uri,
    this.local = false,
    this.localId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'uri': uri,
        'local': local,
        'localId': localId,
      };

  factory Track.fromMap(Map<String, dynamic> m) => Track(
        id: m['id'] as String,
        title: m['title'] as String? ?? 'Sin título',
        artist: m['artist'] as String? ?? 'Desconocido',
        uri: m['uri'] as String,
        local: m['local'] as bool? ?? false,
        localId: m['localId'] as int?,
      );

  AudioSource toSource() => AudioSource.uri(
        Uri.parse(uri),
        tag: MediaItem(
          id: id,
          title: title,
          artist: artist,
          extras: {'local': local, 'localId': localId},
        ),
      );
}
