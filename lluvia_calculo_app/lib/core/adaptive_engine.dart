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
  final bool shouldIncreaseDifficulty;
  final bool shouldDecreaseDifficulty;

  const AdaptiveParameters({
    required this.suggestedTier,
    required this.speedMultiplier,
    required this.spawnIntervalMs,
    required this.strongFamilies,
    required this.weakFamilies,
    required this.shouldIncreaseDifficulty,
    required this.shouldDecreaseDifficulty,
  });

  factory AdaptiveParameters.forBeginner() => const AdaptiveParameters(
    suggestedTier: 1,
    speedMultiplier: 0.7,
    spawnIntervalMs: 4000,
    strongFamilies: [],
    weakFamilies: [],
    shouldIncreaseDifficulty: false,
    shouldDecreaseDifficulty: false,
  );
}

/// Motor adaptativo que ajusta dificultad según rendimiento del jugador.
/// 
/// Principios:
/// - Nunca saltar más de 1 tier a la vez
/// - Requiere consistencia (varios aciertos) para subir
/// - Baja rápido si el jugador está luchando
/// - Trackea fortalezas/debilidades por familia
class AdaptiveEngine {
  // Umbrales para ajuste de dificultad
  static const double _highAccuracyThreshold = 0.85;
  static const double _lowAccuracyThreshold = 0.55;
  static const int _minSamplesForAdjustment = 5;
  static const double _fastResponseThresholdMs = 3000;
  
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

    // Analizar fortalezas y debilidades
    final strongFamilies = <OperationFamily>[];
    final weakFamilies = <OperationFamily>[];
    
    for (final entry in profile.familyStats.entries) {
      final stats = entry.value;
      if (stats.correct + stats.incorrect >= _minSamplesForAdjustment) {
        if (stats.accuracy >= _highAccuracyThreshold) {
          strongFamilies.add(entry.key);
        } else if (stats.accuracy < _lowAccuracyThreshold) {
          weakFamilies.add(entry.key);
        }
      }
    }

    // Calcular tier sugerido
    int suggestedTier = _calculateSuggestedTier(profile, currentSession);
    
    // Determinar si ajustar dificultad
    final sessionSamples = currentSession.correctThisSession + currentSession.incorrectThisSession;
    bool shouldIncrease = false;
    bool shouldDecrease = false;
    
    if (sessionSamples >= _minSamplesForAdjustment) {
      if (currentSession.sessionAccuracy >= _highAccuracyThreshold && 
          currentSession.streak >= 5) {
        shouldIncrease = true;
      } else if (currentSession.sessionAccuracy < _lowAccuracyThreshold) {
        shouldDecrease = true;
      }
    }

    // Calcular velocidad adaptativa
    final speedMultiplier = _calculateSpeedMultiplier(profile, currentSession);
    
    // Calcular intervalo de spawn
    final spawnInterval = _calculateSpawnInterval(mode, suggestedTier, profile);

