import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/lyrics_service.dart';
import '../services/player_service.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});
  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final _ctrl = ScrollController();
  StreamSubscription<SequenceState?>? _sub;
  String? _id;
  String _title = '';
  List<LyricLine> _lines = [];
  bool _timed = false;
  bool _loading = true;
  int _lastIdx = -1;
  static const double _h = 48;
  static const double _pad = 120;

  @override
  void initState() {
    super.initState();
    _sub = PlayerService.instance.player.sequenceStateStream.listen((s) {
      final tag = s?.currentSource?.tag;
      if (tag is MediaItem && tag.id != _id) {
        _id = tag.id;
        _title = tag.title;
        _load();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _id;
    if (id == null) return;
    setState(() => _loading = true);
    final raw = await LyricsService.load(id);
    if (!mounted || id != _id) return;
    final parsed = raw == null ? null : LyricsService.parse(raw);
    setState(() {
      _lines = parsed?.lines ?? [];
      _timed = parsed?.timed ?? false;
      _loading = false;
      _lastIdx = -1;
    });
  }

  Future<void> _import() async {
    final id = _id;
    if (id == null) return;
    if (await LyricsService.pickAndSave(id)) _load();
  }

  Future<void> _remove() async {
    final id = _id;
    if (id == null) return;
    await LyricsService.delete(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = PlayerService.instance.player;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_lines.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Esta canción no tiene letra cargada.\n'
                'Puedes cargar un archivo .lrc (sincronizado) o .txt.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Cargar letra'),
              onPressed: _import,
            ),
          ]),
        ),
      );
    } else if (!_timed) {
      body = ListView(padding: const EdgeInsets.all(24), children: [
        Text(_lines.map((l) => l.text).join('\n'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.6)),
      ]);
    } else {
      body = StreamBuilder<Duration>(
        stream: p.positionStream,
        builder: (_, s) {
          final pos = s.data ?? Duration.zero;
          var idx = -1;
          for (var i = 0; i < _lines.length; i++) {
            if (_lines[i].at <= pos) {
              idx = i;
            } else {
              break;
            }
          }
          if (idx != _lastIdx && idx >= 0) {
            _lastIdx = idx;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_ctrl.hasClients) return;
              final target = _pad + idx * _h + _h / 2 -
                  _ctrl.position.viewportDimension / 2;
              _ctrl.animateTo(
                target.clamp(0.0, _ctrl.position.maxScrollExtent).toDouble(),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
          }
          return ListView.builder(
            controller: _ctrl,
            padding: const EdgeInsets.symmetric(vertical: _pad, horizontal: 24),
            itemExtent: _h,
            itemCount: _lines.length,
            itemBuilder: (_, i) => Center(
              child: Text(
                _lines[i].text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: i == idx ? 20 : 16,
                  fontWeight: i == idx ? FontWeight.bold : FontWeight.normal,
                  color: i == idx ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isEmpty ? 'Letra' : _title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Cargar letra (.lrc o .txt)',
              onPressed: _import),
          if (_lines.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar letra',
                onPressed: _remove),
        ],
      ),
      body: body,
    );
  }
}
