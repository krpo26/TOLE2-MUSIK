import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';

class _Skin {
  final String name;
  final Color body, lcd, fg, dim, face, light, dark;
  const _Skin(this.name, this.body, this.lcd, this.fg, this.dim, this.face,
      this.light, this.dark);
}

const _skins = [
  _Skin('Clásico', Color(0xFF3A3A48), Color(0xFF05100A), Color(0xFF00E676),
      Color(0xFF00692F), Color(0xFF55556A), Color(0xFF8C8CA3), Color(0xFF1B1B24)),
  _Skin('Ámbar', Color(0xFF3B2F22), Color(0xFF120A00), Color(0xFFFFB300),
      Color(0xFF7A5200), Color(0xFF5E4A33), Color(0xFF9C8466), Color(0xFF1E160D)),
  _Skin('Neón azul', Color(0xFF1F2A44), Color(0xFF020814), Color(0xFF40C4FF),
      Color(0xFF0D5C80), Color(0xFF34476E), Color(0xFF6A84B8), Color(0xFF0E1527)),
  _Skin('Rojo', Color(0xFF3B1F24), Color(0xFF140305), Color(0xFFFF5252),
      Color(0xFF7A1F1F), Color(0xFF5E3338), Color(0xFF9C666D), Color(0xFF1E0E11)),
];

const _mono = 'monospace';

BoxDecoration _raised(_Skin k, {bool active = false}) => BoxDecoration(
      color: active ? k.dim : k.face,
      border: Border(
        top: BorderSide(color: k.light, width: 1.5),
        left: BorderSide(color: k.light, width: 1.5),
        bottom: BorderSide(color: k.dark, width: 1.5),
        right: BorderSide(color: k.dark, width: 1.5),
      ),
    );

BoxDecoration _sunken(_Skin k) => BoxDecoration(
      color: k.lcd,
      border: Border(
        top: BorderSide(color: k.dark, width: 2),
        left: BorderSide(color: k.dark, width: 2),
        bottom: BorderSide(color: k.light, width: 1.5),
        right: BorderSide(color: k.light, width: 1.5),
      ),
    );

class _RBtn extends StatelessWidget {
  final _Skin k;
  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final double w;
  const _RBtn(
      {required this.k,
      required this.child,
      required this.onTap,
      this.active = false,
      this.w = 44});

  @override
  Widget build(BuildContext context) {
    final c = active ? k.fg : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        height: 34,
        alignment: Alignment.center,
        decoration: _raised(k, active: active),
        child: IconTheme(
          data: IconThemeData(color: c, size: 20),
          child: DefaultTextStyle(
            style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: _mono),
            child: child,
          ),
        ),
      ),
    );
  }
}

class WinampScreen extends StatefulWidget {
  const WinampScreen({super.key});
  @override
  State<WinampScreen> createState() => _WinampScreenState();
}

class _WinampScreenState extends State<WinampScreen> {
  bool _showEq = false, _showPl = true, _remaining = false;
  double _vol = PlayerService.instance.master;