    return AdaptiveParameters(
      suggestedTier: suggestedTier,
      speedMultiplier: speedMultiplier,
      spawnIntervalMs: spawnInterval,
      strongFamilies: strongFamilies,
      weakFamilies: weakFamilies,
      shouldIncreaseDifficulty: shouldIncrease,
      shouldDecreaseDifficulty: shouldDecrease,
    );
  }

  int _calculateSuggestedTier(PlayerProfile profile, GameState session) {
    // Base: tier desbloqueado del perfil
    int baseTier = profile.globalTierUnlocked.clamp(1, 5);
    
    // Si el jugador tiene poca experiencia, empezar más bajo
    if (profile.totalSessions < 3) {
      baseTier = min(baseTier, 2);
    }
    
    // Ajustar según rendimiento global
    if (profile.globalAccuracy < _lowAccuracyThreshold && profile.totalCorrect > 20) {
      baseTier = max(1, baseTier - 1);
    }
    
    // Ajustar según sesión actual
    if (session.correctThisSession > 10 && session.sessionAccuracy > _highAccuracyThreshold) {
      baseTier = min(5, baseTier + 1);
    }
    
    return baseTier.clamp(1, 5);
  }

  double _calculateSpeedMultiplier(PlayerProfile profile, GameState session) {
    // Base
    double multiplier = profile.adaptiveSpeedFactor;
    
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
    // Intervalos base por modo (en ms)
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
    
    // Reducir intervalo con tier más alto
    baseInterval -= (tier - 1) * 200;
    
    // Ajustar por factor adaptativo del jugador
    baseInterval /= profile.adaptiveSpeedFactor;
    
    // Límites razonables
    return baseInterval.clamp(1000, 5000);
  }

  /// Actualiza el perfil del jugador después de una respuesta
  PlayerProfile updateProfileAfterAnswer({
    required PlayerProfile profile,
    required Operation operation,
    required bool correct,
    required int responseTimeMs,
  }) {
    final family = operation.family;
    final currentStats = profile.familyStats[family] ?? const FamilyStats();
    
    // Actualizar estadísticas de la familia
    final newCorrect = currentStats.correct + (correct ? 1 : 0);
    final newIncorrect = currentStats.incorrect + (correct ? 0 : 1);
    
    // Calcular nuevo promedio de tiempo de respuesta (rolling average)
    final totalResponses = newCorrect + newIncorrect;
    final newAvgTime = totalResponses > 1
      ? ((currentStats.avgResponseTimeMs * (totalResponses - 1)) + responseTimeMs) / totalResponses
      : responseTimeMs.toDouble();
    
    // Actualizar tier desbloqueado si corresponde
    int newMaxTier = currentStats.maxTierUnlocked;
    if (correct && operation.tier > currentStats.maxTierUnlocked) {
      // Solo desbloquear si tiene buena precisión en ese tier
      final tierAccuracy = newCorrect / totalResponses;
      if (tierAccuracy >= 0.7) {
        newMaxTier = operation.tier;
      }
    }
    
    final updatedFamilyStats = currentStats.copyWith(
      correct: newCorrect,
      incorrect: newIncorrect,
      avgResponseTimeMs: newAvgTime,
      maxTierUnlocked: newMaxTier,
    );
    
    // Crear nuevo mapa de stats
    final newFamilyStats = Map<OperationFamily, FamilyStats>.from(profile.familyStats);
    newFamilyStats[family] = updatedFamilyStats;
    
    // Actualizar tier global si desbloqueó uno nuevo
    final newGlobalTier = max(
      profile.globalTierUnlocked,
      _calculateNewGlobalTier(newFamilyStats),
    );
    
    // Calcular nuevo factor de velocidad adaptativo
    double newSpeedFactor = profile.adaptiveSpeedFactor;
    if (correct && responseTimeMs < _fastResponseThresholdMs) {
      newSpeedFactor = min(2.0, newSpeedFactor + 0.02);
    } else if (!correct) {
      newSpeedFactor = max(0.5, newSpeedFactor - 0.03);
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
    
    // El tier global es el mínimo de los tiers desbloqueados en familias principales
    // (excluyendo mixtas y todas que son combinaciones)
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

  /// Determina qué familia debe practicar el jugador (para modo aprendizaje)
  OperationFamily suggestFamilyToPractice(PlayerProfile profile) {
    // Priorizar familias débiles
    OperationFamily? weakest;
    double lowestAccuracy = 1.0;
    
    final coreFamilies = [
      OperationFamily.sumas,
      OperationFamily.restas,
      OperationFamily.multiplicaciones,
      OperationFamily.divisiones,
    ];
    
    for (final family in coreFamilies) {
      final stats = profile.familyStats[family];
      if (stats == null) {
        // Familia sin datos = prioridad alta
        return family;
      }
      
      if (stats.correct + stats.incorrect < _minSamplesForAdjustment) {
        // Poco practicada
        return family;
      }
      
      if (stats.accuracy < lowestAccuracy) {
        lowestAccuracy = stats.accuracy;
        weakest = family;
      }
    }
    
    // Si todas las familias están bien, elegir aleatoriamente o la más débil
    return weakest ?? OperationFamily.todas;
  }
}
