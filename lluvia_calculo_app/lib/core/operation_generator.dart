import 'dart:math';
import '../models/operation.dart';

/// Generador procedural de operaciones matemáticas.
/// Cubre desde principiantes (1+1) hasta operaciones complejas multi-paso.
class OperationGenerator {
  final Random _random;

  OperationGenerator([Random? random]) : _random = random ?? Random();

  /// Genera una operación aleatoria según tier y familia
  Operation generate({
    required int tier,
    OperationFamily family = OperationFamily.todas,
  }) {
    // Clamp tier a rango válido
    final effectiveTier = tier.clamp(1, 5);
    
    // Seleccionar tipo de operación basado en familia
    final availableTypes = _getTypesForFamily(family, effectiveTier);
    final selectedType = availableTypes[_random.nextInt(availableTypes.length)];
    
    return _generateForType(selectedType, effectiveTier);
  }

  /// Genera un lote de operaciones variadas
  List<Operation> generateBatch({
    required int tier,
    required int count,
    OperationFamily family = OperationFamily.todas,
    bool avoidDuplicateAnswers = true,
  }) {
    final operations = <Operation>[];
    final usedAnswers = <int>{};
    
    int attempts = 0;
    while (operations.length < count && attempts < count * 10) {
      final op = generate(tier: tier, family: family);
      if (!avoidDuplicateAnswers || !usedAnswers.contains(op.answer)) {
        operations.add(op);
        usedAnswers.add(op.answer);
      }
      attempts++;
    }
    
    return operations;
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
        // Tier 1: solo suma y resta
        // Tier 2: añade multiplicación
        // Tier 3+: añade división y mixtas
        if (tier == 1) {
          return [OperationType.addition, OperationType.subtraction];
        } else if (tier == 2) {
          return [OperationType.addition, OperationType.subtraction, OperationType.multiplication];
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

  /// SUMAS: desde 1+1 hasta sumas de 3 dígitos
  Operation _generateAddition(int tier) {
    int a, b;
    
    switch (tier) {
      case 1: // Principiante: 1-9 + 1-9, resultado <= 20
        a = _random.nextInt(9) + 1;
        b = _random.nextInt(min(9, 20 - a)) + 1;
        break;
      case 2: // Básico: 1-20 + 1-20
        a = _random.nextInt(20) + 1;
        b = _random.nextInt(20) + 1;
        break;
      case 3: // Intermedio: números hasta 100
        a = _random.nextInt(80) + 10;
        b = _random.nextInt(80) + 10;
        break;
      case 4: // Avanzado: números hasta 200
        a = _random.nextInt(150) + 20;
        b = _random.nextInt(150) + 20;
        break;
      case 5: // Experto: números hasta 500
      default:
        a = _random.nextInt(400) + 50;
        b = _random.nextInt(400) + 50;
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

  /// RESTAS: siempre resultado positivo
  Operation _generateSubtraction(int tier) {
    int a, b;
    
    switch (tier) {
      case 1: // Principiante: resultado 1-10
        a = _random.nextInt(10) + 2;
        b = _random.nextInt(a - 1) + 1;
        break;
      case 2: // Básico: resultado hasta 20
        a = _random.nextInt(30) + 10;
        b = _random.nextInt(min(a - 1, 20)) + 1;
        break;
      case 3: // Intermedio
        a = _random.nextInt(100) + 50;
        b = _random.nextInt(min(a - 1, 80)) + 1;
        break;
      case 4: // Avanzado
        a = _random.nextInt(300) + 100;
        b = _random.nextInt(min(a - 1, 200)) + 1;
        break;
      case 5: // Experto
      default:
        a = _random.nextInt(500) + 200;
        b = _random.nextInt(min(a - 1, 400)) + 1;
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

  /// MULTIPLICACIONES: tablas básicas hasta productos mayores
  Operation _generateMultiplication(int tier) {
    int a, b;
    
    switch (tier) {
      case 1: // Tablas del 1-5
        a = _random.nextInt(5) + 1;
        b = _random.nextInt(5) + 1;
        break;
      case 2: // Tablas del 1-10
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        break;
      case 3: // Tablas extendidas 1-12
        a = _random.nextInt(12) + 1;
        b = _random.nextInt(12) + 1;
        break;
      case 4: // Un factor hasta 15, otro hasta 12
        a = _random.nextInt(15) + 1;
        b = _random.nextInt(12) + 1;
        break;
      case 5: // Factores mayores
      default:
        a = _random.nextInt(20) + 5;
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

  /// DIVISIONES: siempre resultado entero exacto
  Operation _generateDivision(int tier) {
    int quotient, divisor, dividend;
    
    switch (tier) {
      case 1: // División por 1-2, cociente 1-10
        quotient = _random.nextInt(10) + 1;
        divisor = _random.nextInt(2) + 1;
        break;
      case 2: // División por 1-5, cociente 1-10
        quotient = _random.nextInt(10) + 1;
        divisor = _random.nextInt(5) + 1;
        break;
      case 3: // División por 1-10, cociente 1-12
        quotient = _random.nextInt(12) + 1;
        divisor = _random.nextInt(10) + 1;
        break;
      case 4: // Divisiones más grandes
        quotient = _random.nextInt(15) + 2;
        divisor = _random.nextInt(12) + 2;
        break;
      case 5: // Divisiones complejas
      default:
        quotient = _random.nextInt(20) + 5;
        divisor = _random.nextInt(15) + 2;
        break;
    }

    dividend = quotient * divisor;

    return Operation(
      expression: '$dividend ÷ $divisor',
      answer: quotient,
      type: OperationType.division,
      tier: tier,
      complexity: tier + 1,
    );
  }

  /// MIXTAS: operaciones con dos pasos
  Operation _generateMixed(int tier) {
    // Para tier bajo, usamos solo +/- simples
    // Para tier alto, combinamos +,-,×,÷
    
    final operators = tier <= 2 
      ? ['+', '-'] 
      : ['+', '-', '×'];
    
    final op1 = operators[_random.nextInt(operators.length)];
    final op2 = operators[_random.nextInt(operators.length)];
    
    int a, b, c;
    int result;
    String expression;
    
    switch (tier) {
      case 1:
      case 2:
        // Simples: a op b op c con números pequeños
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        c = _random.nextInt(10) + 1;
        break;
      case 3:
        a = _random.nextInt(20) + 5;
        b = _random.nextInt(15) + 1;
        c = _random.nextInt(15) + 1;
        break;
      case 4:
      case 5:
      default:
        a = _random.nextInt(30) + 10;
        b = _random.nextInt(20) + 2;
        c = _random.nextInt(20) + 2;
        break;
    }

    // Generar expresión respetando precedencia
    if (op1 == '×' || op2 == '×') {
      // Si hay multiplicación, calcular con precedencia
      if (op2 == '×') {
        // a op1 (b × c)
        final product = b * c;
        result = op1 == '+' ? a + product : a - product;
        expression = '$a $op1 $b × $c';
        
        // Asegurar resultado positivo
        if (result < 0) {
          result = a + product;
          expression = '$a + $b × $c';
        }
      } else {
        // (a × b) op2 c
        final product = a * b;
        result = op2 == '+' ? product + c : product - c;
        expression = '$a × $b $op2 $c';
        
        if (result < 0) {
          result = product + c;
          expression = '$a × $b + $c';
        }
      }
    } else {
      // Solo + y -, evaluación izquierda a derecha
      int temp = op1 == '+' ? a + b : a - b;
      result = op2 == '+' ? temp + c : temp - c;
      expression = '$a $op1 $b $op2 $c';
      
      // Asegurar resultado positivo
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
}
