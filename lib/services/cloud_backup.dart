import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'library_service.dart';
import 'local_store.dart';

/// Respaldo de favoritos, listas e historial en Firestore.
/// El "código de respaldo" actúa como contraseña: el documento se guarda
/// con el hash del código, así que hay que elegir uno largo y no compartirlo.
class CloudBackup {
  static String _docId(String code) =>
      sha256.convert(utf8.encode('tole2:${code.trim()}')).toString();

  static Future<void> save(String code) async {
    if (!LibraryService.cloudReady) {
      throw Exception('La nube no está configurada');
    }
    final json = jsonEncode(LocalStore.instance.exportData());
    if (json.length > 800000) {
      throw Exception('El respaldo es demasiado grande');
    }
    await FirebaseFirestore.instance
        .collection('backups')
        .doc(_docId(code))
        .set({
      'data': json,
      'updatedAt': FieldValue.serverTimestamp(),
      'app': 'TOLE2',
    });
  }

  /// true si encontró un respaldo con ese código.
  static Future<bool> restore(String code) async {
    if (!LibraryService.cloudReady) {
      throw Exception('La nube no está configurada');
    }
    final doc = await FirebaseFirestore.instance
        .collection('backups')
        .doc(_docId(code))
        .get();
    final json = doc.data()?['data'] as String?;
    if (!doc.exists || json == null) return false;
    await LocalStore.instance
        .importData(jsonDecode(json) as Map<String, dynamic>);
    return true;
  }
}
