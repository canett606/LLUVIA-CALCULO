/// Ritmo de caída elegido en opciones.
///
/// 1 es la velocidad de siempre. Por debajo, las operaciones tardan más
/// en llegar abajo y aparecen con más espacio entre unas y otras.
class FallPace {
  final double factor;
  final String label;
  final String hint;

  const FallPace({
    required this.factor,
    required this.label,
    required this.hint,
  });

  static const muyLenta = FallPace(
    factor: 0.45,
    label: 'Muy lenta',
    hint: 'Mucho más tiempo para pensar',
  );
  static const lenta = FallPace(
    factor: 0.7,
    label: 'Lenta',
    hint: 'Un poco más de tiempo para pensar',
  );
  static const normal = FallPace(
    factor: 1.0,
    label: 'Normal',
    hint: 'La velocidad de siempre',
  );
  static const rapida = FallPace(
    factor: 1.35,
    label: 'Rápida',
    hint: 'Caen más deprisa',
  );

  static const choices = <FallPace>[muyLenta, lenta, normal, rapida];

  static const String settingsKey = 'fallSpeed';

  static FallPace nearest(double value) {
    var best = choices.first;
    var bestDist = (value - best.factor).abs();
    for (final choice in choices.skip(1)) {
      final dist = (value - choice.factor).abs();
      if (dist < bestDist) {
        best = choice;
        bestDist = dist;
      }
    }
    return best;
  }

  static FallPace fromSettings(Map<String, dynamic> settings) {
    final raw = settings[settingsKey];
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null) return normal;
    return nearest(value);
  }

  /// Velocidad de una gota, en unidades por segundo, con este ritmo.
  double applySpeed(double speed) {
    return (speed * factor).clamp(0.025, 0.9);
  }

  /// Milisegundos entre operaciones. Más lento implica más espera.
  int applyInterval(num intervalMs) {
    return (intervalMs / factor).round().clamp(900, 14000);
  }

  @override
  bool operator ==(Object other) =>
      other is FallPace && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
}