  Widget _thin(_Skin k, Widget slider) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: k.fg,
          inactiveTrackColor: k.dark,
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: slider,
      );

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    final svc = PlayerService.instance;
    final p = svc.player;
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) {
        final k = _skins[s.winampSkin.clamp(0, _skins.length - 1)];
        return Scaffold(
          backgroundColor: k.body,
          body: SafeArea(
            child: StreamBuilder<SequenceState?>(
              stream: p.sequenceStateStream,
              builder: (_, snap) {
                final seq = snap.data;
                final tag = seq?.currentSource?.tag;
                final item = tag is MediaItem ? tag : null;
                final total = seq?.sequence.length ?? 0;
                final idx = seq?.currentIndex ?? 0;
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    _titleBar(k, s),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 84,
                      child: Row(children: [
                        Expanded(flex: 5, child: _lcdTime(k, svc, idx, total)),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 6,
                          child: Container(
                            decoration: _sunken(k),
                            padding: const EdgeInsets.all(4),
                            child: StreamBuilder<PlayerState>(
                              stream: p.playerStateStream,
                              builder: (_, st) => _Spectrum(
                                  color: k.fg,
                                  dim: k.dim,
                                  playing: st.data?.playing ?? false),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 30,
                      decoration: _sunken(k),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.centerLeft,
                      child: item == null
                          ? Text('NO HAY PISTA',
                              style: TextStyle(
                                  color: k.dim, fontFamily: _mono, fontSize: 13))
                          : _Marquee(
                              text:
                                  '${idx + 1}. ${item.title} - ${item.artist ?? ''}'
                                  '${item.duration != null ? ' (${fmtDuration(item.duration!)})' : ''}',
                              style: TextStyle(
                                  color: k.fg, fontFamily: _mono, fontSize: 13),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: StreamBuilder(
                          stream: svc.progress,
                          builder: (_, ps) {
                            final pos = ps.data?.pos ?? Duration.zero;
                            final dur = ps.data?.dur ?? Duration.zero;
                            final mx = dur.inMilliseconds.toDouble();
                            return _thin(
                              k,
                              Slider(
                                value: pos.inMilliseconds
                                    .toDouble()
                                    .clamp(0, mx > 0 ? mx : 1),
                                max: mx > 0 ? mx : 1,
                                onChanged: (v) =>
                                    p.seek(Duration(milliseconds: v.round())),
                              ),
                            );
                          },
                        ),
                      ),
                      Icon(Icons.volume_up, size: 16, color: k.fg),
                      Expanded(
                        flex: 2,
                        child: _thin(
                          k,
                          Slider(
                            value: _vol,
                            onChanged: (v) {
                              setState(() => _vol = v);
                              svc.setMaster(v);
                            },
                          ),
                        ),
                      ),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      _RBtn(
                          k: k,
                          onTap: p.seekToPrevious,
                          child: const Icon(Icons.skip_previous)),
                      _RBtn(
                          k: k,
                          onTap: p.play,
                          child: const Icon(Icons.play_arrow)),
                      _RBtn(
                          k: k, onTap: p.pause, child: const Icon(Icons.pause)),
                      _RBtn(
                          k: k,
                          onTap: () {
                            p.pause();
                            p.seek(Duration.zero);
                          },
                          child: const Icon(Icons.stop)),
                      _RBtn(
                          k: k,
                          onTap: p.seekToNext,
                          child: const Icon(Icons.skip_next)),
                      _RBtn(
                          k: k,
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.eject)),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      StreamBuilder<bool>(
                        stream: p.shuffleModeEnabledStream,
                        builder: (_, sh) => _RBtn(
                          k: k,
                          w: 64,
                          active: sh.data ?? false,
                          onTap: () async {
                            final on = !(sh.data ?? false);
                            if (on) await p.shuffle();
                            await p.setShuffleModeEnabled(on);
                          },
                          child: const Text('SHUF'),
                        ),
                      ),
                      StreamBuilder<LoopMode>(
                        stream: p.loopModeStream,
                        builder: (_, lp) {
                          final m = lp.data ?? LoopMode.off;
                          return _RBtn(
                            k: k,
                            w: 64,
                            active: m != LoopMode.off,
                            onTap: () => p.setLoopMode(
                                LoopMode.values[(m.index + 1) % 3]),
                            child: Text(m == LoopMode.one ? 'REP 1' : 'REP'),
                          );
                        },
                      ),
                      _RBtn(
                          k: k,
                          w: 64,
                          active: _showEq,
                          onTap: () => setState(() => _showEq = !_showEq),
                          child: const Text('EQ')),
                      _RBtn(
                          k: k,
                          w: 64,
                          active: _showPl,
                          onTap: () => setState(() => _showPl = !_showPl),
                          child: const Text('PL')),
                    ]),
                    const SizedBox(height: 6),
                    if (_showEq) _WinampEq(k: k),
                    if (_showEq) const SizedBox(height: 6),
                    if (_showPl)
                      Expanded(child: _playlist(k, seq, p))
                    else
                      const Spacer(),
                  ]),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _titleBar(_Skin k, SettingsService s) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [k.light, k.face, k.dark]),
        ),
        child: Row(children: [
          const Text('TOLE2 AMP',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: _mono,
                  letterSpacing: 2)),
          const Spacer(),
          GestureDetector(
            onTap: () => s.setWinampSkin((s.winampSkin + 1) % _skins.length),
            child: Row(children: [
              const Icon(Icons.palette, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(k.name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontFamily: _mono)),
            ]),
          ),
        ]),
      );

  Widget _lcdTime(_Skin k, PlayerService svc, int idx, int total) =>
      GestureDetector(
        onTap: () => setState(() => _remaining = !_remaining),
        child: Container(
          decoration: _sunken(k),
          padding: const EdgeInsets.all(6),
          child: StreamBuilder(
            stream: svc.progress,
            builder: (_, ps) {
              final pos = ps.data?.pos ?? Duration.zero;
              final dur = ps.data?.dur ?? Duration.zero;
              final shown = _remaining
                  ? '-${fmtDuration(dur > pos ? dur - pos : Duration.zero)}'
                  : fmtDuration(pos);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(shown,
                        style: TextStyle(
                            color: k.fg,
                            fontFamily: _mono,
                            fontSize: 34,
                            fontWeight: FontWeight.bold)),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('STEREO',
                        style: TextStyle(
                            color: k.dim, fontSize: 9, fontFamily: _mono)),
                    Text(total > 0 ? '${idx + 1}/$total' : '-/-',
                        style: TextStyle(
                            color: k.dim, fontSize: 9, fontFamily: _mono)),
                  ]),
                ],
              );
            },
          ),
        ),
      );

  Widget _playlist(_Skin k, SequenceState? seq, AudioPlayer p) {
    final list = seq?.sequence ?? const <IndexedAudioSource>[];
    return Container(
      decoration: _sunken(k),
      child: list.isEmpty
          ? Center(
              child: Text('LISTA VACÍA',
                  style: TextStyle(color: k.dim, fontFamily: _mono)))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final t = list[i].tag;
                final mi = t is MediaItem ? t : null;
                final cur = i == seq?.currentIndex;
                final style = TextStyle(
                    color: cur ? Colors.white : k.fg,
                    fontFamily: _mono,
                    fontSize: 12);
                return InkWell(
                  onTap: () => p.seek(Duration.zero, index: i),
                  child: Container(
                    color: cur ? k.dim : null,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text('${i + 1}. ${mi?.title ?? 'Audio'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style),
                      ),
                      Text(
                          mi?.duration != null ? fmtDuration(mi!.duration!) : '',
                          style: style),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------- Texto que se desplaza ----------------
class _Marquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _Marquee({required this.text, required this.style});
  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 12))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, cons) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final w = tp.width;
        final h = (widget.style.fontSize ?? 13) * 1.5;
        if (w <= cons.maxWidth) {
          return Text(widget.text, style: widget.style, maxLines: 1);
        }
        return SizedBox(
          height: h,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-(w + 40) * _c.value, 0),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.text, style: widget.style, maxLines: 1),
                    const SizedBox(width: 40),
                    Text(widget.text, style: widget.style, maxLines: 1),
                  ]),
                ),
              ),
            ),
          ),
        );
      });
}

