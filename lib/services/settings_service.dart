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
  int fadeSeconds = 0;
  bool skipSilence = false;
  bool waveformSeek = true;
  int winampSkin = 0;
  String backupCode = '';
  bool hideWhatsapp = true;
  bool batteryAsked = false;
  List<String> hiddenFolders = [];

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
    fadeSeconds = _p.getInt('fadeSeconds') ?? 0;
    skipSilence = _p.getBool('skipSilence') ?? false;
    waveformSeek = _p.getBool('waveformSeek') ?? true;
    winampSkin = _p.getInt('winampSkin') ?? 0;
    backupCode = _p.getString('backupCode') ?? '';
    hideWhatsapp = _p.getBool('hideWhatsapp') ?? true;
    batteryAsked = _p.getBool('batteryAsked') ?? false;
    hiddenFolders = _p.getStringList('hiddenFolders') ?? [];
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
    await _p.setInt('fadeSeconds', fadeSeconds);
    await _p.setBool('skipSilence', skipSilence);
    await _p.setBool('waveformSeek', waveformSeek);
    await _p.setInt('winampSkin', winampSkin);
    await _p.setString('backupCode', backupCode);
    await _p.setBool('hideWhatsapp', hideWhatsapp);
    await _p.setBool('batteryAsked', batteryAsked);
    await _p.setStringList('hiddenFolders', hiddenFolders);
    notifyListeners();
  }

  Future<void> setTheme(String id) async { themeId = id; await _save(); }
  Future<void> setStyle(ThemeStyle s) async { style = s; await _save(); }
  Future<void> setBannerEvery(int n) async { bannerEvery = n; await _save(); }
  Future<void> setShowBanners(bool v) async { showBanners = v; await _save(); }
  Future<void> setFade(int s) async { fadeSeconds = s; await _save(); }
  Future<void> setSkipSilence(bool v) async { skipSilence = v; await _save(); }
  Future<void> setWaveform(bool v) async { waveformSeek = v; await _save(); }
  Future<void> setWinampSkin(int v) async { winampSkin = v; await _save(); }
  Future<void> setBackupCode(String v) async { backupCode = v; await _save(); }
  Future<void> setHideWhatsapp(bool v) async { hideWhatsapp = v; await _save(); }
  Future<void> setBatteryAsked(bool v) async { batteryAsked = v; await _save(); }
  Future<void> hideFolder(String path) async {
    if (!hiddenFolders.contains(path)) {
      hiddenFolders = [...hiddenFolders, path];
      await _save();
    }
  }
  Future<void> unhideFolder(String path) async {
    hiddenFolders = hiddenFolders.where((x) => x != path).toList();
    await _save();
  }

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
