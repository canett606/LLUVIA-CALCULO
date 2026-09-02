import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/operation.dart';
import '../core/operation_generator.dart';
import '../widgets/numeric_keypad.dart';
import '../providers/game_provider.dart';
import '../services/tournament_service.dart';
import '../services/multiplayer_service.dart';

/// Pantalla de partida de torneo (1v1 con Firebase)
class TournamentMatchScreen extends StatefulWidget {
  final String roomCode;
  final String matchId;
  final String tournamentCode;
  final TournamentService tournamentService;

  const TournamentMatchScreen({
    super.key,
    required this.roomCode,
    required this.matchId,
    required this.tournamentCode,
    required this.tournamentService,
  });

  @override
  State<TournamentMatchScreen> createState() => _TournamentMatchScreenState();
}

class _TournamentMatchScreenState extends State<TournamentMatchScreen> {
  late OperationGenerator _generator;
  final List<FallingOperation> _drops = [];
  
  int _score = 0;
  int _correctAnswers = 0;
  int _rivalScore = 0;
  int _timeRemaining = 90;
  String _currentInput = '';
  bool _isPlaying = false;
  bool _isWaiting = true;
  bool _gameEnded = false;
  String? _winnerId;
  
  Timer? _gameTimer;
  Timer? _dropTimer;
  Timer? _pollingTimer;
  
  late MultiplayerService _multiplayer;
  String? _rivalName;
  