// ---------------- Visualizador animado ----------------
// Es una animación decorativa (no analiza el audio real).
class _Spectrum extends StatefulWidget {
  final Color color, dim;
  final bool playing;
  const _Spectrum(
      {required this.color, required this.dim, required this.playing});
  @override
  State<_Spectrum> createState() => _SpectrumState();
}

class _SpectrumState extends State<_Spectrum>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      _level += ((widget.playing ? 1.0 : 0.0) - _level) * 0.08;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SpecPainter(_c, () => _level, widget.color, widget.dim),
        size: Size.infinite,
      );
}

class _SpecPainter extends CustomPainter {
  final Animation<double> anim;
  final double Function() level;
  final Color color, dim;
  _SpecPainter(this.anim, this.level, this.color, this.dim)
      : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    const n = 22;
    final slot = size.width / n;
    final bw = slot * 0.7;
    final lv = level();
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final paint = Paint()..color = color;
    final cap = Paint()..color = dim;
    for (var i = 0; i < n; i++) {
      final a = 0.5 + 0.5 * sin(t * (1.8 + 0.31 * i) + i * 1.7);
      final b = 0.55 + 0.45 * sin(t * (0.9 + 0.17 * i) + i * 0.6);
      final v = (a * b * lv * (1.0 - i / (n * 1.8))).clamp(0.03, 1.0).toDouble();
      final h = size.height * v;
      final x = i * slot + (slot - bw) / 2;
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, bw, h), paint);
      canvas.drawRect(Rect.fromLTWH(x, size.height - h - 3, bw, 2), cap);
    }
  }

  @override
  bool shouldRepaint(covariant _SpecPainter old) => true;
}

