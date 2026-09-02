import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../core/operation_generator.dart';
import '../models/operation.dart';
import '../models/game_state.dart';
import '../widgets/falling_drop.dart';
import '../widgets/numeric_keypad.dart';

/// Pantalla de juego 1v1 con HUD del rival
class MultiplayerGameScreen extends StatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  late OperationGenerator _generator;
  late Timer _gameTimer;
  late Timer _updateTimer;
  
  String _inputBuffer = '';
  int _score = 0;
  int _lives = 5;
  int _streak = 0;
  int _correctCount = 0;
  Duration _timeRemaining = const Duration(seconds: 90);
  List<FallingDrop> _drops = [];
  String _message = '';
  bool _isFinished = false;
  
  StreamSubscription? _roomSubscription;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final mp = context.read<GameProvider>().multiplayer;
    final room = mp.currentRoom;
    
    // Usar la misma seed para ambos jugadores
    final seed = room?.gameSeed ?? Random().nextInt(1000000);
    _generator = OperationGenerator(Random(seed));
    _generator.resetSession();
    
    // Escuchar cambios en la sala
    _roomSubscription = mp.roomStream.listen((room) {
      if (mounted) setState(() {});
    });
    
    _eventSubscription = mp.eventStream.listen((event) {
      if (event.type == 'match_finished' && mounted) {
        _showResults();
      }
    });
    
    // Iniciar juego
    _startGame();
  }

  void _startGame() {
    // Spawn inicial
    _spawnDrop();
    
    // Timer principal (16ms = ~60fps)
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_isFinished) {
        _updateDrops();
      }
    });
    
    // Timer de countdown
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isFinished || !mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _timeRemaining -= const Duration(seconds: 1);
        if (_timeRemaining.inSeconds <= 0) {
          _endGame();
        }
      });
    });
    
    // Timer de spawn
    Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_isFinished || !mounted) {
        timer.cancel();
        return;
      }
      _spawnDrop();
    });
    
    // Timer de envío de updates
    _updateTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _sendUpdate();
    });
  }

  void _spawnDrop() {
    if (_drops.length >= 6) return;
    
    final op = _generator.generate(tier: 2, family: OperationFamily.todas);
    final x = 0.1 + Random().nextDouble() * 0.8;
    
    final drop = FallingDrop(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
      operation: op,
      x: x,
      y: -0.1,
      speed: 0.15 + Random().nextDouble() * 0.05,
      spawnedAt: DateTime.now(),
    );
    
    setState(() {
      _drops = [..._drops, drop];
    });
  }

  void _updateDrops() {
    if (_drops.isEmpty) return;
    
    final updated = <FallingDrop>[];
    
    for (final drop in _drops) {
      final newY = drop.y + (drop.speed / 60);
      
      if (newY >= 1.0) {
        // Llegó al suelo - perdemos vida
        _handleMiss();
      } else {
        updated.add(drop.copyWith(y: newY));
      }
    }
    
    if (mounted) {
      setState(() {
        _drops = updated;
      });
    }
  }

  void _handleMiss() {
    setState(() {
      _lives = max(0, _lives - 1);
      _streak = 0;
      _message = '¡Perdiste una vida!';
    });
    
    if (_lives <= 0) {
      _endGame();
    }
  }

  void _appendDigit(String digit) {
    if (_isFinished) return;
    setState(() {
      _inputBuffer += digit;
    });
  }

  void _backspace() {
    if (_inputBuffer.isNotEmpty) {
      setState(() {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      });
    }
  }

  void _clear() {
    setState(() {
      _inputBuffer = '';
    });
  }

  void _submit() {
    if (_inputBuffer.isEmpty || _isFinished) return;
    
    final answer = int.tryParse(_inputBuffer);
    if (answer == null) {
      _clear();
      return;
    }
    
    // Buscar drop con esa respuesta
    FallingDrop? hitDrop;
    for (final drop in _drops) {
      if (drop.operation.answer == answer) {
        hitDrop = drop;
        break;
      }
    }
    
    if (hitDrop != null) {
      // Acierto
      final points = 10 + (_streak * 2);
      setState(() {
        _score += points;
        _streak++;
        _correctCount++;
        _drops = _drops.where((d) => d.id != hitDrop!.id).toList();
        _message = _streak >= 5 ? '🔥 ¡Racha x$_streak!' : '¡+$points!';
      });
      context.read<GameProvider>().audio.playHit();
    } else {
      // Fallo
      setState(() {
        _streak = 0;
        _message = 'Incorrecto';
      });
      context.read<GameProvider>().audio.playMiss();
    }
    
    _clear();
  }

  void _sendUpdate() {
    final mp = context.read<GameProvider>().multiplayer;
    mp.sendGameUpdate(
      score: _score,
      lives: _lives,
      correctAnswers: _correctCount,
      isFinished: _isFinished,
    );
  }

  void _endGame() {
    if (_isFinished) return;
    
    setState(() {
      _isFinished = true;
    });
    
    _gameTimer.cancel();
    _updateTimer.cancel();
    
    final mp = context.read<GameProvider>().multiplayer;
    mp.sendGameOver(_score);
    
    // Esperar un momento y mostrar resultados
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showResults();
    });
  }

  void _showResults() {
    final mp = context.read<GameProvider>().multiplayer;
    final opponent = mp.opponent;
    
    final myScore = _score;
    final opponentScore = opponent?.score ?? 0;
    final isWinner = myScore > opponentScore;
    final isTie = myScore == opponentScore;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: Text(
          isTie ? '¡Empate!' : isWinner ? '¡Victoria!' : 'Derrota',
          style: TextStyle(
            color: isTie ? Colors.amber : isWinner ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTie ? Icons.handshake : isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 64,
              color: isTie ? Colors.amber : isWinner ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 16),
            _ResultRow('Tu puntuación', '$myScore', highlight: isWinner),
            _ResultRow('Rival', '$opponentScore', highlight: !isWinner && !isTie),
            const Divider(color: Colors.white24),
            _ResultRow('Aciertos', '$_correctCount'),
            _ResultRow('Racha máx.', '$_streak'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/game');
              mp.leaveRoom();
            },
            child: const Text('Volver al menú'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gameTimer.cancel();
    _updateTimer.cancel();
    _roomSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<GameProvider>().multiplayer;
    final opponent = mp.opponent;
    
    return Scaffold(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalHeight = constraints.maxHeight;
              const hudHeight = 60.0;
              final keypadHeight = (totalHeight * 0.38).clamp(160.0, 280.0);
              
              return Column(
                children: [
                  // HUD con scores de ambos
                  SizedBox(
                    height: hudHeight,
                    child: _MultiplayerHud(
                      myScore: _score,
                      myLives: _lives,
                      opponentScore: opponent?.score ?? 0,
                      opponentName: opponent?.name ?? 'Rival',
                      timeRemaining: _timeRemaining,
                    ),
                  ),
                  // Área de juego
                  Expanded(
                    child: Stack(
                      children: [
                        GamePlayfield(drops: _drops, message: _message),
                        if (_isFinished)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.amber),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Keypad
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      height: keypadHeight,
                      child: CompactNumericKeypad(
                        currentValue: _inputBuffer,
                        onDigit: _appendDigit,
                        onBackspace: _backspace,
                        onClear: _clear,
                        onSubmit: _submit,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MultiplayerHud extends StatelessWidget {
  final int myScore;
  final int myLives;
  final int opponentScore;
  final String opponentName;
  final Duration timeRemaining;

  const _MultiplayerHud({
    required this.myScore,
    required this.myLives,
    required this.opponentScore,
    required this.opponentName,
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final isWinning = myScore > opponentScore;
    final isTied = myScore == opponentScore;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2431),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Mi score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('TÚ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text(
                  '$myScore',
                  style: TextStyle(
                    color: isWinning ? Colors.green : isTied ? Colors.amber : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Vidas y tiempo
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.favorite,
                  size: 14,
                  color: i < myLives ? Colors.pink : Colors.grey[800],
                )),
              ),
              const SizedBox(height: 4),
              Text(
                '${timeRemaining.inSeconds}s',
                style: TextStyle(
                  color: timeRemaining.inSeconds <= 10 ? Colors.red : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          // Rival score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(opponentName.toUpperCase(),
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Text(
                  '$opponentScore',
                  style: TextStyle(
                    color: !isWinning && !isTied ? Colors.red : Colors.white70,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ResultRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(
            color: highlight ? Colors.amber : Colors.white,
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }
}
