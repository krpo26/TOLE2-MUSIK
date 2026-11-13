import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/settings_service.dart';
import '../widgets/backup_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _thumb(String? path, {double w = 72, double h = 72}) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: path == null
            ? Container(
                width: w,
                height: h,
                color: Colors.grey.withAlpha(60),
                child: const Icon(Icons.image_outlined))
            : Image.file(File(path),
                width: w,
                height: h,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    SizedBox(width: w, height: h, child: const Icon(Icons.broken_image))),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _imageRow(String title, String subtitle, String? path,
          VoidCallback pick, VoidCallback clear) =>
      ListTile(
        leading: _thumb(path),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.photo_library), onPressed: pick),
          if (path != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: clear),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizar')),
      body: ListenableBuilder(
        listenable: s,
        builder: (_, __) => ListView(children: [
          _section('Tema'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeStyle>(
              segments: const [
                ButtonSegment(value: ThemeStyle.oscuro, label: Text('Oscuro')),
                ButtonSegment(value: ThemeStyle.claro, label: Text('Claro')),
                ButtonSegment(value: ThemeStyle.amoled, label: Text('AMOLED')),
              ],
              selected: {s.style},
              onSelectionChanged: (v) => s.setStyle(v.first),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final t in appThemes)
                GestureDetector(
                  onTap: () => s.setTheme(t.id),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: t.color,
                      child: s.themeId == t.id
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(t.name, style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ]),
          ),
          _section('Imágenes'),
          _imageRow('Logo de inicio', 'Se muestra al abrir la app', s.logoPath,
              s.pickLogo, s.clearLogo),
          _imageRow('Imagen principal', 'Banner arriba de la biblioteca',
              s.heroPath, s.pickHero, s.clearHero),
          _section('Imágenes entre canciones'),
          SwitchListTile(
            title: const Text('Mostrar entre canciones'),
            value: s.showBanners,
            onChanged: s.setShowBanners,
          ),
          ListTile(
            title: Text('Una imagen cada ${s.bannerEvery} canciones'),
            subtitle: Slider(
              min: 3,
              max: 20,
              divisions: 17,
              value: s.bannerEvery.toDouble(),
              label: '${s.bannerEvery}',
              onChanged: (v) => s.setBannerEvery(v.round()),
            ),
          ),
          for (var i = 0; i < s.banners.length; i++)
            ListTile(
              leading: _thumb(s.banners[i], w: 110, h: 56),
              title: Text('Imagen ${i + 1}'),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => s.removeBanner(i)),
            ),
          ListTile(
            leading: const Icon(Icons.add_photo_alternate),
            title: const Text('Agregar imagen'),
            subtitle: const Text('Se muestran en orden y se repiten'),
            onTap: s.addBanner,
          ),
          _section('Reproducción'),
          ListTile(
            title: Text(s.fadeSeconds == 0
                ? 'Fundido de entrada y salida: desactivado'
                : 'Fundido de entrada y salida: ${s.fadeSeconds} s'),
            subtitle: Slider(
              min: 0,
              max: 8,
              divisions: 8,
              value: s.fadeSeconds.toDouble(),
              label: '${s.fadeSeconds} s',
              onChanged: (v) => s.setFade(v.round()),
            ),
          ),
          SwitchListTile(
            title: const Text('Saltar silencios'),
            subtitle: const Text('Se salta los tramos mudos de las pistas'),
            value: s.skipSilence,
            onChanged: s.setSkipSilence,
          ),
          SwitchListTile(
            title: const Text('Barra de onda en "Reproduciendo"'),
            value: s.waveformSeek,
            onChanged: s.setWaveform,
          ),
          SwitchListTile(
            title: const Text('Ocultar audios de WhatsApp'),
            subtitle: const Text('No aparecen en la biblioteca ni se reproducen'),
            value: s.hideWhatsapp,
            onChanged: s.setHideWhatsapp,
          ),
          _section('Segundo plano'),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Evitar que Android corte la música'),
            subtitle: const Text('Permite que TOLE2 ignore el ahorro de batería'),
            onTap: () => Permission.ignoreBatteryOptimizations.request(),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Notificación con controles'),
            subtitle: const Text('Abre los ajustes de la app para permitir notificaciones'),
            onTap: openAppSettings,
          ),
          _section('Respaldo en la nube'),
          const BackupCard(),
          _section('Carpetas ocultas'),
          if (s.hiddenFolders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                  'Ninguna. Mantén presionada una carpeta en la pestaña Carpetas para ocultarla.',
                  style: TextStyle(fontSize: 12)),
            ),
          for (final h in s.hiddenFolders)
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: Text(h, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: TextButton(
                  onPressed: () => s.unhideFolder(h), child: const Text('Mostrar')),
            ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
