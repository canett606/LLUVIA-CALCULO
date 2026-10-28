import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// En iPhone/Android un Focus con autofocus crea un input oculto y se come los toques.
bool get physicalKeyboardEnabled {
  const touch = {TargetPlatform.iOS, TargetPlatform.android};
  return !touch.contains(defaultTargetPlatform);
}

/// Acción de una tecla física.
/// [side] 1 = teclado numérico (jugador A), 2 = fila de números (jugador B).
class PhysicalKeyAction {
  final String? digit;
  final bool backspace;
  final bool submit;
  final bool pause;
  final bool quit;
  final int side;

  const PhysicalKeyAction({
    this.digit,
    this.backspace = false,
    this.submit = false,
    this.pause = false,
    this.quit = false,
    this.side = 0,
  });

  static final Map<LogicalKeyboardKey, String> _row = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
  };

  static final Map<LogicalKeyboardKey, String> _pad = {
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  static PhysicalKeyAction? fromKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      return const PhysicalKeyAction(quit: true);
    }
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyP) {
      return const PhysicalKeyAction(pause: true);
    }
    if (key == LogicalKeyboardKey.backspace) {
      return const PhysicalKeyAction(backspace: true, side: 2);
    }
    if (key == LogicalKeyboardKey.delete) {
      return const PhysicalKeyAction(backspace: true, side: 1);
    }
    if (key == LogicalKeyboardKey.enter) {
      return const PhysicalKeyAction(submit: true, side: 2);
    }
    if (key == LogicalKeyboardKey.numpadEnter) {
      return const PhysicalKeyAction(submit: true, side: 1);
    }
    if (key == LogicalKeyboardKey.minus) {
      return const PhysicalKeyAction(digit: '-', side: 2);
    }
    if (key == LogicalKeyboardKey.numpadSubtract) {
      return const PhysicalKeyAction(digit: '-', side: 1);
    }
    final row = _row[key];
    if (row != null) return PhysicalKeyAction(digit: row, side: 2);
    final pad = _pad[key];
    if (pad != null) return PhysicalKeyAction(digit: pad, side: 1);
    return null;
  }
}

/// Añade un dígito o alterna el signo menos en el buffer.
String applyKeyDigit(String buffer, String digit) {
  if (digit == '-' || digit == '−') {
    if (buffer.startsWith('-')) return buffer.substring(1);
    return '-$buffer';
  }
  if (buffer.replaceAll('-', '').length >= 8) return buffer;
  return buffer + digit;
}
