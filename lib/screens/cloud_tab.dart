import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../widgets/track_list_view.dart';

class CloudTab extends StatelessWidget {
  const CloudTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!LibraryService.cloudReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Nube no configurada.\nCompleta firebase_options.dart para usarla.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Track>>(
        stream: LibraryService.cloudTracks(),
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('Error de nube: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final list = s.data!;
          return Column(children: [
            PlayAllBar(tracks: list),
            Expanded(child: TrackListView(tracks: list, withBanners: true)),
          ]);
        },
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
}
