import 'dart:math';
import '../models/operation.dart';
import '../models/player_profile.dart';

/// Generador procedural de operaciones matemáticas con ALTA VARIEDAD.
/// 
/// Principios:
/// - Genera operaciones proceduralmente, nunca de lista fija
/// - Evita repetir la misma expresión en una sesión
/// - Familias: sumas, restas, multiplicaciones, divisiones, mixtas
/// - Tiers 1-5: desde principiantes (1+2) hasta avanzado (3 cifras, mixtas)
class OperationGenerator {
  final Random _random;
  final Set<String> _usedExpressions = {};
  int _sessionOperationCount = 0;

  OperationGenerator([Random? random]) : _random = random ?? Random();

  /// Reinicia el tracking de expresiones usadas (nueva sesión)
  void resetSession() {
    _usedExpressions.clear();
    _sessionOperationCount = 0;
  }

  /// Genera operación según tier, familia y memoria del jugador
  Operation generate({
    required int tier,
    OperationFamily family = OperationFamily.todas,
    FamilyStats? playerStats,
    int maxAttempts = 50,
  }) {
    final effectiveTier = tier.clamp(1, 5);
    _sessionOperationCount++;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final availableTypes = _getTypesForFamily(family, effectiveTier);
      final selectedType = availableTypes[_random.nextInt(availableTypes.length)];
      
      final op = _generateForType(selectedType, effectiveTier);
      
      // Verificar no-repetición
      if (!_usedExpressions.contains(op.expression)) {
        _usedExpressions.add(op.expression);
        
        // Limpiar cache si crece demasiado (evitar memory leak)
        if (_usedExpressions.length > 500) {
          final toRemove = _usedExpressions.take(200).toList();
          for (final expr in toRemove) {
            _usedExpressions.remove(expr);
          }
        }
        
        return op;
      }
    }
    
