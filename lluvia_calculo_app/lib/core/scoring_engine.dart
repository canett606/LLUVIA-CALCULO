import '../models/game_state.dart';

/// Resultado de evaluar una respuesta
class AnswerResult {
  final bool correct;
  final int pointsGained;
  final int newStreak;
  final String message;
  final FallingDrop? hitDrop;
  final int bonusPoints;

  const AnswerResult({
    required this.correct,
    required this.pointsGained,
    required this.newStreak,
    required this.message,
    this.hitDrop,
    this.bonusPoints = 0,
  });
}

/// Motor de puntuación que calcula puntos basados en:
/// - Tier/complejidad de la operación
/// - Tiempo de respuesta
/// - Racha actual
/// - Modo de juego
class ScoringEngine {
  // Puntos base por tier
  static const Map<int, int> _basePointsByTier = {
    1: 5,
    2: 8,
    3: 12,
    4: 16,
    5: 20,
  };

  // Bonus por respuesta rápida (ms)
  static const int _fastThresholdMs = 1500;
  static const int _mediumThresholdMs = 3000;
  static const int _fastBonus = 5;
  static const int _mediumBonus = 2;

  // Bonus por racha
  static const int _streakBonusCap = 25;

  /// Evalúa una respuesta del jugador
  AnswerResult evaluateAnswer({
    required int userAnswer,
    required GameState state,
    required GameMode mode,
  }) {
    // Buscar gotas con la respuesta correcta
    final matchingDrops = state.activeDrops
        .where((drop) => drop.operation.answer == userAnswer)
        .toList();

    if (matchingDrops.isEmpty) {
      return AnswerResult(
        correct: false,
        pointsGained: 0,
        newStreak: 0,
        message: 'No hay ninguna gota con resultado $userAnswer.',
      );
    }

    // Tomar la gota más cercana al suelo (más urgente)
    matchingDrops.sort((a, b) => b.y.compareTo(a.y));
    final hitDrop = matchingDrops.first;
    final operation = hitDrop.operation;
    final responseTimeMs = hitDrop.responseTimeMs;

    // Calcular puntos base
    int basePoints = _basePointsByTier[operation.tier] ?? 10;
    
    // Ajustar por modo
    basePoints = _adjustPointsForMode(basePoints, mode);

    // Bonus por velocidad
    int speedBonus = 0;
    if (responseTimeMs < _fastThresholdMs) {
      speedBonus = _fastBonus;
    } else if (responseTimeMs < _mediumThresholdMs) {
      speedBonus = _mediumBonus;
    }

    // Bonus por racha
    final newStreak = state.streak + 1;
    final streakBonus = (newStreak ~/ 3).clamp(0, _streakBonusCap);

    // Bonus por complejidad
    final complexityBonus = (operation.complexity - 1) * 2;

    final totalBonus = speedBonus + streakBonus + complexityBonus;
    final totalPoints = basePoints + totalBonus;

    // Mensaje de feedback
    String message = '✓ ${operation.expression} = ${operation.answer}';
    if (totalBonus > 0) {
      message += ' (+$totalPoints pts)';
    }
    if (newStreak >= 5 && newStreak % 5 == 0) {
      message += ' 🔥 Racha de $newStreak!';
    }

    return AnswerResult(
      correct: true,
      pointsGained: totalPoints,
      newStreak: newStreak,
      message: message,
      hitDrop: hitDrop,
      bonusPoints: totalBonus,
    );
  }

  int _adjustPointsForMode(int basePoints, GameMode mode) {
    switch (mode) {
      case GameMode.aprendizaje:
        return basePoints; // Normal
      case GameMode.porTiempo:
        return (basePoints * 1.2).round(); // Bonus por presión
      case GameMode.porPuntuacion:
        return basePoints;
      case GameMode.supervivencia:
        return (basePoints * 1.3).round(); // Mayor recompensa por riesgo
      case GameMode.porNiveles:
        return basePoints;
    }
  }

  /// Calcula pérdida por gota que llega al suelo
  MissResult calculateMiss({
    required FallingDrop drop,
    required GameState state,
  }) {
    return MissResult(
      livesLost: 1,
      streakReset: true,
      message: 'Se escapó ${drop.operation.expression}. '
               'Resultado: ${drop.operation.answer}',
    );
  }

  /// Determina si el juego ha terminado
  GameEndResult? checkGameEnd(GameState state) {
    // Verificar vidas
    if (state.lives <= 0) {
      return GameEndResult(
        reason: GameEndReason.noLives,
        finalScore: state.score,
        message: '¡Fin del juego! Sin vidas.',
        victory: false,
      );
    }

    // Verificar tiempo (modo porTiempo)
    if (state.mode == GameMode.porTiempo && 
        state.timeRemaining != null &&
        state.timeRemaining!.inSeconds <= 0) {
      return GameEndResult(
        reason: GameEndReason.timeUp,
        finalScore: state.score,
        message: '¡Tiempo! Puntuación final: ${state.score}',
        victory: true, // Completar el tiempo es victoria
      );
    }

    // Verificar puntuación objetivo (modo porPuntuacion)
    if (state.mode == GameMode.porPuntuacion && 
        state.targetScore != null &&
        state.score >= state.targetScore!) {
      return GameEndResult(
        reason: GameEndReason.targetReached,
        finalScore: state.score,
        message: '¡Victoria! Alcanzaste ${state.targetScore} puntos.',
        victory: true,
      );
    }

    return null; // Juego continúa
  }

  /// Calcula bonus de fin de partida
  int calculateEndGameBonus(GameState state) {
    int bonus = 0;
    
    // Bonus por vidas restantes
    bonus += state.lives * 5;
    
    // Bonus por precisión
    if (state.sessionAccuracy >= 0.9) {
      bonus += 50;
    } else if (state.sessionAccuracy >= 0.75) {
      bonus += 25;
    }
    
    // Bonus por racha máxima alcanzada (aproximado por racha actual)
    bonus += state.streak * 2;
    
    return bonus;
  }
}

/// Resultado de una gota perdida
class MissResult {
  final int livesLost;
  final bool streakReset;
  final String message;

  const MissResult({
    required this.livesLost,
    required this.streakReset,
    required this.message,
  });
}

/// Razón de fin de partida
enum GameEndReason {
  noLives,
  timeUp,
  targetReached,
  userQuit,
}

/// Resultado de fin de partida
class GameEndResult {
  final GameEndReason reason;
  final int finalScore;
  final String message;
  final bool victory;

  const GameEndResult({
    required this.reason,
    required this.finalScore,
    required this.message,
    required this.victory,
  });
}
