import 'dart:math';
import '../models/operation.dart';
import '../models/player_profile.dart';
import '../models/game_state.dart';

/// Parámetros adaptativos calculados para un jugador
class AdaptiveParameters {
  final int suggestedTier;
  final double speedMultiplier;
  final double spawnIntervalMs;
  final List<OperationFamily> strongFamilies;
  final List<OperationFamily> weakFamilies;
  final OperationFamily suggestedFamily;
  final bool shouldIncreaseDifficulty;
  final bool shouldDecreaseDifficulty;

  const AdaptiveParameters({
    required this.suggestedTier,
    required this.speedMultiplier,
    required this.spawnIntervalMs,
    required this.strongFamilies,
    required this.weakFamilies,
    required this.suggestedFamily,
    required this.shouldIncreaseDifficulty,
    required this.shouldDecreaseDifficulty,
  });

  factory AdaptiveParameters.forBeginner() => const AdaptiveParameters(
    suggestedTier: 1,
    speedMultiplier: 0.7,
    spawnIntervalMs: 4000,
    strongFamilies: [],
    weakFamilies: [],
    suggestedFamily: OperationFamily.sumas,
    shouldIncreaseDifficulty: false,
    shouldDecreaseDifficulty: false,
  );
}

/// Motor adaptativo que ajusta dificultad según rendimiento del jugador.
/// 
/// Principios clave:
/// - NUNCA saltar más de 1 tier a la vez
/// - Requiere consistencia (varios aciertos seguidos) para subir
/// - Baja rápido si el jugador está luchando
/// - Trackea fortalezas/debilidades por familia Y por tier
/// - Memoria persistente por jugador
class AdaptiveEngine {
  // Umbrales para ajuste de dificultad
  static const double _highAccuracyThreshold = 0.80;
  static const double _lowAccuracyThreshold = 0.50;
  static const int _minSamplesForAdjustment = 5;
  static const int _streakToIncrease = 5;
  static const double _fastResponseMs = 3000;
  
  /// Calcula parámetros adaptativos basados en perfil y sesión actual
  AdaptiveParameters calculate({
    required PlayerProfile profile,
    required GameState currentSession,
    required GameMode mode,
  }) {
    // Para jugadores nuevos, empezar conservador
    if (profile.totalSessions == 0 && currentSession.correctThisSession == 0) {
      return AdaptiveParameters.forBeginner();
    }

    // Analizar fortalezas y debilidades por familia
    final strongFamilies = <OperationFamily>[];
    final weakFamilies = <OperationFamily>[];
    
    for (final entry in profile.familyStats.entries) {
      final stats = entry.value;
      final samples = stats.correct + stats.incorrect;
      
      if (samples >= _minSamplesForAdjustment) {
        if (stats.accuracy >= _highAccuracyThreshold) {
          strongFamilies.add(entry.key);
        } else if (stats.accuracy < _lowAccuracyThreshold) {
          weakFamilies.add(entry.key);
        }
      }
    }

    // Calcular tier sugerido basado en memoria
    int suggestedTier = _calculateSuggestedTier(profile, currentSession, mode);
    
    // Determinar si ajustar dificultad durante sesión
    final sessionSamples = currentSession.correctThisSession + currentSession.incorrectThisSession;
    bool shouldIncrease = false;
    bool shouldDecrease = false;
    
    if (sessionSamples >= _minSamplesForAdjustment) {
      // Solo subir si:
      // 1. Alta precisión en sesión
      // 2. Racha sólida (al menos 5 consecutivos)
      // 3. No subir más de 1 tier por sesión
      if (currentSession.sessionAccuracy >= _highAccuracyThreshold && 
          currentSession.streak >= _streakToIncrease &&
          suggestedTier < 5) {
        shouldIncrease = true;
      } 
      // Bajar si precisión baja
      else if (currentSession.sessionAccuracy < _lowAccuracyThreshold &&
               suggestedTier > 1) {
        shouldDecrease = true;
      }
    }

    // Calcular velocidad adaptativa
    final speedMultiplier = _calculateSpeedMultiplier(profile, currentSession, mode);
    
    // Calcular intervalo de spawn
    final spawnInterval = _calculateSpawnInterval(mode, suggestedTier, profile);

    // Sugerir familia a practicar (para modo aprendizaje)
    final suggestedFamily = _suggestFamilyToPractice(profile, weakFamilies);

    return AdaptiveParameters(
      suggestedTier: suggestedTier,
      speedMultiplier: speedMultiplier,
      spawnIntervalMs: spawnInterval,
      strongFamilies: strongFamilies,
      weakFamilies: weakFamilies,
      suggestedFamily: suggestedFamily,
      shouldIncreaseDifficulty: shouldIncrease,
      shouldDecreaseDifficulty: shouldDecrease,
    );
  }

