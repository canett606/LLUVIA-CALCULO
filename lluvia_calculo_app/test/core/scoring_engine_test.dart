import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/core/scoring_engine.dart';
import 'package:lluvia_calculo/models/operation.dart';
import 'package:lluvia_calculo/models/game_state.dart';

void main() {
  group('ScoringEngine', () {
    late ScoringEngine engine;

    setUp(() {
      engine = ScoringEngine();
    });

    FallingDrop _createDrop({
      required int answer,
      int tier = 2,
      double y = 0.5,
      int ageMs = 2000,
    }) {
      return FallingDrop(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        operation: Operation(
          expression: 'test',
          answer: answer,
          type: OperationType.addition,
          tier: tier,
        ),
        x: 0.5,
        y: y,
        speed: 0.1,
        spawnedAt: DateTime.now().subtract(Duration(milliseconds: ageMs)),
      );
    }

    group('evaluateAnswer', () {
      test('retorna correcto cuando hay gota con respuesta coincidente', () {
        final drop = _createDrop(answer: 42);
        final state = GameState(
          activeDrops: [drop],
          streak: 0,
        );

        final result = engine.evaluateAnswer(
          userAnswer: 42,
          state: state,
          mode: GameMode.aprendizaje,
        );

        expect(result.correct, isTrue);
        expect(result.hitDrop, isNotNull);
        expect(result.hitDrop!.operation.answer, 42);
      });

      test('retorna incorrecto cuando no hay gota coincidente', () {
        final drop = _createDrop(answer: 42);
        final state = GameState(
          activeDrops: [drop],
          streak: 3,
        );

        final result = engine.evaluateAnswer(
          userAnswer: 99,
          state: state,
          mode: GameMode.aprendizaje,
        );

        expect(result.correct, isFalse);
        expect(result.hitDrop, isNull);
        expect(result.newStreak, 0); // Racha reseteada
      });

      test('selecciona gota más cercana al suelo cuando hay múltiples', () {
        final dropFar = _createDrop(answer: 42, y: 0.3);
        final dropClose = _createDrop(answer: 42, y: 0.8);
        final state = GameState(
          activeDrops: [dropFar, dropClose],
        );

        final result = engine.evaluateAnswer(
          userAnswer: 42,
          state: state,
          mode: GameMode.aprendizaje,
        );

        expect(result.correct, isTrue);
        expect(result.hitDrop!.y, 0.8); // La más cercana
      });

      test('incrementa racha en acierto', () {
        final drop = _createDrop(answer: 10);
        final state = GameState(
          activeDrops: [drop],
          streak: 5,
        );

        final result = engine.evaluateAnswer(
          userAnswer: 10,
          state: state,
          mode: GameMode.aprendizaje,
        );

        expect(result.newStreak, 6);
      });

      test('resetea racha en fallo', () {
        final drop = _createDrop(answer: 10);
        final state = GameState(
          activeDrops: [drop],
          streak: 10,
        );

        final result = engine.evaluateAnswer(
          userAnswer: 999,
          state: state,
          mode: GameMode.aprendizaje,
        );

        expect(result.newStreak, 0);
      });
    });

    group('puntos', () {
      test('tier más alto da más puntos base', () {
        final dropTier1 = _createDrop(answer: 5, tier: 1, ageMs: 2500);
        final dropTier5 = _createDrop(answer: 100, tier: 5, ageMs: 2500);

        final state1 = GameState(activeDrops: [dropTier1], streak: 0);
        final state5 = GameState(activeDrops: [dropTier5], streak: 0);

        final result1 = engine.evaluateAnswer(
          userAnswer: 5,
          state: state1,
          mode: GameMode.aprendizaje,
        );
        
        final result5 = engine.evaluateAnswer(
          userAnswer: 100,
          state: state5,
          mode: GameMode.aprendizaje,
        );

        expect(result5.pointsGained, greaterThan(result1.pointsGained));
      });

      test('respuesta rápida da bonus', () {
        final fastDrop = _createDrop(answer: 10, tier: 2, ageMs: 1000);
        final slowDrop = _createDrop(answer: 20, tier: 2, ageMs: 4000);

        final fastState = GameState(activeDrops: [fastDrop], streak: 0);
        final slowState = GameState(activeDrops: [slowDrop], streak: 0);

        final fastResult = engine.evaluateAnswer(
          userAnswer: 10,
          state: fastState,
          mode: GameMode.aprendizaje,
        );
        
        final slowResult = engine.evaluateAnswer(
          userAnswer: 20,
          state: slowState,
          mode: GameMode.aprendizaje,
        );

        expect(fastResult.pointsGained, greaterThan(slowResult.pointsGained));
      });

      test('racha alta da bonus', () {
        final drop1 = _createDrop(answer: 10, tier: 2, ageMs: 2500);
        final drop2 = _createDrop(answer: 20, tier: 2, ageMs: 2500);

        final noStreakState = GameState(activeDrops: [drop1], streak: 0);
        final streakState = GameState(activeDrops: [drop2], streak: 15);

        final noStreakResult = engine.evaluateAnswer(
          userAnswer: 10,
          state: noStreakState,
          mode: GameMode.aprendizaje,
        );
        
        final streakResult = engine.evaluateAnswer(
          userAnswer: 20,
          state: streakState,
          mode: GameMode.aprendizaje,
        );

        expect(streakResult.pointsGained, greaterThan(noStreakResult.pointsGained));
      });

      test('modo supervivencia da más puntos', () {
        final drop = _createDrop(answer: 10, tier: 2, ageMs: 2500);
        final state = GameState(activeDrops: [drop], streak: 0);

        final normalResult = engine.evaluateAnswer(
          userAnswer: 10,
          state: state,
          mode: GameMode.aprendizaje,
        );
        
        final survivalResult = engine.evaluateAnswer(
          userAnswer: 10,
          state: state,
          mode: GameMode.supervivencia,
        );

        expect(survivalResult.pointsGained, greaterThan(normalResult.pointsGained));
      });
    });

    group('calculateMiss', () {
      test('pierde una vida y resetea racha', () {
        final drop = _createDrop(answer: 42);
        final state = const GameState(streak: 5, lives: 3);

        final result = engine.calculateMiss(drop: drop, state: state);

        expect(result.livesLost, 1);
        expect(result.streakReset, isTrue);
      });

      test('mensaje incluye operación y respuesta', () {
        final drop = FallingDrop(
          id: 'test',
          operation: const Operation(
            expression: '7 × 8',
            answer: 56,
            type: OperationType.multiplication,
            tier: 2,
          ),
          x: 0.5,
          y: 1.0,
          speed: 0.1,
          spawnedAt: DateTime.now(),
        );
        final state = const GameState();

        final result = engine.calculateMiss(drop: drop, state: state);

        expect(result.message, contains('7 × 8'));
        expect(result.message, contains('56'));
      });
    });

    group('checkGameEnd', () {
      test('detecta fin por vidas agotadas', () {
        final state = const GameState(lives: 0, score: 150);

        final result = engine.checkGameEnd(state);

        expect(result, isNotNull);
        expect(result!.reason, GameEndReason.noLives);
        expect(result.victory, isFalse);
        expect(result.finalScore, 150);
      });

      test('detecta fin por tiempo en modo porTiempo', () {
        final state = const GameState(
          mode: GameMode.porTiempo,
          timeRemaining: Duration.zero,
          score: 200,
        );

        final result = engine.checkGameEnd(state);

        expect(result, isNotNull);
        expect(result!.reason, GameEndReason.timeUp);
        expect(result.victory, isTrue);
      });

      test('detecta objetivo alcanzado en modo porPuntuacion', () {
        final state = const GameState(
          mode: GameMode.porPuntuacion,
          targetScore: 500,
          score: 520,
        );

        final result = engine.checkGameEnd(state);

        expect(result, isNotNull);
        expect(result!.reason, GameEndReason.targetReached);
        expect(result.victory, isTrue);
      });

      test('retorna null cuando juego continúa', () {
        final state = const GameState(
          lives: 3,
          score: 100,
        );

        final result = engine.checkGameEnd(state);

        expect(result, isNull);
      });
    });

    group('calculateEndGameBonus', () {
      test('da bonus por vidas restantes', () {
        final stateWithLives = const GameState(lives: 5, correctThisSession: 10, incorrectThisSession: 10);
        final stateNoLives = const GameState(lives: 0, correctThisSession: 10, incorrectThisSession: 10);

        final bonusWithLives = engine.calculateEndGameBonus(stateWithLives);
        final bonusNoLives = engine.calculateEndGameBonus(stateNoLives);

        expect(bonusWithLives, greaterThan(bonusNoLives));
      });

      test('da bonus por alta precisión', () {
        final highAccuracy = const GameState(
          correctThisSession: 90,
          incorrectThisSession: 10,
          lives: 0,
        );
        final lowAccuracy = const GameState(
          correctThisSession: 50,
          incorrectThisSession: 50,
          lives: 0,
        );

        final bonusHigh = engine.calculateEndGameBonus(highAccuracy);
        final bonusLow = engine.calculateEndGameBonus(lowAccuracy);

        expect(bonusHigh, greaterThan(bonusLow));
      });

      test('da bonus por racha', () {
        final withStreak = const GameState(streak: 10, lives: 0);
        final noStreak = const GameState(streak: 0, lives: 0);

        final bonusWithStreak = engine.calculateEndGameBonus(withStreak);
        final bonusNoStreak = engine.calculateEndGameBonus(noStreak);

        expect(bonusWithStreak, greaterThan(bonusNoStreak));
      });
    });
  });
}
