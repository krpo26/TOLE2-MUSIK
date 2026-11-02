import 'dart:io';
import 'package:flutter/material.dart';
import '../app_init.dart';
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
    _go();
  }

  Future<void> _go() async {
    // Mínimo 2,2 s de logo; máximo 12 s esperando la inicialización.
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2200)),
      AppInit.run().timeout(const Duration(seconds: 12), onTimeout: () {}),
    ]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custom = SettingsService.instance.logoPath;
    return Scaffold(
      backgroundColor: const Color(0xFF04202A),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: .9 + .1 * v, child: child),
          ),
          child: SizedBox(
            width: double.infinity,
            child: custom != null
                ? Image.file(File(custom), fit: BoxFit.contain)
                : Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
