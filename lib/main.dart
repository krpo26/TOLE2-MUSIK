import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.audio_player.channel.audio',
    androidNotificationChannelName: 'Reproducción de audio',
    androidNotificationOngoing: true,
  );
  await Firebase.initializeApp(options: firebaseOptions);
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(const PlayerApp());
}

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsService.instance,
        builder: (_, __) => MaterialApp(
          title: 'Reproductor',
          debugShowCheckedModeBanner: false,
          theme: SettingsService.instance.theme,
          home: const SplashScreen(),
        ),
      );
}
