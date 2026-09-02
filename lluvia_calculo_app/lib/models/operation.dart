import 'package:equatable/equatable.dart';

/// Tipos de operación matemática
enum OperationType {
  addition,
  subtraction,
  multiplication,
  division,
  mixed,
}

/// Familias de operaciones (para UI en español)
enum OperationFamily {
  sumas,
  restas,
  multiplicaciones,
  divisiones,
  mixtas,
  todas,
}

/// Representa una operación matemática generada
class Operation extends Equatable {
  final String expression;
  final int answer;
  final OperationType type;
  final int tier; // 1-5, indica dificultad
  final int complexity; // puntos de complejidad para scoring

  const Operation({
    required this.expression,
    required this.answer,
    required this.type,
    required this.tier,
    this.complexity = 1,
  });

  OperationFamily get family {
    switch (type) {
      case OperationType.addition:
        return OperationFamily.sumas;
      case OperationType.subtraction:
        return OperationFamily.restas;
      case OperationType.multiplication:
        return OperationFamily.multiplicaciones;
      case OperationType.division:
        return OperationFamily.divisiones;
      case OperationType.mixed:
        return OperationFamily.mixtas;
    }
  }

  @override
  List<Object?> get props => [expression, answer, type, tier];

  @override
  String toString() => 'Operation($expression = $answer, tier: $tier)';
}
