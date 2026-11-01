import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/track.dart';

class PlayerService {
  PlayerService._();
  static final instance = PlayerService._();
  final player = AudioPlayer();

  Future<void> playList(List<Track> tracks, int index) async {
    await player.setAudioSources(
      tracks.map((t) => t.toSource()).toList(),
      initialIndex: index,
    );
    player.play();
  }

  Stream<({Duration pos, Duration dur})> get progress => Rx.combineLatest2(
        player.positionStream,
        player.durationStream,
        (p, d) => (pos: p, dur: d ?? Duration.zero),
      );
}
