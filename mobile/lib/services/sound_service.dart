import 'dart:async' show unawaited;
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SoundService {
  SoundService._();
  static final SoundService _i = SoundService._();

  static const int _sr = 22050;

  late Uint8List _tickNormal;
  late Uint8List _tickCritique;
  late Uint8List _tickUrgent;
  late Uint8List _bonneReponse;
  late Uint8List _mauvaiseReponse;
  late Uint8List _gong;
  late Uint8List _serie5;
  late Uint8List _serie10;
  late Uint8List _serie15;
  late Uint8List _serie20;
  late Uint8List _perfect;
  late Uint8List _bombard;

  bool _ready = false;
  final AudioPlayer _tickPlayer = AudioPlayer();

  // ─── API statique (compatible avec l'existant) ───────────────────────────

  static Future<void> initialiser() => _i._init();

  static Future<void> jouerTick(int tempsRestant) => _i._tick(tempsRestant);
  static Future<void> stopTick() => _i._tickPlayer.stop();

  static Future<void> reponseCorrecte() => _i._play(_i._bonneReponse);
  static Future<void> reponseIncorrecte() => _i._play(_i._mauvaiseReponse);
  static Future<void> jouerGong() => _i._play(_i._gong);

  static Future<void> serie(int palier) {
    switch (palier) {
      case 5:  return _i._play(_i._serie5);
      case 10: return _i._play(_i._serie10);
      case 15: return _i._play(_i._serie15);
      case 20: return _i._play(_i._serie20);
      default: return Future.value();
    }
  }

  static Future<void> perfect() => _i._play(_i._perfect);

  static Future<void> bombardement(int palier) => _i._play(_i._bombard);

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> _init() async {
    if (_ready || kIsWeb) return;
    _ready = true;
    await _tickPlayer.setReleaseMode(ReleaseMode.stop);

    _tickNormal      = _wav(_tone(440,  0.055, vol: 0.28, fadeMs: 25));
    _tickCritique    = _wav(_tone(660,  0.055, vol: 0.50, fadeMs: 20));
    _tickUrgent      = _wav(_tone(880,  0.040, vol: 0.70, fadeMs: 12));
    _bonneReponse    = _wav(_arpeggio([523.25, 659.25, 783.99], [0.09, 0.09, 0.22], 0.55));
    _mauvaiseReponse = _wav(_buzzer());
    _gong            = _wav(_buildGong());
    _serie5          = _wav(_arpeggio([523.25, 659.25, 783.99], [0.07, 0.07, 0.18], 0.45));
    _serie10         = _wav(_arpeggio([523.25, 659.25, 783.99, 1046.5], [0.07, 0.07, 0.07, 0.22], 0.55));
    _serie15         = _wav(_arpeggio([659.25, 783.99, 1046.5, 1318.5], [0.07, 0.07, 0.07, 0.25], 0.60));
    _serie20         = _wav(_arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.5], [0.06, 0.06, 0.06, 0.06, 0.28], 0.65));
    _perfect         = _wav(_buildFanfare());
    _bombard         = _wav(_arpeggio([440, 554.37, 659.25, 880], [0.08, 0.08, 0.08, 0.28], 0.60));
  }

  Future<void> _tick(int tempsRestant) async {
    if (!_ready) return;
    final b = tempsRestant <= 3 ? _tickUrgent
             : tempsRestant <= 7 ? _tickCritique
             : _tickNormal;
    await _tickPlayer.stop();
    unawaited(_tickPlayer.play(BytesSource(b)));
  }

  Future<void> _play(Uint8List data) async {
    if (!_ready) return;
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.release);
    unawaited(p.play(BytesSource(data)));
  }

  // ─── Synthèse WAV ────────────────────────────────────────────────────────

  List<int> _tone(double freq, double dur, {double vol = 0.5, int fadeMs = 30}) {
    final n  = (_sr * dur).round();
    final fo = (_sr * fadeMs / 1000).round().clamp(1, n);
    final fi = (_sr * 0.008).round().clamp(1, n);
    final out = List<int>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double a = sin(2 * pi * freq * i / _sr);
      if (i < fi) { a *= i / fi; }
      if (i > n - fo) { a *= (n - i) / fo; }
      out[i] = (a * vol * 32767).round().clamp(-32768, 32767);
    }
    return out;
  }

  List<int> _arpeggio(List<double> freqs, List<double> durs, double vol) {
    final out = <int>[];
    for (int k = 0; k < freqs.length; k++) {
      out.addAll(_tone(freqs[k], durs[k], vol: vol + k * 0.03, fadeMs: 25));
    }
    return out;
  }

  List<int> _buzzer() {
    const dur = 0.22;
    final n   = (_sr * dur).round();
    final out = List<int>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t    = i / _sr;
      final freq = (350.0 - 700.0 * t).clamp(150.0, 350.0);
      final env  = (1.0 - t / dur * 1.4).clamp(0.0, 1.0);
      out[i] = (sin(2 * pi * freq * t) * env * 0.65 * 32767).round().clamp(-32768, 32767);
    }
    return out;
  }

  List<int> _buildGong() {
    const dur       = 2.0;
    final n         = (_sr * dur).round();
    const harmonics = [110.0, 176.0, 297.0, 473.0];
    const weights   = [0.50,  0.26,  0.14,  0.10];
    const decays    = [1.2,   2.0,   3.5,   5.5];
    final out = List<int>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _sr;
      double s = 0;
      for (int h = 0; h < harmonics.length; h++) {
        s += weights[h] * sin(2 * pi * harmonics[h] * t) * exp(-decays[h] * t);
      }
      if (t < 0.005) { s *= t / 0.005; }
      out[i] = (s * 32767).round().clamp(-32768, 32767);
    }
    return out;
  }

  List<int> _buildFanfare() {
    return [
      ..._tone(523.25, 0.08, vol: 0.50, fadeMs: 20),
      ..._tone(659.25, 0.08, vol: 0.55, fadeMs: 20),
      ..._tone(783.99, 0.08, vol: 0.60, fadeMs: 20),
      ..._tone(1046.5, 0.08, vol: 0.65, fadeMs: 20),
      ..._tone(1318.5, 0.30, vol: 0.70, fadeMs: 60),
    ];
  }

  Uint8List _wav(List<int> samples) {
    final ds  = samples.length * 2;
    final buf = ByteData(44 + ds);
    void s4(int off, String s) {
      for (int i = 0; i < 4; i++) { buf.setUint8(off + i, s.codeUnitAt(i)); }
    }
    s4(0, 'RIFF'); buf.setUint32(4, 36 + ds, Endian.little);
    s4(8, 'WAVE'); s4(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, _sr, Endian.little);
    buf.setUint32(28, _sr * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    s4(36, 'data'); buf.setUint32(40, ds, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return buf.buffer.asUint8List();
  }
}
