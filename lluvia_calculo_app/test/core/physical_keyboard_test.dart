import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/core/physical_keyboard.dart';

KeyDownEvent _key({
  required PhysicalKeyboardKey physical,
  required LogicalKeyboardKey logical,
  String? character,
}) {
  return KeyDownEvent(
    physicalKey: physical,
    logicalKey: logical,
    character: character,
    timeStamp: Duration.zero,
  );
}

void main() {
  test('la fila de arriba escribe y es el jugador B', () {
    final action = PhysicalKeyAction.fromEvent(_key(
      physical: PhysicalKeyboardKey.digit7,
      logical: LogicalKeyboardKey.digit7,
      character: '7',
    ));
    expect(action?.digit, '7');
    expect(action?.side, 2);
  });

  test('el numérico de la derecha escribe con Bloq Num encendido', () {
    final action = PhysicalKeyAction.fromEvent(_key(
      physical: PhysicalKeyboardKey.numpad8,
      logical: LogicalKeyboardKey.numpad8,
      character: '8',
    ));
    expect(action?.digit, '8');
    expect(action?.side, 1);
  });

  test('el numérico escribe aunque Bloq Num esté apagado', () {
    final cases = <(PhysicalKeyboardKey, LogicalKeyboardKey, String)>[
      (PhysicalKeyboardKey.numpad0, LogicalKeyboardKey.insert, '0'),
      (PhysicalKeyboardKey.numpad1, LogicalKeyboardKey.end, '1'),
      (PhysicalKeyboardKey.numpad2, LogicalKeyboardKey.arrowDown, '2'),
      (PhysicalKeyboardKey.numpad4, LogicalKeyboardKey.arrowLeft, '4'),
      (PhysicalKeyboardKey.numpad7, LogicalKeyboardKey.home, '7'),
      (PhysicalKeyboardKey.numpad9, LogicalKeyboardKey.pageUp, '9'),
    ];
    for (final item in cases) {
      final action = PhysicalKeyAction.fromEvent(_key(
        physical: item.$1,
        logical: item.$2,
      ));
      expect(action?.digit, item.$3, reason: item.$2.debugName);
      expect(action?.side, 1);
    }
  });

  test('Intro del numérico confirma y el menos del numérico es el signo', () {
    final enter = PhysicalKeyAction.fromEvent(_key(
      physical: PhysicalKeyboardKey.numpadEnter,
      logical: LogicalKeyboardKey.numpadEnter,
    ));
    expect(enter?.submit, isTrue);
    expect(enter?.side, 1);

    final minus = PhysicalKeyAction.fromEvent(_key(
      physical: PhysicalKeyboardKey.numpadSubtract,
      logical: LogicalKeyboardKey.minus,
    ));
    expect(minus?.digit, '-');
    expect(minus?.side, 1);
  });
}
