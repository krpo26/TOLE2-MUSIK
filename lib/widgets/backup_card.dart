import 'package:flutter/material.dart';
import '../services/cloud_backup.dart';
import '../services/settings_service.dart';
import 'dialogs.dart';

class BackupCard extends StatefulWidget {
  const BackupCard({super.key});
  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  final _c = TextEditingController(text: SettingsService.instance.backupCode);
  bool _busy = false;
  String? _msg;

  String? _code() {
    final c = _c.text.trim();
    if (c.length < 6) {
      setState(() => _msg = 'Usa un código de al menos 6 caracteres.');
      return null;
    }
    SettingsService.instance.setBackupCode(c);
    return c;
  }

  Future<void> _run(Future<String> Function() job) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final m = await job();
      if (mounted) setState(() => _msg = m);
    } catch (e) {
      if (mounted) setState(() => _msg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Guarda tus favoritos, listas e historial. Con el mismo código '
              'puedes recuperarlos en otro celular o tras reinstalar.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            decoration: const InputDecoration(
              labelText: 'Código de respaldo (es tu contraseña)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Respaldar'),
                onPressed: _busy
                    ? null
                    : () {
                        final c = _code();
                        if (c == null) return;
                        _run(() async {
                          await CloudBackup.save(c);
                          return 'Respaldo guardado.';
                        });
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_download),
                label: const Text('Restaurar'),
                onPressed: _busy
                    ? null
                    : () async {
                        final c = _code();
                        if (c == null) return;
                        if (!await confirm(context,
                            'Esto reemplaza los favoritos, listas e historial de este celular. ¿Continuar?')) {
                          return;
                        }
                        _run(() async => await CloudBackup.restore(c)
                            ? 'Restaurado correctamente.'
                            : 'No hay un respaldo con ese código.');
                      },
              ),
            ),
          ]),
          if (_busy)
            const Padding(
                padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          if (_msg != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
        ]),
      );
}
