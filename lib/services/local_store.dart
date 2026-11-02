import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

/// Favoritos y listas de reproducción guardados en el celular.
class LocalStore extends ChangeNotifier {
  LocalStore._();
  static final instance = LocalStore._();

  late SharedPreferences _p;
  bool _ready = false;
  final Map<String, Track> _favs = {};
  final Map<String, List<Track>> _lists = {};

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
