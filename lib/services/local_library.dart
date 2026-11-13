import 'package:flutter/foundation.dart';
import '../models/track.dart';
import 'library_service.dart';
import 'settings_service.dart';

/// Biblioteca del celular, cargada una sola vez y compartida por todas las pestañas.
class LocalLibrary extends ChangeNotifier {
  LocalLibrary._() {
    SettingsService.instance.addListener(_onSettings);
  }
  static final instance = LocalLibrary._();

  List<Track> _all = [];
  List<Track> tracks = [];
  String _hiddenKey = '';

  String _key() {
    final s = SettingsService.instance;
    return "${s.hiddenFolders.join("|")}#${s.hideWhatsapp}";
  }

  void _applyFilter() {
    final s = SettingsService.instance;
    final h = s.hiddenFolders;
    final wa = s.hideWhatsapp;
    _hiddenKey = _key();
    bool hidden(Track t) {
      if (wa && (t.path ?? '').toLowerCase().contains('whatsapp')) return true;
      final f = t.folder;
      return h.any((x) => f == x || f.startsWith('$x/'));
    }

    tracks = _all.where((t) => !hidden(t)).toList();
  }

  void _onSettings() {
    if (_key() != _hiddenKey) {
      _applyFilter();
      notifyListeners();
    }
  }

  bool loading = false, loaded = false, denied = false;
  String? error;

  Future<void> load() async {
    loading = true;
    denied = false;
    error = null;
    notifyListeners();
    try {
      if (await LibraryService.ensurePermission()) {
        _all = await LibraryService.localTracks();
        _applyFilter();
      } else {
        denied = true;
        _all = [];
        tracks = [];
      }
    } catch (e) {
      error = '$e';
    }
    loading = false;
    loaded = true;
    notifyListeners();
  }
}
