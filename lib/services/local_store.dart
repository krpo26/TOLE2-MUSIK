import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'local_library.dart';

/// Favoritos y listas de reproducción guardados en el celular.
class LocalStore extends ChangeNotifier {
  LocalStore._();
  static final instance = LocalStore._();

  late SharedPreferences _p;
  bool _ready = false;
  final Map<String, Track> _favs = {};
  final Map<String, List<Track>> _lists = {};
  final Map<String, Track> _played = {};
  final Map<String, int> _counts = {};
  List<String> _recentIds = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _ready = true;
    try {
      final f = _p.getString('favs');
      if (f != null) {
        for (final m in jsonDecode(f) as List) {
          final t = Track.fromMap(Map<String, dynamic>.from(m as Map));
          _favs[t.id] = t;
        }
      }
      final l = _p.getString('playlists');
      if (l != null) {
        (jsonDecode(l) as Map).forEach((k, v) {
          _lists[k as String] = (v as List)
              .map((m) => Track.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
        });
      }
      _loadHistory();
    } catch (_) {}
  }

  List<Track> get favorites => _favs.values.toList().reversed.toList();
  bool isFav(String id) => _favs.containsKey(id);

  Future<void> toggleFav(Track t) async {
    if (_favs.containsKey(t.id)) {
      _favs.remove(t.id);
    } else {
      _favs[t.id] = t;
    }
    await _save();
  }

  List<String> get playlistNames => _lists.keys.toList();
  List<Track> playlist(String name) => _lists[name] ?? const <Track>[];

  Future<void> createPlaylist(String name) async {
    _lists.putIfAbsent(name, () => <Track>[]);
    await _save();
  }

  Future<void> deletePlaylist(String name) async {
    _lists.remove(name);
    await _save();
  }

  Future<void> addToPlaylist(String name, Track t) async {
    final l = _lists.putIfAbsent(name, () => <Track>[]);
    if (!l.any((x) => x.id == t.id)) l.add(t);
    await _save();
  }

  Future<void> removeFromPlaylist(String name, Track t) async {
    _lists[name]?.removeWhere((x) => x.id == t.id);
    await _save();
  }

  void _loadHistory() {
    final pl = _p.getString('played');
    if (pl != null) {
      for (final m in jsonDecode(pl) as List) {
        final t = Track.fromMap(Map<String, dynamic>.from(m as Map));
        _played[t.id] = t;
      }
    }
    final c = _p.getString('counts');
    if (c != null) {
      (jsonDecode(c) as Map)
          .forEach((k, v) => _counts[k as String] = (v as num).toInt());
    }
    _recentIds = _p.getStringList('recent') ?? [];
  }

  List<Track> get recentTracks => [
        for (final id in _recentIds)
          if (_played[id] != null) _played[id]!
      ];

  List<Track> get topTracks {
    final ids = _counts.keys.where((id) => _played.containsKey(id)).toList()
      ..sort((a, b) => (_counts[b] ?? 0).compareTo(_counts[a] ?? 0));
    return [for (final id in ids.take(100)) _played[id]!];
  }

  int playCount(String id) => _counts[id] ?? 0;

  Future<void> recordPlay(Track t) async {
    _played[t.id] = t;
    _counts[t.id] = (_counts[t.id] ?? 0) + 1;
    _recentIds.remove(t.id);
    _recentIds.insert(0, t.id);
    if (_recentIds.length > 100) _recentIds = _recentIds.sublist(0, 100);
    if (_played.length > 800) {
      final keep = _recentIds.toSet();
      _played.removeWhere(
          (id, _) => !keep.contains(id) && (_counts[id] ?? 0) <= 1);
      _counts.removeWhere((id, _) => !_played.containsKey(id));
    }
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    _played.clear();
    _counts.clear();
    _recentIds = [];
    notifyListeners();
    await _saveHistory();
  }

  /// Datos para el respaldo en la nube (solo lo esencial, para que sea liviano).
  Map<String, dynamic> exportData() {
    final keep = <String>{..._recentIds, ...topTracks.map((t) => t.id)};
    return {
      'v': 1,
      'favs': _favs.values.map((t) => t.toMap()).toList(),
      'playlists': _lists.map((k, v) => MapEntry(k, v.map((t) => t.toMap()).toList())),
      'played': [
        for (final id in keep)
          if (_played[id] != null) _played[id]!.toMap()
      ],
      'counts': {for (final id in keep) id: _counts[id] ?? 0},
      'recent': _recentIds,
    };
  }

  List<Track> _tracksFrom(Object? raw) => [
        for (final m in (raw as List? ?? const []))
          Track.fromMap(Map<String, dynamic>.from(m as Map))
      ];

  /// Reemplaza favoritos, listas e historial por los del respaldo.
  Future<void> importData(Map<String, dynamic> d) async {
    _favs.clear();
    _lists.clear();
    _played.clear();
    _counts.clear();
    for (final t in _tracksFrom(d['favs'])) {
      _favs[t.id] = t;
    }
    (d['playlists'] as Map? ?? const {}).forEach((k, v) {
      _lists[k as String] = _tracksFrom(v);
    });
    for (final t in _tracksFrom(d['played'])) {
      _played[t.id] = t;
    }
    (d['counts'] as Map? ?? const {})
        .forEach((k, v) => _counts[k as String] = (v as num).toInt());
    _recentIds = List<String>.from(d['recent'] as List? ?? const []);
    remap(LocalLibrary.instance.tracks);
    await _save();
    await _saveHistory();
  }

  /// Vuelve a enlazar las canciones locales con las de ESTE celular (por ruta de archivo).
  void remap(List<Track> library) {
    final byPath = {
      for (final t in library)
        if (t.path != null) t.path!: t
    };
    Track fix(Track t) =>
        (t.local && t.path != null) ? (byPath[t.path!] ?? t) : t;

    final favs = _favs.values.map(fix).toList();
    _favs.clear();
    for (final t in favs) {
      _favs[t.id] = t;
    }
    _lists.updateAll((k, v) => v.map(fix).toList());

    final idMap = <String, String>{};
    final newPlayed = <String, Track>{};
    for (final t in _played.values) {
      final n = fix(t);
      idMap[t.id] = n.id;
      newPlayed[n.id] = n;
    }
    final newCounts = <String, int>{};
    _counts.forEach((id, c) {
      final nid = idMap[id] ?? id;
      newCounts[nid] = (newCounts[nid] ?? 0) + c;
    });
    _played
      ..clear()
      ..addAll(newPlayed);
    _counts
      ..clear()
      ..addAll(newCounts);
    _recentIds = _recentIds.map((id) => idMap[id] ?? id).toSet().toList();
  }

  Future<void> _saveHistory() async {
    if (!_ready) return;
    await _p.setString(
        'played', jsonEncode(_played.values.map((x) => x.toMap()).toList()));
    await _p.setString('counts', jsonEncode(_counts));
    await _p.setStringList('recent', _recentIds);
  }

  Future<void> _save() async {
    notifyListeners();
    if (!_ready) return;
    await _p.setString(
        'favs', jsonEncode(_favs.values.map((t) => t.toMap()).toList()));
    await _p.setString(
        'playlists',
        jsonEncode(_lists.map(
            (k, v) => MapEntry(k, v.map((t) => t.toMap()).toList()))));
  }
}
