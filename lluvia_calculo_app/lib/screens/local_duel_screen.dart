import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/operation_generator.dart';
import '../core/physical_keyboard.dart';
import '../models/game_state.dart';
import '../models/multiplication_practice.dart';
import '../models/operation.dart';
import '../providers/game_provider.dart';
import '../widgets/falling_drop.dart';
import '../widgets/numeric_keypad.dart';

/// 1 vs 1 en la misma pantalla.
/// Tacto: dos teclados. Teclado físico: A en el numérico, B en la fila 1–0.
class LocalDuelScreen extends StatefulWidget {
  final OperationFamily family;
  final MultiplicationPractice practice;
  final VoidCallback onExit;

  const LocalDuelScreen({
    super.key,
    required this.family,
    this.practice = const MultiplicationPractice(),
    required this.onExit,
  });

  @override
  State<LocalDuelScreen> createState() => _LocalDuelScreenState();
}

class _LocalDuelScreenState extends State<LocalDuelScreen> {
  final _generator = OperationGenerator();
  final _random = Random();
  final _focus = FocusNode();

  final List<FallingDrop> _drops = [];
  String _inputA = '';
  String _inputB = '';
  int _scoreA = 0;
  int _scoreB = 0;
  int _seconds = 90;
  bool _paused = false;
  bool _finished = false;
  String? _message;

