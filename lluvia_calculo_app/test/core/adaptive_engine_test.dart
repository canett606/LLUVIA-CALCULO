import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/core/adaptive_engine.dart';
import 'package:lluvia_calculo/models/operation.dart';
import 'package:lluvia_calculo/models/player_profile.dart';
import 'package:lluvia_calculo/models/game_state.dart';

void main() {
  group('AdaptiveEngine', () {
    late AdaptiveEngine engine;

    setUp(() {
      engine = AdaptiveEngine();
    });

    group('calculate', () {
      test('retorna parámetros conservadores para jugador nuevo', () {
        final profile = PlayerProfile.create('Nuevo');
        final session = GameState.initial();

        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );

        expect(params.suggestedTier, 1);
        expect(params.speedMultiplier, lessThanOrEqualTo(1.0));
        expect(params.shouldIncreaseDifficulty, isFalse);
        expect(params.shouldDecreaseDifficulty, isFalse);
      });

      test('sugiere aumentar dificultad con alta precisión y racha', () {
        final profile = PlayerProfile.create('Experto').copyWith(
          totalCorrect: 100,
          totalIncorrect: 10,
          totalSessions: 5,
        );
        
        final session = const GameState(
          correctThisSession: 20,
          incorrectThisSession: 1,
          streak: 8,
        );

        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );

        expect(params.shouldIncreaseDifficulty, isTrue);
      });

      test('sugiere disminuir dificultad con baja precisión', () {
        final profile = PlayerProfile.create('Luchando').copyWith(
          totalCorrect: 20,
          totalIncorrect: 30,
          totalSessions: 3,
        );
        
        final session = const GameState(
          correctThisSession: 3,
          incorrectThisSession: 7,
          streak: 0,
        );

        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );

        expect(params.shouldDecreaseDifficulty, isTrue);
      });

      test('no ajusta con pocas muestras', () {
        final profile = PlayerProfile.create('Nuevo').copyWith(
          totalSessions: 1,
        );
        
        final session = const GameState(
          correctThisSession: 2,
          incorrectThisSession: 1,
        );

        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );

        expect(params.shouldIncreaseDifficulty, isFalse);
        expect(params.shouldDecreaseDifficulty, isFalse);
      });
    });

    group('updateProfileAfterAnswer', () {
      test('incrementa contador de aciertos correctamente', () {
        final profile = PlayerProfile.create('Test');
        const operation = Operation(
          expression: '2 + 3',
          answer: 5,
          type: OperationType.addition,
          tier: 1,
        );

        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: true,
          responseTimeMs: 1500,
        );

        expect(updated.totalCorrect, profile.totalCorrect + 1);
        expect(updated.totalIncorrect, profile.totalIncorrect);
      });

      test('incrementa contador de fallos correctamente', () {
        final profile = PlayerProfile.create('Test');
        const operation = Operation(
          expression: '2 + 3',
          answer: 5,
          type: OperationType.addition,
          tier: 1,
        );

        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: false,
          responseTimeMs: 5000,
        );

        expect(updated.totalCorrect, profile.totalCorrect);
        expect(updated.totalIncorrect, profile.totalIncorrect + 1);
      });

      test('actualiza estadísticas de familia', () {
        final profile = PlayerProfile.create('Test');
        const operation = Operation(
          expression: '3 × 4',
          answer: 12,
          type: OperationType.multiplication,
          tier: 2,
        );

        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: true,
          responseTimeMs: 2000,
        );

        final multStats = updated.familyStats[OperationFamily.multiplicaciones];
        expect(multStats, isNotNull);
        expect(multStats!.correct, 1);
        expect(multStats.avgResponseTimeMs, 2000);
      });

      test('aumenta factor de velocidad con respuestas rápidas', () {
        var profile = PlayerProfile.create('Test');
        const operation = Operation(
          expression: '2 + 2',
          answer: 4,
          type: OperationType.addition,
          tier: 1,
        );

        // Varias respuestas rápidas
        for (int i = 0; i < 5; i++) {
          profile = engine.updateProfileAfterAnswer(
            profile: profile,
            operation: operation,
            correct: true,
            responseTimeMs: 1000, // Rápido
          );
        }

        expect(profile.adaptiveSpeedFactor, greaterThan(1.0));
      });

      test('reduce factor de velocidad con errores', () {
        var profile = PlayerProfile.create('Test').copyWith(
          adaptiveSpeedFactor: 1.5,
        );
        const operation = Operation(
          expression: '7 × 8',
          answer: 56,
          type: OperationType.multiplication,
          tier: 2,
        );

        // Varios errores
        for (int i = 0; i < 5; i++) {
          profile = engine.updateProfileAfterAnswer(
            profile: profile,
            operation: operation,
            correct: false,
            responseTimeMs: 5000,
          );
        }

        expect(profile.adaptiveSpeedFactor, lessThan(1.5));
      });
    });

    group('suggestFamilyToPractice', () {
      test('sugiere familia sin datos primero', () {
        final profile = PlayerProfile.create('Test').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(correct: 50, incorrect: 5),
          },
        );

        final suggestion = engine.suggestFamilyToPractice(profile);
        
        // Debería sugerir una familia sin datos (restas, multiplicaciones, o divisiones)
        expect(suggestion, isNot(OperationFamily.sumas));
      });

      test('sugiere familia más débil cuando todas tienen datos', () {
        final profile = PlayerProfile.create('Test').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(correct: 50, incorrect: 5),
            OperationFamily.restas: const FamilyStats(correct: 30, incorrect: 20),
            OperationFamily.multiplicaciones: const FamilyStats(correct: 45, incorrect: 5),
            OperationFamily.divisiones: const FamilyStats(correct: 40, incorrect: 10),
          },
        );

        final suggestion = engine.suggestFamilyToPractice(profile);
        
        // Restas tiene peor precisión (30/50 = 60%)
        expect(suggestion, OperationFamily.restas);
      });
    });
  });

  group('AdaptiveParameters', () {
    test('forBeginner retorna valores conservadores', () {
      final params = AdaptiveParameters.forBeginner();
      
      expect(params.suggestedTier, 1);
      expect(params.speedMultiplier, lessThan(1.0));
      expect(params.spawnIntervalMs, greaterThanOrEqualTo(3000));
      expect(params.shouldIncreaseDifficulty, isFalse);
      expect(params.shouldDecreaseDifficulty, isFalse);
    });
  });

  group('FamilyStats', () {
    test('calcula precisión correctamente', () {
      const stats = FamilyStats(correct: 80, incorrect: 20);
      expect(stats.accuracy, 0.8);
    });

    test('maneja división por cero en precisión', () {
      const stats = FamilyStats(correct: 0, incorrect: 0);
      expect(stats.accuracy, 0.0);
    });

    test('copyWith preserva valores no cambiados', () {
      const original = FamilyStats(
        correct: 10,
        incorrect: 5,
        avgResponseTimeMs: 2000,
        maxTierUnlocked: 3,
      );
      
      final updated = original.copyWith(correct: 15);
      
      expect(updated.correct, 15);
      expect(updated.incorrect, 5);
      expect(updated.avgResponseTimeMs, 2000);
      expect(updated.maxTierUnlocked, 3);
    });

    test('serializa y deserializa correctamente', () {
      const original = FamilyStats(
        correct: 25,
        incorrect: 8,
        avgResponseTimeMs: 1800.5,
        maxTierUnlocked: 2,
      );
      
      final json = original.toJson();
      final restored = FamilyStats.fromJson(json);
      
      expect(restored.correct, original.correct);
      expect(restored.incorrect, original.incorrect);
      expect(restored.avgResponseTimeMs, original.avgResponseTimeMs);
      expect(restored.maxTierUnlocked, original.maxTierUnlocked);
    });
  });
}
