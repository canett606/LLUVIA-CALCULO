import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

/// Servicio de audio para efectos de sonido del juego.
/// Genera tonos sintéticos sin necesidad de assets de audio.
class AudioService {
  AudioPlayer? _hitPlayer;
  AudioPlayer? _missPlayer;
  AudioPlayer? _tapPlayer;
  
  bool _initialized = false;
  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;
  
  set soundEnabled(bool value) {
    _soundEnabled = value;
  }

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _hitPlayer = AudioPlayer();
      _missPlayer = AudioPlayer();
      _tapPlayer = AudioPlayer();
      
      // Configurar bajo volumen para evitar molestias
      await _hitPlayer?.setVolume(0.5);
      await _missPlayer?.setVolume(0.4);
      await _tapPlayer?.setVolume(0.3);
      
      _initialized = true;
    } catch (e) {
      print('Error initializing audio: $e');
    }
  }

  /// Reproduce sonido de acierto (tono agudo ascendente)
  Future<void> playHit() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Usar tono generado via URL de data
      // Frecuencia alta para acierto
      await _hitPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 880, durationMs: 150)),
      );
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  /// Reproduce sonido de fallo (tono grave descendente)
  Future<void> playMiss() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      await _missPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 220, durationMs: 200)),
      );
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  /// Reproduce sonido de tecla presionada
  Future<void> playTap() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      await _tapPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 440, durationMs: 50)),
      );
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  /// Reproduce sonido de victoria/logro
  Future<void> playVictory() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Secuencia de tonos ascendentes
      await _hitPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 523, durationMs: 100)),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      await _hitPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 659, durationMs: 100)),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      await _hitPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 784, durationMs: 200)),
      );
    } catch (e) {
      // Silenciar errores
    }
  }

  /// Reproduce sonido de game over
  Future<void> playGameOver() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Secuencia descendente
      await _missPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 392, durationMs: 150)),
      );
      await Future.delayed(const Duration(milliseconds: 150));
      await _missPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 330, durationMs: 150)),
      );
      await Future.delayed(const Duration(milliseconds: 150));
      await _missPlayer?.play(
        UrlSource(_generateToneDataUrl(frequency: 262, durationMs: 300)),
      );
    } catch (e) {
      // Silenciar errores
    }
  }

  /// Genera una URL de datos con un tono WAV simple
  String _generateToneDataUrl({
    required double frequency,
    required int durationMs,
  }) {
    // Generar WAV en memoria
    final sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    
    // Header WAV
    final bytes = <int>[];
    
    // RIFF header
    bytes.addAll('RIFF'.codeUnits);
    _addInt32LE(bytes, 36 + numSamples * 2); // file size - 8
    bytes.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    bytes.addAll('fmt '.codeUnits);
    _addInt32LE(bytes, 16); // chunk size
    _addInt16LE(bytes, 1); // audio format (PCM)
    _addInt16LE(bytes, 1); // num channels
    _addInt32LE(bytes, sampleRate); // sample rate
    _addInt32LE(bytes, sampleRate * 2); // byte rate
    _addInt16LE(bytes, 2); // block align
    _addInt16LE(bytes, 16); // bits per sample
    
    // data chunk
    bytes.addAll('data'.codeUnits);
    _addInt32LE(bytes, numSamples * 2);
    
    // Generate samples with envelope
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      
      // Simple ADSR envelope
      double envelope;
      final attackSamples = sampleRate * 0.01;
      final releaseSamples = sampleRate * 0.1;
      
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i > numSamples - releaseSamples) {
        envelope = (numSamples - i) / releaseSamples;
      } else {
        envelope = 1.0;
      }
      
      // Sine wave
      final sample = (sin(2 * pi * frequency * t) * 0.3 * envelope * 32767).round();
      _addInt16LE(bytes, sample.clamp(-32768, 32767));
    }
    
    // Convert to base64 data URL
    final base64 = _bytesToBase64(bytes);
    return 'data:audio/wav;base64,$base64';
  }

  void _addInt16LE(List<int> bytes, int value) {
    bytes.add(value & 0xFF);
    bytes.add((value >> 8) & 0xFF);
  }

  void _addInt32LE(List<int> bytes, int value) {
    bytes.add(value & 0xFF);
    bytes.add((value >> 8) & 0xFF);
    bytes.add((value >> 16) & 0xFF);
    bytes.add((value >> 24) & 0xFF);
  }

  String _bytesToBase64(List<int> bytes) {
    const base64Chars = 
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    
    final result = StringBuffer();
    
    for (var i = 0; i < bytes.length; i += 3) {
      final b1 = bytes[i];
      final b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      
      result.write(base64Chars[b1 >> 2]);
      result.write(base64Chars[((b1 & 3) << 4) | (b2 >> 4)]);
      result.write(i + 1 < bytes.length 
        ? base64Chars[((b2 & 15) << 2) | (b3 >> 6)] 
        : '=');
      result.write(i + 2 < bytes.length 
        ? base64Chars[b3 & 63] 
        : '=');
    }
    
    return result.toString();
  }

  Future<void> dispose() async {
    await _hitPlayer?.dispose();
    await _missPlayer?.dispose();
    await _tapPlayer?.dispose();
    _initialized = false;
  }
}