  Timer? _tick;
  Timer? _spawn;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _generator.multiplicationPractice = widget.practice;
    if (physicalKeyboardEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) => _advance());
    _spawn = Timer.periodic(const Duration(milliseconds: 2400), (_) => _spawnDrop());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _countdown());
    _spawnDrop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spawn?.cancel();
    _clock?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _stop() {
    _tick?.cancel();
    _spawn?.cancel();
    _clock?.cancel();
  }

  void _advance() {
    if (!mounted || _paused || _finished || _drops.isEmpty) return;
    final next = <FallingDrop>[];
    String? landed;
    for (final drop in _drops) {
      final y = drop.y + (drop.speed / 60);
      if (y >= 1) {
        landed = '${drop.operation.expression} = ${drop.operation.answer}';
      } else {
        next.add(drop.copyWith(y: y));
      }
    }
    setState(() {
      _drops
        ..clear()
        ..addAll(next);
      if (landed != null) _message = landed;
    });
  }

  void _countdown() {
    if (!mounted || _paused || _finished) return;
    if (_seconds <= 1) {
      setState(() {
        _seconds = 0;
        _finished = true;
      });
      _stop();
      return;
    }
    setState(() => _seconds--);
  }

  void _spawnDrop() {
    if (!mounted || _paused || _finished || _drops.length >= 6) return;
    final op = _generator.generate(tier: 2, family: widget.family);
    setState(() {
      _drops.add(FallingDrop(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        operation: op,
        x: 0.12 + _random.nextDouble() * 0.76,
        y: -0.08,
        speed: 0.12 + _random.nextDouble() * 0.04,
        spawnedAt: DateTime.now(),
      ));
    });
  }

  void _type(bool playerA, String digit) {
    if (_paused || _finished) return;
    setState(() {
      if (playerA) {
        _inputA = applyKeyDigit(_inputA, digit);
      } else {
        _inputB = applyKeyDigit(_inputB, digit);
      }
    });
    _tryAuto(playerA);
  }

  void _tryAuto(bool playerA) {
    final raw = playerA ? _inputA : _inputB;
    final answer = int.tryParse(raw);
    if (answer == null) return;
    FallingDrop? hit;
    for (final drop in _drops) {
      if (drop.operation.answer == answer && (hit == null || drop.y > hit.y)) {
        hit = drop;
      }
    }
    if (hit == null) return;
    final caught = hit;
    setState(() {
      _drops.removeWhere((d) => d.id == caught.id);
      if (playerA) {
        _scoreA += 10;
        _inputA = '';
      } else {
        _scoreB += 10;
        _inputB = '';
      }
      _message = '${playerA ? 'A' : 'B'} · ${caught.operation.expression} = $answer';
    });
    context.read<GameProvider>().audio.playHit();
  }

  void _backspace(bool playerA) {
    setState(() {
      final value = playerA ? _inputA : _inputB;
      if (value.isEmpty) return;
      final next = value.substring(0, value.length - 1);
      if (playerA) {
        _inputA = next;
      } else {
        _inputB = next;
      }
    });
  }

  void _submit(bool playerA) {
    if (_paused || _finished) return;
    final before = playerA ? _inputA : _inputB;
    _tryAuto(playerA);
    final after = playerA ? _inputA : _inputB;
    if (before.isNotEmpty && before == after) {
      setState(() => _message = 'Sigue escribiendo');
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final action = PhysicalKeyAction.fromKey(event.logicalKey);
    if (action == null) return KeyEventResult.ignored;
    if (action.quit) {
      _exit();
      return KeyEventResult.handled;
    }
    if (action.pause) {
      _togglePause();
      return KeyEventResult.handled;
    }
    if (_finished) return KeyEventResult.handled;
    final playerA = action.side != 2;
    if (action.backspace) {
      _backspace(playerA);
    } else if (action.submit) {
      _submit(playerA);
    } else if (action.digit != null) {
      _type(playerA, action.digit!);
    }
    return KeyEventResult.handled;
  }

  void _togglePause() {
    if (_finished) return;
    setState(() => _paused = !_paused);
  }

  void _exit() {
    _stop();
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0C2431), Color(0xFF07131D)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _finished ? _result() : _board(),
              ),
            ),
          ),
        ),
    );
    if (!physicalKeyboardEnabled) return scaffold;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: scaffold,
    );
  }

  Widget _board() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keypadH = (constraints.maxHeight * 0.38).clamp(150.0, 280.0);
        return Stack(
          children: [
            Column(
              children: [
                _hud(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: GamePlayfield(drops: _drops, message: _message),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    height: keypadH,
                    child: Row(
                      children: [
                        Expanded(child: _pad(true, _inputA, const Color(0xFF1B4F72))),
                        const SizedBox(width: 4),
                        Expanded(child: _pad(false, _inputB, const Color(0xFF7A4E12))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_paused)
              _PauseCover(onResume: _togglePause, onQuit: _exit),
          ],
        );
      },
    );
  }

  Widget _hud() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF0C2431),
      child: Row(
        children: [
          _scoreChip('A num', _scoreA, const Color(0xFF5DADE2)),
          const SizedBox(width: 8),
          Text(
            '${_seconds}s',
            style: TextStyle(
              color: _seconds <= 10 ? Colors.redAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          _scoreChip('B 123', _scoreB, const Color(0xFFF5B041)),
          const Spacer(),
          _iconButton(Icons.pause, _togglePause),
          _iconButton(Icons.close, _exit),
        ],
      ),
    );
  }

  Widget _scoreChip(String name, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$name  $score',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return _TapTarget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _pad(bool playerA, String value, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(90),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CompactNumericKeypad(
        currentValue: value,
        onDigit: (d) => _type(playerA, d),
        onBackspace: () => _backspace(playerA),
        onClear: () => setState(() {
          if (playerA) {
            _inputA = '';
          } else {
            _inputB = '';
          }
        }),
        onSubmit: () => _submit(playerA),
      ),
    );
  }

  Widget _result() {
    final tie = _scoreA == _scoreB;
    final aWins = _scoreA > _scoreB;
    final title = tie ? 'Empate' : (aWins ? 'Gana el jugador A' : 'Gana el jugador B');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 56),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('A $_scoreA   ·   B $_scoreB', style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 24),
            _BigButton(label: 'Volver al menú', onTap: _exit, color: const Color(0xFF62D6FF)),
          ],
        ),
      ),
    );
  }
}

class _PauseCover extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const _PauseCover({required this.onResume, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pausa', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _BigButton(label: 'Continuar', onTap: onResume, color: const Color(0xFF62D6FF)),
            const SizedBox(height: 8),
            _BigButton(label: 'Salir', onTap: onQuit, color: const Color(0xFFE57373)),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _BigButton({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return _TapTarget(
      onTap: onTap,
      child: Container(
        width: 240,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _TapTarget extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TapTarget({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onTap(),
      child: child,
    );
  }
}
