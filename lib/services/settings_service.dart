import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final String id, name;
  final Color color;
  const AppTheme(this.id, this.name, this.color);
}

const appThemes = [
  AppTheme('naranja', 'Naranja', Color(0xFFFF9800)),
  AppTheme('azul', 'Océano', Color(0xFF1E88E5)),
  AppTheme('verde', 'Verde', Color(0xFF43A047)),
  AppTheme('violeta', 'Violeta', Color(0xFF8E24AA)),
  AppTheme('rojo', 'Rojo', Color(0xFFE53935)),
  AppTheme('rosa', 'Rosa', Color(0xFFD81B60)),
  AppTheme('turquesa', 'Turquesa', Color(0xFF00ACC1)),
];

enum ThemeStyle { oscuro, claro, amoled }

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final instance = SettingsService._();

  late SharedPreferences _p;
  String themeId = 'naranja';
  ThemeStyle style = ThemeStyle.oscuro;
  String? logoPath, heroPath;
  List<String> banners = [];
  int bannerEvery = 8;
  bool showBanners = true;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeId = _p.getString('themeId') ?? 'naranja';
    style = ThemeStyle.values[(_p.getInt('style') ?? 0).clamp(0, 2)];
    logoPath = _existing(_p.getString('logoPath'));
    heroPath = _existing(_p.getString('heroPath'));
    banners = (_p.getStringList('banners') ?? [])
        .where((f) => File(f).existsSync())
        .toList();
    bannerEvery = _p.getInt('bannerEvery') ?? 8;
    showBanners = _p.getBool('showBanners') ?? true;
  }

  String? _existing(String? p) => (p != null && File(p).existsSync()) ? p : null;

  Color get accent =>
      appThemes.firstWhere((t) => t.id == themeId, orElse: () => appThemes.first).color;

  ThemeData get theme {
    final dark = style != ThemeStyle.claro;
    var cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    if (style == ThemeStyle.amoled) cs = cs.copyWith(surface: Colors.black);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: style == ThemeStyle.amoled
          ? Colors.black
          : (dark ? const Color(0xFF121212) : null),
    );
  }

  Future<void> _save() async {
    await _p.setString('themeId', themeId);
    await _p.setInt('style', style.index);
    logoPath == null ? await _p.remove('logoPath') : await _p.setString('logoPath', logoPath!);
    heroPath == null ? await _p.remove('heroPath') : await _p.setString('heroPath', heroPath!);
    await _p.setStringList('banners', banners);
    await _p.setInt('bannerEvery', bannerEvery);
    await _p.setBool('showBanners', showBanners);
    notifyListeners();
  }

  Future<void> setTheme(String id) async { themeId = id; await _save(); }
  Future<void> setStyle(ThemeStyle s) async { style = s; await _save(); }
  Future<void> setBannerEvery(int n) async { bannerEvery = n; await _save(); }
  Future<void> setShowBanners(bool v) async { showBanners = v; await _save(); }

  /// Elige una imagen de la galería y la copia a la carpeta de la app.
  Future<String?> _pick(String kind) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    final src = res?.files.single.path;
    if (src == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final ext = src.contains('.') ? src.split('.').last : 'jpg';
    final dest = '${dir.path}/${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(src).copy(dest);
    return dest;
  }

  Future<void> _delete(String? p) async {
    if (p == null) return;
    try { await File(p).delete(); } catch (_) {}
  }

  Future<void> pickLogo() async {
    final f = await _pick('logo');
    if (f == null) return;
    await _delete(logoPath);
    logoPath = f;
    await _save();
  }

  Future<void> clearLogo() async { await _delete(logoPath); logoPath = null; await _save(); }

  Future<void> pickHero() async {
    final f = await _pick('hero');
    if (f == null) return;
    await _delete(heroPath);
    heroPath = f;
    await _save();
  }

  Future<void> clearHero() async { await _delete(heroPath); heroPath = null; await _save(); }

  Future<void> addBanner() async {
    final f = await _pick('banner');
    if (f == null) return;
    banners = [...banners, f];
    await _save();
  }

  Future<void> removeBanner(int i) async {
    await _delete(banners[i]);
    banners = [...banners]..removeAt(i);
    await _save();
  }
}
