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

    group('Cálculo de parámetros adaptativos', () {
      test('devuelve parámetros de principiante para jugador nuevo', () {
        final profile = PlayerProfile.create('Nuevo');
        final session = GameState.initial();
        
        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );
        
        expect(params.suggestedTier, equals(1));
        expect(params.speedMultiplier, lessThan(1.0));
        expect(params.shouldIncreaseDifficulty, isFalse);
        expect(params.shouldDecreaseDifficulty, isFalse);
      });

      test('sugiere subir dificultad con racha alta y buena precisión', () {
        final profile = PlayerProfile.create('Experto').copyWith(
          totalCorrect: 100,
          totalIncorrect: 10,
          globalTierUnlocked: 3,
          familyStats: {
            OperationFamily.sumas: const FamilyStats(
              correct: 50,
              incorrect: 5,
              maxTierUnlocked: 3,
            ),
          },
        );
        
        final session = GameState.initial().copyWith(
          isRunning: true,
          correctThisSession: 15,
          incorrectThisSession: 1,
          streak: 8,
        );
        
        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );
        
        expect(params.shouldIncreaseDifficulty, isTrue,
          reason: 'Con 87.5% precisión y racha de 8, debe sugerir subir');
      });

      test('sugiere bajar dificultad con baja precisión', () {
        final profile = PlayerProfile.create('Luchando').copyWith(
          totalCorrect: 20,
          totalIncorrect: 30,
          globalTierUnlocked: 3,
        );
        
        final session = GameState.initial().copyWith(
          isRunning: true,
          correctThisSession: 3,
          incorrectThisSession: 10,
          streak: 0,
          currentTier: 3,
        );
        
        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.supervivencia,
        );
        
        expect(params.shouldDecreaseDifficulty, isTrue,
          reason: 'Con ~23% precisión, debe sugerir bajar');
      });

      test('identifica familias fuertes y débiles', () {
        final profile = PlayerProfile.create('Mixto').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(
              correct: 45,
              incorrect: 5,
              maxTierUnlocked: 4,
            ),
            OperationFamily.multiplicaciones: const FamilyStats(
              correct: 8,
              incorrect: 12,
              maxTierUnlocked: 2,
            ),
          },
        );
        
        final session = GameState.initial();
        
        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.aprendizaje,
        );
        
        expect(params.strongFamilies, contains(OperationFamily.sumas));
        expect(params.weakFamilies, contains(OperationFamily.multiplicaciones));
      });
    });

    group('Actualización de perfil después de respuesta', () {
      test('incrementa contadores de aciertos', () {
        final profile = PlayerProfile.create('Test');
        final operation = Operation(
          expression: '5 + 3',
          answer: 8,
          type: OperationType.addition,
          tier: 1,
          complexity: 1,
        );
        
        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: true,
          responseTimeMs: 2000,
        );
        
        expect(updated.totalCorrect, equals(1));
        expect(updated.totalIncorrect, equals(0));
        expect(updated.familyStats[OperationFamily.sumas]?.correct, equals(1));
      });

      test('incrementa contadores de fallos', () {
        final profile = PlayerProfile.create('Test');
        final operation = Operation(
          expression: '7 × 8',
          answer: 56,
          type: OperationType.multiplication,
          tier: 2,
          complexity: 2,
        );
        
        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: false,
          responseTimeMs: 5000,
        );
        
        expect(updated.totalCorrect, equals(0));
        expect(updated.totalIncorrect, equals(1));
        expect(updated.familyStats[OperationFamily.multiplicaciones]?.incorrect, equals(1));
      });

      test('desbloquea tier siguiente con buena precisión', () {
        var profile = PlayerProfile.create('Test').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(
              correct: 9,
              incorrect: 1,
              maxTierUnlocked: 2,
            ),
          },
        );
        
        final operation = Operation(
          expression: '25 + 38',
          answer: 63,
          type: OperationType.addition,
          tier: 2,
          complexity: 2,
        );
        
        // Añadir varios aciertos para alcanzar umbral
        for (int i = 0; i < 5; i++) {
          profile = engine.updateProfileAfterAnswer(
            profile: profile,
            operation: operation,
            correct: true,
            responseTimeMs: 2500,
          );
        }
        
        // Con 14/16 = 87.5% precisión, debe desbloquear tier 3
        expect(profile.familyStats[OperationFamily.sumas]?.maxTierUnlocked, 
          greaterThanOrEqualTo(2));
      });

      test('ajusta factor de velocidad con respuestas rápidas', () {
        final profile = PlayerProfile.create('Test').copyWith(
          adaptiveSpeedFactor: 1.0,
        );
        final operation = Operation(
          expression: '3 + 4',
          answer: 7,
          type: OperationType.addition,
          tier: 1,
          complexity: 1,
        );
        
        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: true,
          responseTimeMs: 1500, // Respuesta rápida
        );
        
        expect(updated.adaptiveSpeedFactor, greaterThan(1.0),
          reason: 'Factor de velocidad debe aumentar con respuestas rápidas');
      });

      test('reduce factor de velocidad con fallos', () {
        final profile = PlayerProfile.create('Test').copyWith(
          adaptiveSpeedFactor: 1.2,
        );
        final operation = Operation(
          expression: '9 × 8',
          answer: 72,
          type: OperationType.multiplication,
          tier: 3,
          complexity: 3,
        );
        
        final updated = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: operation,
          correct: false,
          responseTimeMs: 10000,
        );
        
        expect(updated.adaptiveSpeedFactor, lessThan(1.2),
          reason: 'Factor de velocidad debe disminuir con fallos');
      });

      test('trackea stats por tier dentro de familia', () {
        var profile = PlayerProfile.create('Test');
        
        // Acierto en tier 1
        profile = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: Operation(
            expression: '2 + 3',
            answer: 5,
            type: OperationType.addition,
            tier: 1,
            complexity: 1,
          ),
          correct: true,
          responseTimeMs: 2000,
        );
        
        // Acierto en tier 2
        profile = engine.updateProfileAfterAnswer(
          profile: profile,
          operation: Operation(
            expression: '15 + 18',
            answer: 33,
            type: OperationType.addition,
            tier: 2,
            complexity: 2,
          ),
          correct: true,
          responseTimeMs: 3000,
        );
        
        final familyStats = profile.familyStats[OperationFamily.sumas]!;
        expect(familyStats.tierStats[1]?.correct, equals(1));
        expect(familyStats.tierStats[2]?.correct, equals(1));
      });
    });

    group('Selección de tier para próxima operación', () {
      test('devuelve tier 1 para familia sin datos', () {
        final profile = PlayerProfile.create('Test');
        final session = GameState.initial();
        
        final tier = engine.getNextOperationTier(
          profile: profile,
          session: session,
          family: OperationFamily.sumas,
        );
        
        expect(tier, equals(1));
      });

      test('permite subir con racha alta', () {
        final profile = PlayerProfile.create('Test').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(
              correct: 20,
              incorrect: 3,
              maxTierUnlocked: 2,
            ),
          },
        );
        
        final session = GameState.initial().copyWith(
          streak: 7,
          correctThisSession: 10,
          incorrectThisSession: 1,
        );
        
        final tier = engine.getNextOperationTier(
          profile: profile,
          session: session,
          family: OperationFamily.sumas,
        );
        
        expect(tier, equals(3),
          reason: 'Con racha de 7 y >80% precisión, debe subir a tier 3');
      });

      test('baja tier con muchos fallos', () {
        final profile = PlayerProfile.create('Test').copyWith(
          familyStats: {
            OperationFamily.multiplicaciones: const FamilyStats(
              correct: 10,
              incorrect: 5,
              maxTierUnlocked: 3,
            ),
          },
        );
        
        final session = GameState.initial().copyWith(
          streak: 0,
          correctThisSession: 2,
          incorrectThisSession: 5,
        );
        
        final tier = engine.getNextOperationTier(
          profile: profile,
          session: session,
          family: OperationFamily.multiplicaciones,
        );
        
        expect(tier, equals(2),
          reason: 'Con <50% precisión y varios fallos, debe bajar');
      });
    });

    group('Límites y seguridad', () {
      test('tier nunca excede rango 1-5', () {
        final profile = PlayerProfile.create('Test').copyWith(
          globalTierUnlocked: 10, // Valor inválido
          familyStats: {
            OperationFamily.todas: const FamilyStats(
              correct: 100,
              incorrect: 5,
              maxTierUnlocked: 8,
            ),
          },
        );
        
        final session = GameState.initial().copyWith(
          streak: 20,
          correctThisSession: 50,
          incorrectThisSession: 2,
        );
        
        final params = engine.calculate(
          profile: profile,
          currentSession: session,
          mode: GameMode.porTiempo,
        );
        
        expect(params.suggestedTier, lessThanOrEqualTo(5));
        expect(params.suggestedTier, greaterThanOrEqualTo(1));
      });

      test('factor de velocidad se mantiene en rango 0.5-2.0', () {
        var profile = PlayerProfile.create('Test').copyWith(
          adaptiveSpeedFactor: 1.95,
        );
        
        final operation = Operation(
          expression: '2 + 2',
          answer: 4,
          type: OperationType.addition,
          tier: 1,
          complexity: 1,
        );
        
        // Muchos aciertos rápidos
        for (int i = 0; i < 20; i++) {
          profile = engine.updateProfileAfterAnswer(
            profile: profile,
            operation: operation,
            correct: true,
            responseTimeMs: 1000,
          );
        }
        
        expect(profile.adaptiveSpeedFactor, lessThanOrEqualTo(2.0));
        
        // Ahora muchos fallos
        for (int i = 0; i < 50; i++) {
          profile = engine.updateProfileAfterAnswer(
            profile: profile,
            operation: operation,
            correct: false,
            responseTimeMs: 10000,
          );
        }
        
        expect(profile.adaptiveSpeedFactor, greaterThanOrEqualTo(0.5));
      });
    });

    group('Persistencia de memoria', () {
      test('perfil mantiene historial entre sesiones simuladas', () {
        var profile = PlayerProfile.create('Persistente');
        
        // Primera "sesión"
        for (int i = 0; i < 10; i++) {
          profile = engine.updateProfileAfterAnswer(
            profile: profile,
            operation: Operation(
              expression: '${i + 1} + ${i + 2}',
              answer: (i + 1) + (i + 2),
              type: OperationType.addition,
              tier: 1,
              complexity: 1,
            ),
            correct: true,
            responseTimeMs: 2000,
          );
        }
        
        // Verificar que se acumularon
        expect(profile.totalCorrect, equals(10));
        expect(profile.familyStats[OperationFamily.sumas]?.correct, equals(10));
        
        // "Nueva sesión" - perfil mantiene datos
        final params = engine.calculate(
          profile: profile,
          currentSession: GameState.initial(), // Sesión vacía
          mode: GameMode.aprendizaje,
        );
        
        // Debe usar el historial del perfil
        expect(params.suggestedTier, greaterThanOrEqualTo(1));
        expect(params.strongFamilies, isNotEmpty);
      });
    });
  });
}
