/// Cómo se preguntan las multiplicaciones, aparte del nivel.
///
/// [onlyTables1to10]: los dos factores se quedan entre 1 y 10.
/// [onlySelectedTables]: si hay tablas marcadas, solo salen esas.
/// [focusTables]: tablas en las que hay que insistir (por ejemplo 7, 8 y 9).
class MultiplicationPractice {
  final bool onlyTables1to10;
  final bool onlySelectedTables;
  final Set<int> focusTables;

  const MultiplicationPractice({
    this.onlyTables1to10 = false,
    this.onlySelectedTables = false,
    this.focusTables = const {},
  });

  bool get hasExclusiveFocus => onlySelectedTables && sortedFocus.isNotEmpty;

  bool get restrictsLevel =>
      onlyTables1to10 || focusTables.isNotEmpty || hasExclusiveFocus;

  MultiplicationPractice copyWith({
    bool? onlyTables1to10,
    bool? onlySelectedTables,
    Set<int>? focusTables,
  }) {
    return MultiplicationPractice(
      onlyTables1to10: onlyTables1to10 ?? this.onlyTables1to10,
      onlySelectedTables: onlySelectedTables ?? this.onlySelectedTables,
      focusTables: focusTables ?? this.focusTables,
    );
  }

  List<int> get sortedFocus {
    final list = focusTables.where((n) => n >= 1 && n <= 10).toList()..sort();
    return list;
  }

  String get summary {
    final focus = sortedFocus;
    if (onlySelectedTables && focus.isEmpty) {
      return 'Marca las tablas: saldrán solo esas';
    }
    if (!restrictsLevel) {
      return 'Las multiplicaciones siguen el nivel';
    }
    final parts = <String>[];
    if (onlyTables1to10 && !hasExclusiveFocus) {
      parts.add('solo tablas del 1 al 10');
    }
    if (focus.isNotEmpty) {
      final list = focus.join(', ');
      if (hasExclusiveFocus) {
        parts.add('solo las tablas del $list');
      } else {
        parts.add('más de las tablas del $list');
        if (!onlyTables1to10) {
          parts.add('el resto sigue el nivel');
        }
      }
    }
    return parts.join(' · ');
  }

  static const String onlyKey = 'multOnly1to10';
  static const String onlySelectedKey = 'multOnlySelected';
  static const String focusKey = 'multFocusTables';

  factory MultiplicationPractice.fromSettings(Map<String, dynamic> settings) {
    final raw = settings[focusKey];
    final focus = <int>{};
    if (raw is List) {
      for (final item in raw) {
        final n = item is int ? item : int.tryParse('$item');
        if (n != null && n >= 1 && n <= 10) focus.add(n);
      }
    }
    return MultiplicationPractice(
      onlyTables1to10: settings[onlyKey] == true,
      onlySelectedTables: settings[onlySelectedKey] == true,
      focusTables: focus,
    );
  }
}