// ---------------- Ecualizador estilo Winamp ----------------
class _WinampEq extends StatefulWidget {
  final _Skin k;
  const _WinampEq({required this.k});
  @override
  State<_WinampEq> createState() => _WinampEqState();
}

class _WinampEqState extends State<_WinampEq> {
  final eq = PlayerService.instance.equalizer;
  AndroidEqualizerParameters? _params;
  List<double> _gains = [];
  bool _enabled = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final en = prefs.getBool('eq_enabled') ?? false;
    try {
      PlayerService.instance.player;
      final p = await eq.parameters.timeout(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _enabled = en;
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

  void _preset(double Function(double t) f) {
    final params = _params!;
    final n = params.bands.length;
    for (var i = 0; i < n; i++) {
      final t = n > 1 ? i / (n - 1) : 0.5;
      final g = (f(t) * params.maxDecibels)
          .clamp(params.minDecibels, params.maxDecibels)
          .toDouble();
      _gains[i] = g;
      params.bands[i].setGain(g);
    }
    setState(() {});
    _save();
  }

  String _freq(double f) =>
      f >= 1000 ? '${(f / 1000).toStringAsFixed(0)}k' : '${f.round()}';

  @override
  Widget build(BuildContext context) {
    final k = widget.k;
    final params = _params;
    return Container(
      height: 190,
      decoration: _sunken(k),
      padding: const EdgeInsets.all(6),
      child: _failed
          ? Center(
              child: Text('REPRODUCE UNA PISTA PARA ACTIVAR EL EQ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: k.dim, fontFamily: _mono, fontSize: 11)))
          : params == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Row(children: [
                    _RBtn(
                      k: k,
                      w: 44,
                      active: _enabled,
                      onTap: () {
                        setState(() => _enabled = !_enabled);
                        eq.setEnabled(_enabled);
                        _save();
                      },
                      child: const Text('ON'),
                    ),
                    const SizedBox(width: 6),
                    _RBtn(k: k, w: 50, onTap: () => _preset((t) => 0), child: const Text('FLAT')),
                    const SizedBox(width: 6),
                    _RBtn(k: k, w: 50, onTap: () => _preset((t) => (1 - t) * (1 - t) * 0.8), child: const Text('BASS')),
                    const SizedBox(width: 6),
                    _RBtn(k: k, w: 50, onTap: () => _preset((t) => t * t * 0.8), child: const Text('TREB')),
                    const SizedBox(width: 6),
                    _RBtn(k: k, w: 50, onTap: () => _preset((t) => (2 * t - 1).abs() * 0.6 - 0.1), child: const Text('ROCK')),
                  ]),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(children: [
                      for (var i = 0; i < params.bands.length; i++)
                        Expanded(
                          child: Column(children: [
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    activeTrackColor: k.fg,
                                    inactiveTrackColor: k.dim,
                                    thumbColor: Colors.white,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: SliderComponentShape.noOverlay,
                                  ),
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
                              ),
                            ),
                            Text(_freq(params.bands[i].centerFrequency),
                                style: TextStyle(
                                    color: k.fg, fontSize: 9, fontFamily: _mono)),
                          ]),
                        ),
                    ]),
                  ),
                ]),
    );
  }
}
