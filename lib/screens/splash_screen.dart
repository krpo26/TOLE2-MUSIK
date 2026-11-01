import 'dart:io';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final logo = SettingsService.instance.logoPath;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: .85 + .15 * v, child: child),
          ),
          child: logo != null
              ? ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 260, maxHeight: 260),
                  child: Image.file(File(logo), fit: BoxFit.contain),
                )
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.library_music, size: 96, color: cs.primary),
                  const SizedBox(height: 16),
                  const Text('Mi Reproductor',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ]),
        ),
      ),
    );
  }
}