  int _calculateSuggestedTier(PlayerProfile profile, GameState session, GameMode mode) {
    // Base: usar el tier guardado del jugador para esta familia
    int baseTier = profile.globalTierUnlocked.clamp(1, 5);
    
    // Para modo aprendizaje, ser más conservador
    if (mode == GameMode.aprendizaje) {
      // Usar el tier específico de la familia seleccionada si existe
      final familyStats = profile.familyStats[session.selectedFamily];
      if (familyStats != null && familyStats.correct + familyStats.incorrect >= _minSamplesForAdjustment) {
        baseTier = familyStats.maxTierUnlocked.clamp(1, 5);
      } else {
        // Sin datos, empezar desde 1
        baseTier = 1;
      }
    }
    
    // Jugadores nuevos: empezar bajo
    if (profile.totalSessions < 3) {
      baseTier = min(baseTier, 2);
    }
    
    // Ajustar según precisión global histórica
    if (profile.globalAccuracy < _lowAccuracyThreshold && profile.totalCorrect > 20) {
      baseTier = max(1, baseTier - 1);
    }
    
    // Ajustar según sesión actual (pero máximo ±1)
    if (session.correctThisSession > 15 && session.sessionAccuracy > _highAccuracyThreshold) {
      baseTier = min(5, baseTier + 1);
    } else if (session.sessionAccuracy < 0.4 && session.incorrectThisSession > 5) {
      baseTier = max(1, baseTier - 1);
    }
    
    return baseTier.clamp(1, 5);
  }

  double _calculateSpeedMultiplier(PlayerProfile profile, GameState session, GameMode mode) {
    double multiplier = profile.adaptiveSpeedFactor;
    
    // Modo aprendizaje: más lento
    if (mode == GameMode.aprendizaje) {
      multiplier *= 0.85;
    }
    
    // Jugadores con buena precisión pueden manejar más velocidad
    if (profile.globalAccuracy > _highAccuracyThreshold && profile.totalCorrect > 50) {
      multiplier += 0.1;
    }
    
    // Si están luchando, reducir velocidad
    if (session.sessionAccuracy < _lowAccuracyThreshold && 
        session.correctThisSession + session.incorrectThisSession > 5) {
      multiplier -= 0.2;
    }
    
    // Racha alta = pueden ir más rápido
    if (session.streak >= 10) {
      multiplier += 0.1;
    }
    
    return multiplier.clamp(0.5, 2.0);
  }

  double _calculateSpawnInterval(GameMode mode, int tier, PlayerProfile profile) {
    double baseInterval;
    switch (mode) {
      case GameMode.aprendizaje:
        baseInterval = 3500;
        break;
      case GameMode.porTiempo:
        baseInterval = 2500;
        break;
      case GameMode.porPuntuacion:
        baseInterval = 2800;
        break;
      case GameMode.supervivencia:
        baseInterval = 2000;
        break;
      case GameMode.porNiveles:
        baseInterval = 2800;
        break;
    }
    
    // Reducir intervalo con tier más alto (pero suavemente)
    baseInterval -= (tier - 1) * 150;
    
    // Ajustar por factor adaptativo del jugador
    baseInterval /= profile.adaptiveSpeedFactor;
    
    return baseInterval.clamp(1200, 5000);
  }

  OperationFamily _suggestFamilyToPractice(PlayerProfile profile, List<OperationFamily> weakFamilies) {
    // Priorizar familias débiles
    if (weakFamilies.isNotEmpty) {
      return weakFamilies.first;
    }
    
    // Buscar familias sin datos o poco practicadas
    final coreFamilies = [
      OperationFamily.sumas,
      OperationFamily.restas,
      OperationFamily.multiplicaciones,
      OperationFamily.divisiones,
    ];
    
    for (final family in coreFamilies) {
      final stats = profile.familyStats[family];
      if (stats == null || stats.correct + stats.incorrect < _minSamplesForAdjustment) {
        return family;
      }
    }
    
    // Todas practicadas: elegir la de menor precisión
    OperationFamily? lowest;
    double lowestAcc = 1.0;
    for (final family in coreFamilies) {
      final stats = profile.familyStats[family];
      if (stats != null && stats.accuracy < lowestAcc) {
        lowestAcc = stats.accuracy;
        lowest = family;
      }
    }
    
    return lowest ?? OperationFamily.todas;
  }

