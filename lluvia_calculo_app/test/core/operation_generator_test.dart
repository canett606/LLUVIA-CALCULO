import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/core/operation_generator.dart';
import 'package:lluvia_calculo/models/operation.dart';
import 'package:lluvia_calculo/models/player_profile.dart';

void main() {
  group('OperationGenerator', () {
    late OperationGenerator generator;

    setUp(() {
      generator = OperationGenerator(Random(42)); // Seed fijo para reproducibilidad
    });

    group('Variedad de operaciones', () {
      test('genera sumas válidas en todos los tiers', () {
        for (int tier = 1; tier <= 5; tier++) {
          final op = generator.generate(tier: tier, family: OperationFamily.sumas);
          
          expect(op.type, equals(OperationType.addition));
          expect(op.tier, equals(tier));
          expect(op.answer, isPositive);
          expect(op.expression.contains('+'), isTrue);
          
          // Verificar que la respuesta es correcta
          final parts = op.expression.split(' + ');
          expect(int.parse(parts[0]) + int.parse(parts[1]), equals(op.answer));
        }
      });

      test('genera restas con resultado positivo', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 3, family: OperationFamily.restas);
          
          expect(op.type, equals(OperationType.subtraction));
          expect(op.answer, greaterThanOrEqualTo(0), 
            reason: 'Resta ${op.expression} = ${op.answer} debe ser >= 0');
        }
      });

      test('genera multiplicaciones válidas', () {
        for (int tier = 1; tier <= 5; tier++) {
          final op = generator.generate(tier: tier, family: OperationFamily.multiplicaciones);
          
          expect(op.type, equals(OperationType.multiplication));
          expect(op.expression.contains('×'), isTrue);
          
          final parts = op.expression.split(' × ');
          expect(int.parse(parts[0]) * int.parse(parts[1]), equals(op.answer));
        }
      });

      test('genera divisiones exactas', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 3, family: OperationFamily.divisiones);
          
          expect(op.type, equals(OperationType.division));
          expect(op.expression.contains('÷'), isTrue);
          
          final parts = op.expression.split(' ÷ ');
          final dividend = int.parse(parts[0]);
          final divisor = int.parse(parts[1]);
          expect(dividend % divisor, equals(0), 
            reason: 'División $dividend ÷ $divisor debe ser exacta');
          expect(dividend ~/ divisor, equals(op.answer));
        }
      });

      test('genera operaciones mixtas válidas', () {
        for (int tier = 1; tier <= 5; tier++) {
          final op = generator.generate(tier: tier, family: OperationFamily.mixtas);
          
          expect(op.type, equals(OperationType.mixed));
          expect(op.answer, greaterThanOrEqualTo(0),
            reason: 'Mixta ${op.expression} = ${op.answer} debe ser >= 0');
        }
      });
    });

    group('No repetición de expresiones', () {
      test('no repite expresiones en la misma sesión', () {
        generator.resetSession();
        final expressions = <String>{};
        
        for (int i = 0; i < 50; i++) {
          final op = generator.generate(tier: 2, family: OperationFamily.todas);
          expect(expressions.contains(op.expression), isFalse,
            reason: 'Expresión ${op.expression} repetida');
          expressions.add(op.expression);
        }
      });

      test('resetSession limpia el historial', () {
        generator.resetSession();
        
        final firstBatch = <String>[];
        for (int i = 0; i < 20; i++) {
          firstBatch.add(generator.generate(tier: 1, family: OperationFamily.sumas).expression);
        }
        
        generator.resetSession();
        
        // Después de reset, puede repetir
        final secondBatch = <String>[];
        for (int i = 0; i < 20; i++) {
          secondBatch.add(generator.generate(tier: 1, family: OperationFamily.sumas).expression);
        }
        
        // Debe haber alguna repetición potencial (con el mismo seed)
        final intersection = firstBatch.toSet().intersection(secondBatch.toSet());
        // Con seed fijo y reset, es probable que haya coincidencias
        expect(intersection, isNotEmpty);
      });
    });

    group('Control por tier', () {
      test('tier 1 genera operaciones simples', () {
        for (int i = 0; i < 20; i++) {
          final op = generator.generate(tier: 1, family: OperationFamily.sumas);
          expect(op.answer, lessThanOrEqualTo(18),
            reason: 'Tier 1 suma ${op.expression} = ${op.answer} debe ser <= 18');
        }
      });

      test('tier 1 multiplicaciones usa tablas 1-5', () {
        for (int i = 0; i < 20; i++) {
          final op = generator.generate(tier: 1, family: OperationFamily.multiplicaciones);
          final parts = op.expression.split(' × ');
          expect(int.parse(parts[0]), lessThanOrEqualTo(5));
          expect(int.parse(parts[1]), lessThanOrEqualTo(5));
        }
      });

      test('tier 5 genera números más grandes', () {
        bool hasLargeAnswer = false;
        for (int i = 0; i < 20; i++) {
          final op = generator.generate(tier: 5, family: OperationFamily.sumas);
          if (op.answer > 200) hasLargeAnswer = true;
        }
        expect(hasLargeAnswer, isTrue, 
          reason: 'Tier 5 debe generar sumas con resultados > 200');
      });
    });

    group('Generación adaptativa', () {
      test('genera operaciones adaptadas al perfil del jugador', () {
        final profile = PlayerProfile.create('TestPlayer').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(
              correct: 20,
              incorrect: 2,
              maxTierUnlocked: 3,
            ),
            OperationFamily.restas: const FamilyStats(
              correct: 5,
              incorrect: 10,
              maxTierUnlocked: 1,
            ),
          },
        );

        // Generar varias operaciones adaptativas
        for (int i = 0; i < 10; i++) {
          final op = generator.generateAdaptive(
            profile: profile,
            currentTier: 2,
            selectedFamily: OperationFamily.todas,
          );
          
          expect(op, isNotNull);
          expect(op.answer, greaterThan(0));
        }
      });

      test('prioriza familias débiles', () {
        final profile = PlayerProfile.create('TestPlayer').copyWith(
          familyStats: {
            OperationFamily.sumas: const FamilyStats(
              correct: 50,
              incorrect: 5,
              maxTierUnlocked: 4,
            ),
            // Restas muy débil
            OperationFamily.restas: const FamilyStats(
              correct: 3,
              incorrect: 12,
              maxTierUnlocked: 1,
            ),
          },
        );

        int restasCount = 0;
        for (int i = 0; i < 50; i++) {
          final op = generator.generateAdaptive(
            profile: profile,
            currentTier: 2,
            selectedFamily: OperationFamily.todas,
          );
          if (op.type == OperationType.subtraction) restasCount++;
        }
        
        // Debería haber una buena cantidad de restas por ser la familia débil
        expect(restasCount, greaterThan(5),
          reason: 'Debe practicar más la familia débil (restas)');
      });
    });

    group('Generación por lote', () {
      test('genera lote sin respuestas duplicadas', () {
        final ops = generator.generateBatch(
          tier: 2,
          count: 10,
          family: OperationFamily.todas,
          avoidDuplicateAnswers: true,
        );
        
        expect(ops.length, equals(10));
        
        final answers = ops.map((op) => op.answer).toSet();
        expect(answers.length, equals(10),
          reason: 'No debe haber respuestas duplicadas');
      });

      test('genera lote de tamaño solicitado', () {
        final ops = generator.generateBatch(
          tier: 3,
          count: 15,
          family: OperationFamily.multiplicaciones,
        );
        
        expect(ops.length, equals(15));
        for (final op in ops) {
          expect(op.type, equals(OperationType.multiplication));
        }
      });
    });

    group('Estadísticas del generador', () {
      test('trackea expresiones usadas', () {
        generator.resetSession();
        
        for (int i = 0; i < 30; i++) {
          generator.generate(tier: 2, family: OperationFamily.todas);
        }
        
        final stats = generator.getStats();
        expect(stats['usedExpressions'], greaterThanOrEqualTo(30));
        expect(stats['sessionOperationCount'], equals(30));
      });
    });
  });
}
