import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SettingsService.instance.load();
  } catch (_) {}
  runApp(const PlayerApp());
}

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsService.instance,
        builder: (_, __) => MaterialApp(
          title: 'TOLE2',
          debugShowCheckedModeBanner: false,
          theme: SettingsService.instance.theme,
          home: const SplashScreen(),
        ),
      );
}