  @override
  void initState() {
    super.initState();
    _generator = OperationGenerator();
    _multiplayer = context.read<GameProvider>().multiplayer;
    _setupMatch();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _dropTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _setupMatch() async {
    // Unirse a la sala de Firebase existente para este match
    final room = await _multiplayer.joinRoom(widget.roomCode);
    
    if (room == null) {
      // Si no existe, crearla
      await _multiplayer.createRoom();
    }
    
    // Empezar a escuchar updates
    _startPolling();
    
    // Marcar listo
    await _multiplayer.setReady(true);
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkRoomState();
    });
  }

  void _checkRoomState() {
    final room = _multiplayer.currentRoom;
    if (room == null) return;
    
    // Detectar rival
    final myId = _multiplayer.playerId;
    for (final entry in room.players.entries) {
      if (entry.key != myId) {
        _rivalName = entry.value.name;
        _rivalScore = entry.value.score;
      }
    }
    
    // Verificar si ambos están listos
    if (_isWaiting && room.allReady && room.players.length >= 2) {
      setState(() {
        _isWaiting = false;
        _isPlaying = true;
      });
      _startGame(room.gameSeed != 0 ? room.gameSeed : DateTime.now().millisecondsSinceEpoch);
    }
    
    // Actualizar puntuación del rival
    if (_isPlaying && !_gameEnded) {
      setState(() {});
    }
    
    // Detectar fin de partida del rival
    final allFinished = room.players.values.every((p) => p.isFinished);
    if (allFinished && room.players.length >= 2 && !_gameEnded) {
      _endGame();
    }
  }

  void _startGame(int seed) {
    _generator = OperationGenerator();
    final random = Random(seed);
    
    // Timer de juego
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _endGame();
      }
    });
    
    // Spawner de gotas
    _dropTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted || !_isPlaying || _gameEnded) return;
      _spawnDrop(random);
    });
    
    // Spawn inicial
    _spawnDrop(random);
  }

  void _spawnDrop(Random random) {
    final operation = _generator.generate(
      family: OperationFamily.todas,
      tier: 2 + (_score ~/ 100),
    );
    
    final screenWidth = MediaQuery.of(context).size.width;
    final x = 20.0 + random.nextDouble() * (screenWidth - 100);
    
    setState(() {
      _drops.add(FallingOperation(
        operation: operation,
        x: x,
        y: -60,
        speed: 1.2 + random.nextDouble() * 0.5,
      ));
    });
  }

  void _handleInput(String digit) {
    if (!_isPlaying || _gameEnded) return;
    
    setState(() {
      if (digit == 'C') {
        _currentInput = '';
      } else if (digit == 'DEL') {
        if (_currentInput.isNotEmpty) {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        }
      } else if (digit == 'OK') {
        _checkAnswer();
      } else if (digit == '-') {
        if (_currentInput.isEmpty) {
          _currentInput = '-';
        }
      } else if (_currentInput.length < 6) {
        _currentInput += digit;
      }
    });
  }

  void _checkAnswer() {
    if (_currentInput.isEmpty) return;
    
    final answer = int.tryParse(_currentInput);
    if (answer == null) {
      setState(() => _currentInput = '');
      return;
    }
    
    // Buscar gota con esa respuesta
    final matchIndex = _drops.indexWhere((d) => d.operation.answer == answer);
    
    if (matchIndex != -1) {
      // ¡Acierto!
      final drop = _drops[matchIndex];
      final bonus = (100 - drop.y).clamp(0, 100).toInt();
      
      setState(() {
        _drops.removeAt(matchIndex);
        _score += 10 + bonus ~/ 10;
        _correctAnswers++;
        _currentInput = '';
      });
      
      // Enviar update
      _multiplayer.sendGameUpdate(
        score: _score,
        lives: 5,
        correctAnswers: _correctAnswers,
      );
    } else {
      // Fallo
      setState(() {
        _score = (_score - 5).clamp(0, 999999);
        _currentInput = '';
      });
    }
  }

  void _endGame() {
    if (_gameEnded) return;
    
    _gameEnded = true;
    _isPlaying = false;
    _gameTimer?.cancel();
    _dropTimer?.cancel();
    
    // Enviar resultado
    _multiplayer.sendGameOver(_score);
    
    // Determinar ganador
    _winnerId = _score > _rivalScore ? _multiplayer.playerId : (_score < _rivalScore ? null : null);
    
    // Reportar resultado al torneo si ganamos
    final myId = _multiplayer.playerId;
    if (_winnerId == myId && myId != null) {
      widget.tournamentService.reportMatchResult(
        widget.matchId,
        myId,
        _score,
        _rivalScore,
      );
    }
    
    setState(() {});
    
    // Mostrar resultado
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showResultDialog();
      }
    });
  }

  void _showResultDialog() {
    final isWinner = _score > _rivalScore;
    final isTie = _score == _rivalScore;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A4A),
        title: Row(
          children: [
            Icon(
              isWinner ? Icons.emoji_events : (isTie ? Icons.handshake : Icons.close),
              color: isWinner ? Colors.amber : (isTie ? Colors.blue : Colors.red),
            ),
            const SizedBox(width: 12),
            Text(
              isWinner ? '¡VICTORIA!' : (isTie ? 'EMPATE' : 'DERROTA'),
              style: TextStyle(
                color: isWinner ? Colors.amber : (isTie ? Colors.blue : Colors.red),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('TÚ', style: TextStyle(color: Colors.white54)),
                    Text('$_score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Text('vs', style: TextStyle(color: Colors.white38)),
                Column(
                  children: [
                    Text(_rivalName ?? 'RIVAL', style: const TextStyle(color: Colors.white54)),
                    Text('$_rivalScore', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isWinner ? '¡Avanzas a la siguiente ronda!' : (isTie ? 'Se decidirá por desempate' : 'Has sido eliminado'),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Volver al bracket
            },
            child: const Text('VOLVER AL BRACKET', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isWaiting) {
      return _buildWaitingScreen();
    }
    
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
          child: Column(
            children: [
              // HUD
              _buildHud(),
              
              // Playfield
              Expanded(
                child: _buildPlayfield(),
              ),
              
              // Keypad
              CompactNumericKeypad(
                currentValue: _currentInput,
                onDigit: _handleInput,
                onClear: () => _handleInput('C'),
                onBackspace: () => _handleInput('DEL'),
                onSubmit: () => _handleInput('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparando partida'),
        backgroundColor: const Color(0xFF0C2431),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C2431), Color(0xFF07131D)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                'Esperando al rival...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Código: ${widget.roomCode}',
                style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
      ),
      child: Row(
        children: [
          // Mi puntuación
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TÚ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text('$_score', style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _timeRemaining <= 10 ? Colors.red.withAlpha(100) : Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_timeRemaining s',
              style: TextStyle(
                color: _timeRemaining <= 10 ? Colors.red : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Rival
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_rivalName ?? 'RIVAL', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Text('$_rivalScore', style: const TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayfield() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Actualizar posiciones de gotas
        _updateDrops(constraints.maxHeight);
        
        return Stack(
          children: [
            // Gotas
            ..._drops.map((drop) => Positioned(
              left: drop.x,
              top: drop.y,
              child: _DropWidget(
                text: drop.operation.expression,
                isHighlighted: drop.operation.answer.toString() == _currentInput,
              ),
            )),
            
            // Input actual
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentInput.isEmpty ? '---' : _currentInput,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateDrops(double maxHeight) {
    if (!_isPlaying || _gameEnded) return;
    
    for (int i = _drops.length - 1; i >= 0; i--) {
      _drops[i] = _drops[i].copyWith(y: _drops[i].y + _drops[i].speed);
      
      if (_drops[i].y > maxHeight) {
        _drops.removeAt(i);
        // No penalizar por gotas perdidas en torneo, solo por fallos activos
      }
    }
  }
}

class FallingOperation {
  final Operation operation;
  final double x;
  final double y;
  final double speed;
  
  FallingOperation({
    required this.operation,
    required this.x,
    required this.y,
    required this.speed,
  });
  
  FallingOperation copyWith({double? x, double? y, double? speed}) {
    return FallingOperation(
      operation: operation,
      x: x ?? this.x,
      y: y ?? this.y,
      speed: speed ?? this.speed,
    );
  }
}

class _DropWidget extends StatelessWidget {
  final String text;
  final bool isHighlighted;
  
  const _DropWidget({required this.text, this.isHighlighted = false});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isHighlighted 
            ? [Colors.green, Colors.green.shade700]
            : [const Color(0xFF62D6FF), const Color(0xFF2A8BC2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? Colors.green : const Color(0xFF62D6FF)).withAlpha(100),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
