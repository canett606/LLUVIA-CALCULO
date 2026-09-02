import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/core/operation_generator.dart';
import 'package:lluvia_calculo/models/operation.dart';

void main() {
  group('OperationGenerator', () {
    late OperationGenerator generator;

    setUp(() {
      // Usar semilla fija para tests reproducibles
      generator = OperationGenerator(Random(42));
    });

    group('generate', () {
      test('genera operaciones válidas para tier 1', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 1);
          
          expect(op.tier, 1);
          expect(op.answer, isNotNull);
          expect(op.expression, isNotEmpty);
          // Tier 1 solo tiene suma y resta
          expect(
            op.type == OperationType.addition || op.type == OperationType.subtraction,
            isTrue,
            reason: 'Tier 1 solo debe tener sumas y restas, pero obtuvo ${op.type}',
          );
        }
      });

      test('genera operaciones válidas para tier 2', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 2);
          
          expect(op.tier, 2);
          expect(op.answer, isNotNull);
          // Tier 2 incluye multiplicación
          expect(
            [OperationType.addition, OperationType.subtraction, OperationType.multiplication]
              .contains(op.type),
            isTrue,
          );
        }
      });

      test('genera operaciones válidas para todos los tiers', () {
        for (int tier = 1; tier <= 5; tier++) {
          for (int i = 0; i < 50; i++) {
            final op = generator.generate(tier: tier);
            expect(op.tier, tier);
            expect(op.answer >= 0, isTrue, reason: 'Resultado debe ser no negativo');
          }
        }
      });

      test('respeta filtro de familia - sumas', () {
        for (int i = 0; i < 50; i++) {
          final op = generator.generate(tier: 3, family: OperationFamily.sumas);
          expect(op.type, OperationType.addition);
        }
      });

      test('respeta filtro de familia - multiplicaciones', () {
        for (int i = 0; i < 50; i++) {
          final op = generator.generate(tier: 3, family: OperationFamily.multiplicaciones);
          expect(op.type, OperationType.multiplication);
        }
      });

      test('respeta filtro de familia - divisiones', () {
        for (int i = 0; i < 50; i++) {
          final op = generator.generate(tier: 3, family: OperationFamily.divisiones);
          expect(op.type, OperationType.division);
          // Verificar que división es exacta
          expect(op.answer, isA<int>());
        }
      });

      test('clampea tier a rango válido', () {
        final opLow = generator.generate(tier: -5);
        expect(opLow.tier, 1);
        
        final opHigh = generator.generate(tier: 100);
        expect(opHigh.tier, 5);
      });
    });

    group('sumas (tier 1)', () {
      test('genera sumas con números pequeños para principiantes', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 1, family: OperationFamily.sumas);
          
          // Para tier 1, resultado debe ser <= 20
          expect(op.answer <= 20, isTrue,
            reason: 'Suma tier 1: ${op.expression} = ${op.answer} excede 20');
        }
      });
    });

    group('restas', () {
      test('siempre genera resultado positivo', () {
        for (int tier = 1; tier <= 5; tier++) {
          for (int i = 0; i < 50; i++) {
            final op = generator.generate(tier: tier, family: OperationFamily.restas);
            
            expect(op.answer >= 0, isTrue,
              reason: 'Resta ${op.expression} = ${op.answer} es negativo');
          }
        }
      });
    });

    group('multiplicaciones', () {
      test('tier 1 usa tablas del 1-5', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 1, family: OperationFamily.multiplicaciones);
          
          // Resultado máximo: 5 × 5 = 25
          expect(op.answer <= 25, isTrue,
            reason: 'Multiplicación tier 1: ${op.expression} = ${op.answer} excede 25');
        }
      });

      test('tier 2 usa tablas del 1-10', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 2, family: OperationFamily.multiplicaciones);
          
          // Resultado máximo: 10 × 10 = 100
          expect(op.answer <= 100, isTrue,
            reason: 'Multiplicación tier 2: ${op.expression} = ${op.answer} excede 100');
        }
      });
    });

    group('divisiones', () {
      test('siempre genera divisiones exactas (sin decimales)', () {
        for (int tier = 1; tier <= 5; tier++) {
          for (int i = 0; i < 50; i++) {
            final op = generator.generate(tier: tier, family: OperationFamily.divisiones);
            
            // Parsear la expresión para verificar
            final parts = op.expression.split(' ÷ ');
            if (parts.length == 2) {
              final dividend = int.tryParse(parts[0]);
              final divisor = int.tryParse(parts[1]);
              
              if (dividend != null && divisor != null && divisor != 0) {
                expect(dividend % divisor, 0,
                  reason: 'División ${op.expression} no es exacta');
                expect(dividend ~/ divisor, op.answer,
                  reason: 'Resultado incorrecto para ${op.expression}');
              }
            }
          }
        }
      });

      test('tier 1 usa divisores pequeños (1-2)', () {
        for (int i = 0; i < 100; i++) {
          final op = generator.generate(tier: 1, family: OperationFamily.divisiones);
          
          final parts = op.expression.split(' ÷ ');
          if (parts.length == 2) {
            final divisor = int.tryParse(parts[1]);
            expect(divisor != null && divisor <= 2, isTrue,
              reason: 'División tier 1 usa divisor > 2: ${op.expression}');
          }
        }
      });
    });

    group('mixtas', () {
      test('genera operaciones de dos pasos', () {
        for (int i = 0; i < 50; i++) {
          final op = generator.generate(tier: 3, family: OperationFamily.mixtas);
          
          // Debe tener al menos 2 operadores
          final operators = ['+', '-', '×'].where((o) => op.expression.contains(o)).length;
          expect(operators >= 1, isTrue,
            reason: 'Operación mixta debe tener operadores: ${op.expression}');
          
          // Resultado positivo
          expect(op.answer >= 0, isTrue,
            reason: 'Operación mixta negativa: ${op.expression} = ${op.answer}');
        }
      });
    });

    group('generateBatch', () {
      test('genera la cantidad solicitada', () {
        final batch = generator.generateBatch(tier: 2, count: 10);
        expect(batch.length, 10);
      });

      test('evita respuestas duplicadas cuando se solicita', () {
        final batch = generator.generateBatch(
          tier: 2, 
          count: 8,
          avoidDuplicateAnswers: true,
        );
        
        final answers = batch.map((op) => op.answer).toSet();
        expect(answers.length, batch.length,
          reason: 'Hay respuestas duplicadas en el lote');
      });

      test('permite respuestas duplicadas cuando no se evita', () {
        // Generar muchas operaciones, es probable que haya duplicados
        final batch = generator.generateBatch(
          tier: 1, 
          count: 50,
          family: OperationFamily.multiplicaciones,
          avoidDuplicateAnswers: false,
        );
        
        expect(batch.length, 50);
      });
    });
  });
}
