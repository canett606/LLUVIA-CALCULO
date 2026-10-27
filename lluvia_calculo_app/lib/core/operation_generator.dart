import 'dart:math';
import '../models/operation.dart';
import '../models/player_profile.dart';

/// Generador procedural de operaciones matemáticas con ALTA VARIEDAD.
///
/// Tiers 1–5: básicos a avanzados (como antes).
/// Tiers 6–10: progresión dura (2 cifras ×/÷, encadenadas, paréntesis,
/// negativos, potencias y raíces exactas).
class OperationGenerator {
  final Random _random;
  final Set<String> _usedExpressions = {};
  int _sessionOperationCount = 0;

  static const int maxTier = OperationDifficulty.maxTier;

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
    final effectiveTier = tier.clamp(OperationDifficulty.minTier, maxTier);
    _sessionOperationCount++;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final availableTypes = _getTypesForFamily(family, effectiveTier);
      final selectedType = availableTypes[_random.nextInt(availableTypes.length)];

      final op = _generateForType(selectedType, effectiveTier);

      if (!_usedExpressions.contains(op.expression)) {
        _usedExpressions.add(op.expression);

        if (_usedExpressions.length > 500) {
          final toRemove = _usedExpressions.take(200).toList();
          for (final expr in toRemove) {
            _usedExpressions.remove(expr);
          }
        }

        return op;
      }
    }

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
    var attempts = 0;
    final maxAttempts = count * 20;

    while (operations.length < count && attempts < maxAttempts) {
      attempts++;
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
    OperationFamily targetFamily = selectedFamily;

    if (selectedFamily == OperationFamily.todas && _random.nextDouble() < 0.4) {
      final weakFamily = _findWeakestFamily(profile);
      if (weakFamily != null) {
        targetFamily = weakFamily;
      }
    }

    int effectiveTier = currentTier;
    final familyStats = profile.familyStats[targetFamily];
    if (familyStats != null) {
      if (familyStats.accuracy > 0.85 && familyStats.correct >= 10) {
        effectiveTier = min(maxTier, familyStats.maxTierUnlocked + 1);
      } else if (familyStats.accuracy < 0.5 && familyStats.incorrect >= 5) {
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
        return family;
      }
      if (stats.correct + stats.incorrect < 5) {
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
        if (tier >= 9) {
          return [OperationType.mixed, OperationType.power];
        }
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
        } else if (tier >= 9) {
          return [
            OperationType.addition,
            OperationType.subtraction,
            OperationType.multiplication,
            OperationType.division,
            OperationType.mixed,
            OperationType.power,
          ];
        } else if (tier >= 6) {
          return [
            OperationType.addition,
            OperationType.subtraction,
            OperationType.multiplication,
            OperationType.division,
            OperationType.mixed,
          ];
        } else {
          return [
            OperationType.addition,
            OperationType.subtraction,
            OperationType.multiplication,
            OperationType.division,
            OperationType.mixed,
          ];
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
      case OperationType.power:
        return _generatePowerOrRoot(tier);
    }
  }

  Operation _generateWithVariation(OperationFamily family, int tier) {
    final types = _getTypesForFamily(family, tier);
    final type = types[_random.nextInt(types.length)];
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
      case OperationType.power:
        return _generatePowerOrRoot(tier);
    }
  }

  // ========== SUMAS ==========
  Operation _generateAddition(int tier) {
    int a, b;

    switch (tier) {
      case 1:
        a = _random.nextInt(9) + 1;
        b = _random.nextInt(min(9, 18 - a)) + 1;
        break;
      case 2:
        a = _random.nextInt(20) + 1;
        b = _random.nextInt(20) + 1;
        break;
      case 3:
        a = _random.nextInt(90) + 10;
        b = _random.nextInt(90) + 10;
        break;
      case 4:
        a = _random.nextInt(150) + 50;
        b = _random.nextInt(150) + 50;
        break;
      case 5:
        a = _random.nextInt(400) + 100;
        b = _random.nextInt(400) + 100;
        break;
      case 6:
        a = _random.nextInt(700) + 200;
        b = _random.nextInt(700) + 200;
        break;
      case 7:
      case 8:
        a = _random.nextInt(900) + 100;
        b = _random.nextInt(900) + 100;
        break;
      default:
        a = _random.nextInt(1500) + 500;
        b = _random.nextInt(1500) + 500;
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
  Operation _generateSubtraction(int tier) {
    int a, b;
    int result;

    switch (tier) {
      case 1:
        result = _random.nextInt(9) + 1;
        b = _random.nextInt(9) + 1;
        a = result + b;
        break;
      case 2:
        result = _random.nextInt(20) + 1;
        b = _random.nextInt(15) + 1;
        a = result + b;
        break;
      case 3:
        result = _random.nextInt(50) + 1;
        b = _random.nextInt(50) + 10;
        a = result + b;
        break;
      case 4:
        result = _random.nextInt(100) + 20;
        b = _random.nextInt(100) + 50;
        a = result + b;
        break;
      case 5:
        result = _random.nextInt(200) + 50;
        b = _random.nextInt(200) + 100;
        a = result + b;
        break;
      case 6:
      case 7:
        result = _random.nextInt(300) + 50;
        b = _random.nextInt(400) + 100;
        a = result + b;
        break;
      case 8:
      case 9:
      case 10:
      default:
        // Negativos en niveles altos
        if (tier >= 8 && _random.nextBool()) {
          a = _random.nextInt(80) + 10;
          b = a + _random.nextInt(60) + 5;
          result = a - b; // negativo
        } else {
          result = _random.nextInt(400) + 100;
          b = _random.nextInt(500) + 200;
          a = result + b;
        }
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
  Operation _generateMultiplication(int tier) {
    int a, b;

    switch (tier) {
      case 1:
        a = _random.nextInt(5) + 1;
        b = _random.nextInt(5) + 1;
        break;
      case 2:
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        break;
      case 3:
        a = _random.nextInt(11) + 2;
        b = _random.nextInt(11) + 2;
        break;
      case 4:
        a = _random.nextInt(14) + 2;
        b = _random.nextInt(12) + 2;
        break;
      case 5:
        a = _random.nextInt(18) + 3;
        b = _random.nextInt(15) + 2;
        break;
      case 6:
        // Dos cifras × una cifra grande
        a = _random.nextInt(40) + 11;
        b = _random.nextInt(12) + 3;
        break;
      case 7:
      case 8:
        // Multiplicaciones de dos cifras
        a = _random.nextInt(25) + 11;
        b = _random.nextInt(20) + 11;
        break;
      default:
        a = _random.nextInt(40) + 12;
        b = _random.nextInt(30) + 12;
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
  Operation _generateDivision(int tier) {
    int quotient, divisor;

    switch (tier) {
      case 1:
        quotient = _random.nextInt(10) + 1;
        divisor = _random.nextInt(2) + 1;
        break;
      case 2:
        quotient = _random.nextInt(10) + 1;
        divisor = _random.nextInt(5) + 1;
        break;
      case 3:
        quotient = _random.nextInt(11) + 2;
        divisor = _random.nextInt(9) + 2;
        break;
      case 4:
        quotient = _random.nextInt(14) + 2;
        divisor = _random.nextInt(11) + 2;
        break;
      case 5:
        quotient = _random.nextInt(18) + 3;
        divisor = _random.nextInt(14) + 2;
        break;
      case 6:
        // Cociente o divisor de dos cifras
        quotient = _random.nextInt(40) + 12;
        divisor = _random.nextInt(12) + 3;
        break;
      case 7:
      case 8:
        quotient = _random.nextInt(50) + 12;
        divisor = _random.nextInt(25) + 11;
        break;
      default:
        quotient = _random.nextInt(60) + 15;
        divisor = _random.nextInt(30) + 12;
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

  // ========== MIXTAS (encadenadas, paréntesis, negativos) ==========
  Operation _generateMixed(int tier) {
    if (tier >= 7 && _random.nextDouble() < 0.45) {
      return _generateParentheses(tier);
    }
    if (tier >= 8 && _random.nextDouble() < 0.35) {
      return _generateNegativeMixed(tier);
    }
    return _generateChained(tier);
  }

  Operation _generateChained(int tier) {
    final operators = tier <= 2
        ? ['+', '-']
        : (tier >= 6 ? ['+', '-', '×', '÷'] : ['+', '-', '×']);
    final op1 = operators[_random.nextInt(operators.length)];
    final op2 = operators[_random.nextInt(operators.length)];

    int a, b, c;

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
        a = _random.nextInt(25) + 10;
        b = _random.nextInt(15) + 2;
        c = _random.nextInt(15) + 2;
        break;
      case 6:
        a = _random.nextInt(40) + 12;
        b = _random.nextInt(12) + 2;
        c = _random.nextInt(12) + 2;
        break;
      default:
        a = _random.nextInt(50) + 12;
        b = _random.nextInt(15) + 3;
        c = _random.nextInt(12) + 2;
        break;
    }

    // Evitar división no exacta en encadenadas
    if (op1 == '÷' || op2 == '÷') {
      return _generateExactDivisionChain(tier, a, b, c);
    }

    int result;
    String expression;

    if (op1 == '×' || op2 == '×') {
      if (op2 == '×') {
        final product = b * c;
        if (op1 == '+') {
          result = a + product;
          expression = '$a + $b × $c';
        } else {
          result = a - product;
          expression = '$a - $b × $c';
          if (result < 0 && tier < 8) {
            result = a + product;
            expression = '$a + $b × $c';
          }
        }
      } else {
        final product = a * b;
        if (op2 == '+') {
          result = product + c;
          expression = '$a × $b + $c';
        } else {
          result = product - c;
          expression = '$a × $b - $c';
          if (result < 0 && tier < 8) {
            result = product + c;
            expression = '$a × $b + $c';
          }
        }
      }
    } else {
      final temp = op1 == '+' ? a + b : a - b;
      result = op2 == '+' ? temp + c : temp - c;
      expression = '$a $op1 $b $op2 $c';

      if (result < 0 && tier < 8) {
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

  Operation _generateExactDivisionChain(int tier, int aSeed, int bSeed, int cSeed) {
    // Forma: a + b ÷ c  o  a × b ÷ c  (siempre exacta)
    final c = (cSeed % 9) + 2;
    final quotient = (bSeed % 10) + 2;
    final b = quotient * c;
    final a = (aSeed % 30) + 5;

    final useTimes = tier >= 6 && _random.nextBool();
    late int result;
    late String expression;

    if (useTimes) {
      // a × b ÷ c = a × quotient
      result = a * quotient;
      expression = '$a × $b ÷ $c';
    } else {
      result = a + quotient;
      expression = '$a + $b ÷ $c';
    }

    return Operation(
      expression: expression,
      answer: result,
      type: OperationType.mixed,
      tier: tier,
      complexity: tier + 2,
    );
  }

  Operation _generateParentheses(int tier) {
    final a = _random.nextInt(tier >= 8 ? 30 : 20) + 5;
    final b = _random.nextInt(15) + 2;
    final c = _random.nextInt(12) + 2;

    final variants = <Operation>[];

    // (a + b) × c
    variants.add(Operation(
      expression: '($a + $b) × $c',
      answer: (a + b) * c,
      type: OperationType.mixed,
      tier: tier,
      complexity: tier + 3,
    ));

    // (a - b) × c  (positivo)
    if (a > b) {
      variants.add(Operation(
        expression: '($a - $b) × $c',
        answer: (a - b) * c,
        type: OperationType.mixed,
        tier: tier,
        complexity: tier + 3,
      ));
    }

    // a × (b + c)
    variants.add(Operation(
      expression: '$a × ($b + $c)',
      answer: a * (b + c),
      type: OperationType.mixed,
      tier: tier,
      complexity: tier + 3,
    ));

    // (a + b) ÷ c  exacta
    final sum = a + b;
    final div = [2, 3, 4, 5].firstWhere((d) => sum % d == 0, orElse: () => 1);
    if (div > 1) {
      variants.add(Operation(
        expression: '($a + $b) ÷ $div',
        answer: sum ~/ div,
        type: OperationType.mixed,
        tier: tier,
        complexity: tier + 3,
      ));
    }

    return variants[_random.nextInt(variants.length)];
  }

  Operation _generateNegativeMixed(int tier) {
    final a = _random.nextInt(40) + 10;
    final b = _random.nextInt(20) + 5;
    final c = _random.nextInt(12) + 2;

    if (_random.nextBool()) {
      // a - b × c  (a menudo negativo o pequeño)
      final product = b * c;
      final result = a - product;
      return Operation(
        expression: '$a - $b × $c',
        answer: result,
        type: OperationType.mixed,
        tier: tier,
        complexity: tier + 3,
      );
    }

    // -a + b × c
    final product = b * c;
    final result = -a + product;
    return Operation(
      expression: '−$a + $b × $c',
      answer: result,
      type: OperationType.mixed,
      tier: tier,
      complexity: tier + 3,
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

  // ========== POTENCIAS Y RAÍCES EXACTAS (tiers 9–10) ==========
  Operation _generatePowerOrRoot(int tier) {
    if (_random.nextBool()) {
      return _generatePower(tier);
    }
    return _generateExactRoot(tier);
  }

  Operation _generatePower(int tier) {
    // Bases y exponentes que dan enteros manejables
    final options = <List<int>>[
      [2, 3], [2, 4], [2, 5], [2, 6], [2, 7], [2, 8],
      [3, 2], [3, 3], [3, 4],
      [4, 2], [4, 3],
      [5, 2], [5, 3],
      [6, 2], [7, 2], [8, 2], [9, 2], [10, 2], [11, 2], [12, 2],
      [13, 2], [14, 2], [15, 2],
    ];

    if (tier >= 10) {
      options.addAll([
        [2, 9], [2, 10], [3, 5], [4, 4], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
      ]);
    }

    final pair = options[_random.nextInt(options.length)];
    final base = pair[0];
    final exp = pair[1];
    final answer = _intPow(base, exp);

    final superscripts = {2: '²', 3: '³', 4: '⁴', 5: '⁵', 6: '⁶', 7: '⁷', 8: '⁸', 9: '⁹', 10: '¹⁰'};
    final expression = superscripts.containsKey(exp)
        ? '$base${superscripts[exp]}'
        : '$base^$exp';

    return Operation(
      expression: expression,
      answer: answer,
      type: OperationType.power,
      tier: tier,
      complexity: tier + 4,
    );
  }

  Operation _generateExactRoot(int tier) {
    // Raíces cuadradas exactas: [radicando, raíz]
    final squares = <List<int>>[
      [4, 2], [9, 3], [16, 4], [25, 5], [36, 6], [49, 7], [64, 8],
      [81, 9], [100, 10], [121, 11], [144, 12], [169, 13], [196, 14],
      [225, 15], [256, 16], [289, 17], [324, 18], [361, 19], [400, 20],
    ];

    // Raíces cúbicas exactas (nivel 10)
    final cubes = <List<int>>[
      [8, 2], [27, 3], [64, 4], [125, 5], [216, 6],
      [343, 7], [512, 8], [729, 9], [1000, 10],
    ];

    final useCube = tier >= 10 && _random.nextDouble() < 0.4;
    final pick = useCube
        ? cubes[_random.nextInt(cubes.length)]
        : squares[_random.nextInt(squares.length)];
    final radicand = pick[0];
    final root = pick[1];
    final expression = useCube ? '∛$radicand' : '√$radicand';

    return Operation(
      expression: expression,
      answer: root,
      type: OperationType.power,
      tier: tier,
      complexity: tier + 4,
    );
  }

  int _intPow(int base, int exp) {
    var result = 1;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  Map<String, dynamic> getStats() {
    return {
      'usedExpressions': _usedExpressions.length,
      'sessionOperationCount': _sessionOperationCount,
    };
  }
}
