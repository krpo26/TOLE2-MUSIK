import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/player_service.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});
  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final eq = PlayerService.instance.equalizer;
  AndroidEqualizerParameters? _params;
  List<double> _gains = [];
  bool _enabled = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('eq_enabled') ?? false;
    try {
      PlayerService.instance.player; // asegura que el reproductor exista
      final p = await eq.parameters.timeout(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _params = p;
        _gains = p.bands.map((b) => b.gain).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('eq_enabled', _enabled);
    await p.setStringList('eq_gains', _gains.map((g) => g.toString()).toList());
  }

  void _preset(double Function(double t) profile) {
    final params = _params!;
    final n = params.bands.length;
    for (var i = 0; i < n; i++) {
      final t = n > 1 ? i / (n - 1) : 0.5;
      final g = (profile(t) * params.maxDecibels)
          .clamp(params.minDecibels, params.maxDecibels)
          .toDouble();
      _gains[i] = g;
      params.bands[i].setGain(g);
    }
    setState(() {});
    _save();
  }

  String _freq(double f) =>
      f >= 1000 ? '${(f / 1000).toStringAsFixed(1)}k' : '${f.round()}';

  @override
  Widget build(BuildContext context) {
    final params = _params;
    return Scaffold(
      appBar: AppBar(title: const Text('Ecualizador')),
      body: _failed
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Primero reproduce una canción para activar el ecualizador.',
                  textAlign: TextAlign.center),
            ))
          : params == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  SwitchListTile(
                    title: const Text('Activar ecualizador'),
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
                      eq.setEnabled(v);
                      _save();
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ActionChip(label: const Text('Plano'), onPressed: () => _preset((t) => 0)),
                    ActionChip(label: const Text('Bajos'), onPressed: () => _preset((t) => (1 - t) * (1 - t) * 0.8)),
                    ActionChip(label: const Text('Agudos'), onPressed: () => _preset((t) => t * t * 0.8)),
                    ActionChip(label: const Text('Rock'), onPressed: () => _preset((t) => (2 * t - 1).abs() * 0.6 - 0.1)),
                    ActionChip(
                        label: const Text('Voz'),
                        onPressed: () => _preset((t) =>
                            (0.6 * (1 - ((t - 0.55) * 2.2).abs()))
                                .clamp(-0.3, 1.0)
                                .toDouble())),
                  ]),
                  const SizedBox(height: 16),
                  for (var i = 0; i < params.bands.length; i++)
                    Row(children: [
                      SizedBox(
                        width: 48,
                        child: Text('${_freq(params.bands[i].centerFrequency)} Hz',
                            style: const TextStyle(fontSize: 11)),
                      ),
                      Expanded(
                        child: Slider(
                          min: params.minDecibels,
                          max: params.maxDecibels,
                          value: _gains[i]
                              .clamp(params.minDecibels, params.maxDecibels)
                              .toDouble(),
                          onChanged: _enabled
                              ? (v) {
                                  setState(() => _gains[i] = v);
                                  params.bands[i].setGain(v);
                                }
                              : null,
                          onChangeEnd: (_) => _save(),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${_gains[i].toStringAsFixed(1)} dB',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ]),
                ]),
    );
  }
}
