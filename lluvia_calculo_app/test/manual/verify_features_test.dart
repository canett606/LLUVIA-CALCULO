import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/core/operation_generator.dart';
import 'package:lluvia_calculo/core/scoring_engine.dart';
import 'package:lluvia_calculo/models/operation.dart';
import 'package:lluvia_calculo/models/game_state.dart';

void main() {
  test('niveles 6-10 generan ops y autovalidación coincide con gotas', () {
    final gen = OperationGenerator();
    for (final tier in [6, 7, 8, 9, 10]) {
      for (var i = 0; i < 8; i++) {
        final op = gen.generate(tier: tier, family: OperationFamily.todas);
        expect(op.tier, tier);
        expect(op.expression, isNotEmpty);
      }
    }

    final engine = ScoringEngine();
    final dropA = FallingDrop(
      id: 'a',
      operation: const Operation(expression: '12 + 7 × 3', answer: 33, type: OperationType.mixed, tier: 7),
      x: 0.2, y: 0.3, speed: 0.1, spawnedAt: DateTime.now(),
    );
    final dropB = FallingDrop(
      id: 'b',
      operation: const Operation(expression: '5²', answer: 25, type: OperationType.power, tier: 9),
      x: 0.6, y: 0.7, speed: 0.1, spawnedAt: DateTime.now(),
    );
    final state = GameState.initial().copyWith(
      isRunning: true,
      activeDrops: [dropA, dropB],
    );

    // Coincide con cualquiera
    final r1 = engine.evaluateAnswer(userAnswer: 33, state: state, mode: GameMode.aprendizaje);
    expect(r1.correct, isTrue);
    expect(r1.hitDrop?.id, 'a');

    final r2 = engine.evaluateAnswer(userAnswer: 25, state: state, mode: GameMode.aprendizaje);
    expect(r2.correct, isTrue);
    expect(r2.hitDrop?.id, 'b');

    // No coincide: no hay hit
    final r3 = engine.evaluateAnswer(userAnswer: 99, state: state, mode: GameMode.aprendizaje);
    expect(r3.correct, isFalse);
  });
}
