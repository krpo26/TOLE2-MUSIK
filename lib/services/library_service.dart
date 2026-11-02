import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';

class LibraryService {
  static final _query = OnAudioQuery();
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// true solo si Firebase se inicializó y hay sesión anónima.
  static bool get cloudReady =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  // ---------- Dispositivo ----------
  static Future<bool> ensurePermission() async {
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  static Future<List<Track>> localTracks() async {
    final songs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return songs
        .where((s) => s.isMusic == true && s.uri != null)
        .map((s) => Track(
              id: 'local_${s.id}',
              title: s.title,
              artist: (s.artist == null || s.artist == '<unknown>')
                  ? 'Desconocido'
                  : s.artist!,
              uri: s.uri!,
              local: true,
              localId: s.id,
            ))
        .toList();
  }

  // ---------- Nube ----------
  static Stream<List<Track>> cloudTracks() {
    if (!cloudReady) return Stream.value(<Track>[]);
    return _db
        .collection('tracks')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((q) => q.docs
            .map((d) => Track.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  static Future<void> uploadAudio() async {
    if (!cloudReady) throw Exception('La nube no está configurada');
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res == null || res.files.single.path == null) return;
    final f = res.files.single;
    final ref = FirebaseStorage.instance
        .ref('audios/${DateTime.now().millisecondsSinceEpoch}_${f.name}');
    await ref.putFile(File(f.path!));
    final url = await ref.getDownloadURL();
    final title = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    await _db.collection('tracks').add({
      'title': title,
      'artist': 'Mi nube',
      'uri': url,
      'local': false,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Favoritos (sincronizados por usuario) ----------
  static CollectionReference<Map<String, dynamic>> get _favs =>
      _db.collection('users').doc(_uid).collection('favorites');

  static Stream<List<Track>> favorites() {
    if (!cloudReady) return Stream.value(<Track>[]);
    return _favs
        .snapshots()
        .map((q) => q.docs.map((d) => Track.fromMap(d.data())).toList());
  }

  static Stream<Set<String>> favoriteIds() {
    if (!cloudReady) return Stream.value(<String>{});
    return _favs.snapshots().map((q) => q.docs.map((d) => d.id).toSet());
  }

  /// Devuelve false si no se pudo (nube no disponible).
  static Future<bool> toggleFavorite(Track t, bool isFav) async {
    if (!cloudReady) return false;
    try {
      final doc = _favs.doc(t.id);
      isFav ? await doc.delete() : await doc.set(t.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }
}