    // Fallback: generar con variación forzada
    return _generateWithVariation(family, effectiveTier);
  }

  /// Genera un lote de operaciones para una partida
  List<Operation> generateBatch({
    required int tier,
    required int count,
    OperationFamily family = OperationFamily.todas,
    bool avoidDuplicateAnswers = true,
  }) {
    final operations = <Operation>[];
    final usedAnswers = <int>{};
    
    for (int i = 0; i < count && operations.length < count; i++) {
      final op = generate(tier: tier, family: family);
      if (!avoidDuplicateAnswers || !usedAnswers.contains(op.answer)) {
        operations.add(op);
        usedAnswers.add(op.answer);
      }
    }
    
    return operations;
  }

  /// Genera operación adaptativa basada en memoria del jugador
  Operation generateAdaptive({
    required PlayerProfile profile,
    required int currentTier,
    required OperationFamily selectedFamily,
  }) {
    // Si el jugador tiene familias débiles, practicarlas más
    OperationFamily targetFamily = selectedFamily;
    
    if (selectedFamily == OperationFamily.todas && _random.nextDouble() < 0.4) {
      // 40% chance de practicar familia débil
      final weakFamily = _findWeakestFamily(profile);
      if (weakFamily != null) {
        targetFamily = weakFamily;
      }
    }
    
    // Determinar tier efectivo basado en stats de esa familia
    int effectiveTier = currentTier;
    final familyStats = profile.familyStats[targetFamily];
    if (familyStats != null) {
      // Si tiene buena precisión en esa familia, puede subir
      if (familyStats.accuracy > 0.85 && familyStats.correct >= 10) {
        effectiveTier = min(5, familyStats.maxTierUnlocked + 1);
      }
      // Si está luchando, bajar
      else if (familyStats.accuracy < 0.5 && familyStats.incorrect >= 5) {
        effectiveTier = max(1, currentTier - 1);
      }
    }
    
    return generate(tier: effectiveTier, family: targetFamily);
  }

  OperationFamily? _findWeakestFamily(PlayerProfile profile) {
    final families = [
      OperationFamily.sumas,
      OperationFamily.restas,
      OperationFamily.multiplicaciones,
      OperationFamily.divisiones,
    ];
    
    OperationFamily? weakest;
    double lowestAccuracy = 1.0;
    
    for (final family in families) {
      final stats = profile.familyStats[family];
      if (stats == null) {
        // Familia sin datos = prioridad
        return family;
      }
      if (stats.correct + stats.incorrect < 5) {
        // Poco practicada = prioridad
        return family;
      }
      if (stats.accuracy < lowestAccuracy) {
        lowestAccuracy = stats.accuracy;
        weakest = family;
      }
    }
    
    return weakest;
  }

  List<OperationType> _getTypesForFamily(OperationFamily family, int tier) {
    switch (family) {
      case OperationFamily.sumas:
        return [OperationType.addition];
      case OperationFamily.restas:
        return [OperationType.subtraction];
      case OperationFamily.multiplicaciones:
        return [OperationType.multiplication];
      case OperationFamily.divisiones:
        return [OperationType.division];
      case OperationFamily.mixtas:
        return [OperationType.mixed];
      case OperationFamily.todas:
        if (tier == 1) {
          return [OperationType.addition, OperationType.subtraction];
        } else if (tier == 2) {
          return [
            OperationType.addition,
            OperationType.subtraction,
            OperationType.multiplication,
          ];
        } else {
          return OperationType.values;
        }
    }
  }

  Operation _generateForType(OperationType type, int tier) {
    switch (type) {
      case OperationType.addition:
        return _generateAddition(tier);
      case OperationType.subtraction:
        return _generateSubtraction(tier);
      case OperationType.multiplication:
        return _generateMultiplication(tier);
      case OperationType.division:
        return _generateDivision(tier);
      case OperationType.mixed:
        return _generateMixed(tier);
    }
  }

  Operation _generateWithVariation(OperationFamily family, int tier) {
    final types = _getTypesForFamily(family, tier);
    final type = types[_random.nextInt(types.length)];
    
    // Añadir variación forzada con un offset aleatorio
    final offset = _sessionOperationCount % 10;
    
    switch (type) {
      case OperationType.addition:
        return _generateAdditionWithOffset(tier, offset);
      case OperationType.subtraction:
        return _generateSubtractionWithOffset(tier, offset);
      case OperationType.multiplication:
        return _generateMultiplicationWithOffset(tier, offset);
      case OperationType.division:
        return _generateDivisionWithOffset(tier, offset);
      case OperationType.mixed:
        return _generateMixedWithOffset(tier, offset);
    }
  }

  // ========== SUMAS ==========
  // Tier 1: 1-9 + 1-9, resultado <= 18
  // Tier 2: 1-20 + 1-20
  // Tier 3: 10-99 + 10-99 (con llevadas)
  // Tier 4: 50-200 + 50-200
  // Tier 5: 100-500 + 100-500

  Operation _generateAddition(int tier) {
    int a, b;
    
    switch (tier) {
      case 1:
        // Principiante: sumas muy simples
        a = _random.nextInt(9) + 1;
        b = _random.nextInt(min(9, 18 - a)) + 1;
        break;
      case 2:
        // Básico: hasta 20+20
        a = _random.nextInt(20) + 1;
        b = _random.nextInt(20) + 1;
        break;
      case 3:
        // Intermedio: dos dígitos con llevadas
        a = _random.nextInt(90) + 10;
        b = _random.nextInt(90) + 10;
        break;
      case 4:
        // Avanzado: números mayores
        a = _random.nextInt(150) + 50;
        b = _random.nextInt(150) + 50;
        break;
      case 5:
      default:
        // Experto: tres dígitos
        a = _random.nextInt(400) + 100;
        b = _random.nextInt(400) + 100;
        break;
    }

    return Operation(
      expression: '$a + $b',
      answer: a + b,
      type: OperationType.addition,
      tier: tier,
      complexity: tier,
    );
  }

  Operation _generateAdditionWithOffset(int tier, int offset) {
    int a, b;
    final baseOffset = offset * 3;
    
    switch (tier) {
      case 1:
        a = ((offset % 9) + 1);
        b = (((offset * 2) % 8) + 1);
        break;
      case 2:
        a = _random.nextInt(20) + 1 + baseOffset % 10;
        b = _random.nextInt(20) + 1 + baseOffset % 10;
        break;
      default:
        a = _random.nextInt(100) + 10 + baseOffset;
        b = _random.nextInt(100) + 10 + baseOffset;
    }

    return Operation(
      expression: '$a + $b',
      answer: a + b,
      type: OperationType.addition,
      tier: tier,
      complexity: tier,
    );
  }

  // ========== RESTAS ==========
  // Siempre resultado positivo
  // Tier 1: resultado 1-10
  // Tier 2: resultado hasta 20
  // Tier 3: resultado hasta 50, minuendo hasta 100
  // Tier 4: minuendo hasta 300
  // Tier 5: minuendo hasta 500

  Operation _generateSubtraction(int tier) {
    int a, b;
    
    switch (tier) {
      case 1:
        // Principiante: resultado positivo pequeño
        final result = _random.nextInt(9) + 1;
        b = _random.nextInt(9) + 1;
        a = result + b;
        break;
      case 2:
        // Básico
        final result = _random.nextInt(20) + 1;
        b = _random.nextInt(15) + 1;
        a = result + b;
        break;
      case 3:
        // Intermedio: con llevadas
        final result = _random.nextInt(50) + 1;
        b = _random.nextInt(50) + 10;
        a = result + b;
        break;
      case 4:
        // Avanzado
        final result = _random.nextInt(100) + 20;
        b = _random.nextInt(100) + 50;
        a = result + b;
        break;
      case 5:
      default:
        // Experto
        final result = _random.nextInt(200) + 50;
        b = _random.nextInt(200) + 100;
        a = result + b;
        break;
    }

    return Operation(
      expression: '$a - $b',
      answer: a - b,
      type: OperationType.subtraction,
      tier: tier,
      complexity: tier,
    );
  }

  Operation _generateSubtractionWithOffset(int tier, int offset) {
    final result = (offset + 1) * (tier + 1);
    final b = (offset + 2) * tier;
    final a = result + b;

    return Operation(
      expression: '$a - $b',
      answer: result,
      type: OperationType.subtraction,
      tier: tier,
      complexity: tier,
    );
  }

  // ========== MULTIPLICACIONES ==========
  // Tier 1: tablas del 1-5
  // Tier 2: tablas del 1-10
  // Tier 3: tablas del 2-12
  // Tier 4: un factor hasta 15, otro hasta 12
  // Tier 5: factores hasta 20

  Operation _generateMultiplication(int tier) {
    int a, b;
    
    switch (tier) {
      case 1:
        // Tablas básicas 1-5
        a = _random.nextInt(5) + 1;
        b = _random.nextInt(5) + 1;
        break;
      case 2:
        // Tablas del 1-10
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        break;
      case 3:
        // Tablas extendidas 2-12
        a = _random.nextInt(11) + 2;
        b = _random.nextInt(11) + 2;
        break;
      case 4:
        // Un factor mayor
        a = _random.nextInt(14) + 2;
        b = _random.nextInt(12) + 2;
        break;
      case 5:
      default:
        // Factores grandes
        a = _random.nextInt(18) + 3;
        b = _random.nextInt(15) + 2;
        break;
    }

    return Operation(
      expression: '$a × $b',
      answer: a * b,
      type: OperationType.multiplication,
      tier: tier,
      complexity: tier,
    );
  }

  Operation _generateMultiplicationWithOffset(int tier, int offset) {
    final a = (offset % 10) + tier;
    final b = ((offset + 3) % 10) + 1;

    return Operation(
      expression: '$a × $b',
      answer: a * b,
      type: OperationType.multiplication,
      tier: tier,
      complexity: tier,
    );
  }

  // ========== DIVISIONES ==========
  // Siempre resultado entero exacto
  // Tier 1: divisor 1-2, cociente 1-10
  // Tier 2: divisor 1-5, cociente 1-10
  // Tier 3: divisor 2-10, cociente 2-12
  // Tier 4: divisor 2-12, cociente 2-15
  // Tier 5: divisor 2-15, cociente 3-20

  Operation _generateDivision(int tier) {
    int quotient, divisor;
    
    switch (tier) {
      case 1:
        // División simple: ÷1 o ÷2
        quotient = _random.nextInt(10) + 1;
        divisor = _random.nextInt(2) + 1;
        break;
      case 2:
        // División por 1-5
        quotient = _random.nextInt(10) + 1;
        divisor = _random.nextInt(5) + 1;
        break;
      case 3:
        // División por 2-10
        quotient = _random.nextInt(11) + 2;
        divisor = _random.nextInt(9) + 2;
        break;
      case 4:
        // División mayor
        quotient = _random.nextInt(14) + 2;
        divisor = _random.nextInt(11) + 2;
        break;
      case 5:
      default:
        // División compleja
        quotient = _random.nextInt(18) + 3;
        divisor = _random.nextInt(14) + 2;
        break;
    }

    final dividend = quotient * divisor;

    return Operation(
      expression: '$dividend ÷ $divisor',
      answer: quotient,
      type: OperationType.division,
      tier: tier,
      complexity: tier + 1,
    );
  }

  Operation _generateDivisionWithOffset(int tier, int offset) {
    final quotient = (offset % 10) + 2;
    final divisor = (offset % 5) + 2;
    final dividend = quotient * divisor;

    return Operation(
      expression: '$dividend ÷ $divisor',
      answer: quotient,
      type: OperationType.division,
      tier: tier,
      complexity: tier + 1,
    );
  }

  // ========== MIXTAS (2 pasos) ==========
  // Tier 1-2: solo + y - con números pequeños
  // Tier 3: incluye × con precedencia
  // Tier 4-5: combinaciones complejas

  Operation _generateMixed(int tier) {
    final operators = tier <= 2 ? ['+', '-'] : ['+', '-', '×'];
    final op1 = operators[_random.nextInt(operators.length)];
    final op2 = operators[_random.nextInt(operators.length)];
    
    int a, b, c, result;
    String expression;
    
    switch (tier) {
      case 1:
      case 2:
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        c = _random.nextInt(10) + 1;
        break;
      case 3:
        a = _random.nextInt(15) + 5;
        b = _random.nextInt(10) + 2;
        c = _random.nextInt(10) + 2;
        break;
      case 4:
      case 5:
      default:
        a = _random.nextInt(25) + 10;
        b = _random.nextInt(15) + 2;
        c = _random.nextInt(15) + 2;
        break;
    }

    // Calcular con precedencia correcta
    if (op1 == '×' || op2 == '×') {
      if (op2 == '×') {
        final product = b * c;
        if (op1 == '+') {
          result = a + product;
          expression = '$a + $b × $c';
        } else {
          result = a - product;
          expression = '$a - $b × $c';
          if (result < 0) {
            result = a + product;
            expression = '$a + $b × $c';
          }
        }
      } else {
        final product = a * b;
        if (op2 == '+') {
          result = product + c;
        } else {
          result = product - c;
        }
        expression = '$a × $b $op2 $c';
        if (result < 0) {
          result = product + c;
          expression = '$a × $b + $c';
        }
      }
    } else {
      int temp = op1 == '+' ? a + b : a - b;
      result = op2 == '+' ? temp + c : temp - c;
      expression = '$a $op1 $b $op2 $c';
      
      if (result < 0) {
        result = a + b + c;
        expression = '$a + $b + $c';
      }
    }

    return Operation(
      expression: expression,
      answer: result,
      type: OperationType.mixed,
      tier: tier,
      complexity: tier + 2,
    );
  }

  Operation _generateMixedWithOffset(int tier, int offset) {
    final a = offset + tier + 5;
    final b = (offset % 5) + 2;
    final c = (offset % 4) + 1;
    
    final result = a + b * c;
    final expression = '$a + $b × $c';

    return Operation(
      expression: expression,
      answer: result,
      type: OperationType.mixed,
      tier: tier,
      complexity: tier + 2,
    );
  }

  // ========== UTILITY ==========

  /// Obtiene estadísticas del generador (para debug)
  Map<String, dynamic> getStats() {
    return {
      'usedExpressions': _usedExpressions.length,
      'sessionOperationCount': _sessionOperationCount,
    };
  }
}