  /// Actualiza el perfil del jugador después de una respuesta
  PlayerProfile updateProfileAfterAnswer({
    required PlayerProfile profile,
    required Operation operation,
    required bool correct,
    required int responseTimeMs,
  }) {
    final family = operation.family;
    final tier = operation.tier;
    final currentStats = profile.familyStats[family] ?? const FamilyStats();
    
    // Actualizar estadísticas de la familia
    final newCorrect = currentStats.correct + (correct ? 1 : 0);
    final newIncorrect = currentStats.incorrect + (correct ? 0 : 1);
    
    // Calcular nuevo promedio de tiempo (rolling average)
    final totalResponses = newCorrect + newIncorrect;
    final newAvgTime = totalResponses > 1
      ? ((currentStats.avgResponseTimeMs * (totalResponses - 1)) + responseTimeMs) / totalResponses
      : responseTimeMs.toDouble();
    
    // Actualizar tier máximo desbloqueado para esta familia
    int newMaxTier = currentStats.maxTierUnlocked;
    if (correct && tier >= currentStats.maxTierUnlocked) {
      // Solo desbloquear si tiene buena precisión reciente
      final recentAccuracy = newCorrect / totalResponses;
      if (recentAccuracy >= 0.7 && newCorrect >= 5) {
        // Desbloquear siguiente tier (máximo +1)
        newMaxTier = min(5, tier + 1);
      }
    }
    
    // Actualizar stats por tier dentro de la familia
    final tierStats = Map<int, TierStats>.from(currentStats.tierStats);
    final currentTierStats = tierStats[tier] ?? const TierStats();
    tierStats[tier] = currentTierStats.copyWith(
      correct: currentTierStats.correct + (correct ? 1 : 0),
      incorrect: currentTierStats.incorrect + (correct ? 0 : 1),
      avgTimeMs: totalResponses > 1
        ? ((currentTierStats.avgTimeMs * (currentTierStats.correct + currentTierStats.incorrect)) + responseTimeMs) / (currentTierStats.correct + currentTierStats.incorrect + 1)
        : responseTimeMs.toDouble(),
    );
    
    final updatedFamilyStats = currentStats.copyWith(
      correct: newCorrect,
      incorrect: newIncorrect,
      avgResponseTimeMs: newAvgTime,
      maxTierUnlocked: newMaxTier,
      tierStats: tierStats,
    );
    
    // Crear nuevo mapa de stats
    final newFamilyStats = Map<OperationFamily, FamilyStats>.from(profile.familyStats);
    newFamilyStats[family] = updatedFamilyStats;
    
    // Actualizar tier global
    final newGlobalTier = max(
      profile.globalTierUnlocked,
      _calculateNewGlobalTier(newFamilyStats),
    );
    
    // Calcular nuevo factor de velocidad adaptativo
    double newSpeedFactor = profile.adaptiveSpeedFactor;
    if (correct && responseTimeMs < _fastResponseMs) {
      newSpeedFactor = min(2.0, newSpeedFactor + 0.015);
    } else if (!correct) {
      newSpeedFactor = max(0.5, newSpeedFactor - 0.025);
    }
    
    return profile.copyWith(
      totalCorrect: profile.totalCorrect + (correct ? 1 : 0),
      totalIncorrect: profile.totalIncorrect + (correct ? 0 : 1),
      familyStats: newFamilyStats,
      globalTierUnlocked: newGlobalTier,
      adaptiveSpeedFactor: newSpeedFactor,
      lastPlayedAt: DateTime.now(),
    );
  }

  int _calculateNewGlobalTier(Map<OperationFamily, FamilyStats> familyStats) {
    if (familyStats.isEmpty) return 1;
    
    // El tier global es el mínimo de los tiers desbloqueados en familias core
    final coreFamilies = [
      OperationFamily.sumas,
      OperationFamily.restas,
      OperationFamily.multiplicaciones,
    ];
    
    int minTier = 5;
    int familiesWithStats = 0;
    
    for (final family in coreFamilies) {
      final stats = familyStats[family];
      if (stats != null && stats.correct + stats.incorrect >= _minSamplesForAdjustment) {
        minTier = min(minTier, stats.maxTierUnlocked);
        familiesWithStats++;
      }
    }
    
    // Si no hay suficientes datos, ser conservador
    if (familiesWithStats < 2) return 1;
    
    return minTier;
  }

  /// Determina el tier para la próxima operación en modo aprendizaje
  int getNextOperationTier({
    required PlayerProfile profile,
    required GameState session,
    required OperationFamily family,
  }) {
    final familyStats = profile.familyStats[family];
    
    // Sin datos: tier 1
    if (familyStats == null || familyStats.correct + familyStats.incorrect < 3) {
      return 1;
    }
    
    int currentTier = familyStats.maxTierUnlocked;
    
    // Si racha actual es buena, permitir subir 1
    if (session.streak >= _streakToIncrease && session.sessionAccuracy >= _highAccuracyThreshold) {
      return min(5, currentTier + 1);
    }
    
    // Si está luchando, bajar
    if (session.sessionAccuracy < _lowAccuracyThreshold && session.incorrectThisSession >= 3) {
      return max(1, currentTier - 1);
    }
    
    return currentTier;
  }
}
