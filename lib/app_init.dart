import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';

/// Inicializa audio en segundo plano y Firebase SIN bloquear la app:
/// si algo falla, la app abre igual y guarda un aviso en [warning].
class AppInit {
  static final warning = ValueNotifier<String?>(null);
  static Future<void>? _f;
  static Future<void> run() => _f ??= _run();

  static Future<void> _run() async {
    final msgs = <String>[];
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.example.audio_player.channel.audio',
        androidNotificationChannelName: 'Reproducción de audio',
        // El servicio sigue activo también en pausa: así Android no lo cierra
        // y la notificación con controles se mantiene.
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      msgs.add('Audio en segundo plano no disponible: $e');
    }

    if (firebaseOptions.apiKey.startsWith('TU_')) {
      msgs.add('Nube desactivada: falta completar lib/firebase_options.dart. '
          'La música del celular funciona igual.');
    } else {
      try {
        await Firebase.initializeApp(options: firebaseOptions)
            .timeout(const Duration(seconds: 10));
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance
              .signInAnonymously()
              .timeout(const Duration(seconds: 10));
        }
      } catch (e) {
        msgs.add('Nube no disponible: $e');
      }
    }
    if (msgs.isNotEmpty) warning.value = msgs.join('\n');
  }
}
