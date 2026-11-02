import 'package:flutter/foundation.dart';
import '../models/track.dart';
import 'library_service.dart';

/// Biblioteca del celular, cargada una sola vez y compartida por todas las pestañas.
class LocalLibrary extends ChangeNotifier {
  LocalLibrary._();
  static final instance = LocalLibrary._();

  List<Track> tracks = [];
  bool loading = false, loaded = false, denied = false;
  String? error;

  Future<void> load() async {
    loading = true;
    denied = false;
    error = null;
    notifyListeners();
    try {
      if (await LibraryService.ensurePermission()) {
        tracks = await LibraryService.localTracks();
      } else {
        denied = true;
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
