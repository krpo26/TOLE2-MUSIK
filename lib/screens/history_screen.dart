import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/player_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/track_list_view.dart';
import '../widgets/track_tile.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final store = LocalStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final list = _mode == 0 ? store.recentTracks : store.topTracks;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0, label: Text('Recientes'), icon: Icon(Icons.history)),
                ButtonSegment(
                    value: 1,
                    label: Text('Más escuchadas'),
                    icon: Icon(Icons.trending_up)),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
          ),
          if (list.isEmpty)
            const Expanded(
              child: Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay historial.\nReproduce canciones y aparecerán aquí.',
                    textAlign: TextAlign.center),
              )),
            )
          else ...[
            PlayAllBar(tracks: list),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final t = list[i];
                  return TrackTile(
                    track: t,
                    extra: _mode == 1 ? ' · ${store.playCount(t.id)}×' : null,
                    onTap: () => PlayerService.instance.playList(list, i),
                  );
                },
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar historial'),
              onPressed: () async {
                if (await confirm(context, '¿Borrar todo el historial?')) {
                  await store.clearHistory();
                }
              },
            ),
          ],
        ]);
      },
    );
  }
}
