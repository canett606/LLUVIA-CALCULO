import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/operation.dart';
import '../models/player_profile.dart';
import '../models/game_state.dart';
import '../core/operation_generator.dart';
import '../core/adaptive_engine.dart';
import '../core/scoring_engine.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../services/multiplayer_service.dart';

/// Provider central del estado del juego.
/// Coordina todos los sistemas: generador, adaptativo, scoring, audio, storage.
class GameProvider extends ChangeNotifier {
  final StorageService _storage;
  final AudioService _audio;
  final MultiplayerService _multiplayer;
  final OperationGenerator _generator;
  final AdaptiveEngine _adaptiveEngine;
  final ScoringEngine _scoringEngine;
  final _uuid = const Uuid();
  final Random _random = Random();

  GameState _state = GameState.initial();
  PlayerProfile? _currentProfile;
  AdaptiveParameters _adaptiveParams = AdaptiveParameters.forBeginner();
  
  Timer? _gameTimer;
  Timer? _spawnTimer;
  Timer? _countdownTimer;
  
  bool _isInitialized = false;
  String _inputBuffer = '';

  GameProvider({
    required StorageService storage,
    required AudioService audio,
    required MultiplayerService multiplayer,
    OperationGenerator? generator,
    AdaptiveEngine? adaptiveEngine,
    ScoringEngine? scoringEngine,
  }) : _storage = storage,
       _audio = audio,
       _multiplayer = multiplayer,
       _generator = generator ?? OperationGenerator(),
       _adaptiveEngine = adaptiveEngine ?? AdaptiveEngine(),
       _scoringEngine = scoringEngine ?? ScoringEngine();

  // Getters
  GameState get state => _state;
  PlayerProfile? get currentProfile => _currentProfile;
  AdaptiveParameters get adaptiveParams => _adaptiveParams;
  bool get isInitialized => _isInitialized;
  String get inputBuffer => _inputBuffer;
  bool get hasPlayer => _currentProfile != null;
  MultiplayerService get multiplayer => _multiplayer;
  AudioService get audio => _audio;
  OperationGenerator get generator => _generator;

  /// Inicializa el provider cargando datos guardados
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _storage.init();
    await _audio.init();
    
    // Cargar jugador actual si existe
    final profile = await _storage.getCurrentPlayer();
    if (profile != null) {
      _currentProfile = profile;
      _updateAdaptiveParams();
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Carga o crea un perfil de jugador
  Future<void> loadOrCreatePlayer(String name) async {
    final profile = await _storage.getOrCreateProfile(name);
    _currentProfile = profile;
    await _storage.setCurrentPlayerId(profile.id);
    _updateAdaptiveParams();
    notifyListeners();
  }

  /// Obtiene lista de perfiles existentes
  Future<List<String>> getExistingProfiles() async {
    return _storage.getProfileNames();
  }

  /// Cambia el modo de juego
  void setMode(GameMode mode) {
    _state = GameState.forMode(mode, family: _state.selectedFamily);
    _updateAdaptiveParams();
    notifyListeners();
  }

  /// Cambia la familia de operaciones
  void setFamily(OperationFamily family) {
    _state = _state.copyWith(selectedFamily: family);
    notifyListeners();
  }

  /// Inicia una nueva partida
  void startGame() {
    if (_currentProfile == null) return;
    
    _stopAllTimers();
    
    // Configurar estado inicial según modo
    _state = GameState.forMode(_state.mode, family: _state.selectedFamily);
    _state = _state.copyWith(
      isRunning: true,
      isPaused: false,
      currentTier: _adaptiveParams.suggestedTier,
      lastMessage: '¡Empieza la lluvia!',
    );
    
    // Iniciar timers
    _startGameLoop();
    _startSpawnTimer();
    
    if (_state.mode == GameMode.porTiempo) {
      _startCountdownTimer();
    }
    
    // Spawn inicial
    _spawnDrop();
    
    notifyListeners();
  }

  /// Pausa o reanuda el juego
  void togglePause() {
    if (!_state.isRunning) return;
    
    _state = _state.copyWith(
      isPaused: !_state.isPaused,
      lastMessage: _state.isPaused ? '¡Continúa!' : 'Juego en pausa',
    );
    
    notifyListeners();
  }

  /// Termina la partida manualmente
  void endGame() {
    _handleGameEnd(GameEndResult(
      reason: GameEndReason.userQuit,
      finalScore: _state.score,
      message: 'Partida terminada',
      victory: false,
    ));
  }

  /// Reinicia el juego al estado inicial
  void resetGame() {
    _stopAllTimers();
    _state = GameState.forMode(_state.mode, family: _state.selectedFamily);
    _inputBuffer = '';
    notifyListeners();
  }

  // ========== INPUT HANDLING ==========

  /// Añade un dígito al buffer de entrada
  void appendDigit(String digit) {
    if (!_state.isRunning || _state.isPaused) return;
    
    _inputBuffer += digit;
    _audio.playTap();
    notifyListeners();
  }

  /// Borra el último dígito
  void backspace() {
    if (_inputBuffer.isNotEmpty) {
      _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      notifyListeners();
    }
  }

  /// Limpia todo el buffer
  void clearInput() {
    _inputBuffer = '';
    notifyListeners();
  }

  /// Envía la respuesta actual
  void submitAnswer() {
    if (!_state.isRunning || _state.isPaused) return;
    if (_inputBuffer.isEmpty) return;
    
    final answer = int.tryParse(_inputBuffer);
    if (answer == null) {
      _inputBuffer = '';
      notifyListeners();
      return;
    }
    
    final result = _scoringEngine.evaluateAnswer(
      userAnswer: answer,
      state: _state,
      mode: _state.mode,
    );
    
    if (result.correct && result.hitDrop != null) {
      _handleCorrectAnswer(result);
    } else {
      _handleIncorrectAnswer(result);
    }
    
    _inputBuffer = '';
    notifyListeners();
  }

  // ========== GAME LOOP ==========

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_state.isRunning || _state.isPaused) return;
      _updateDrops();
    });
  }

  void _startSpawnTimer() {
    _spawnTimer = Timer.periodic(
      Duration(milliseconds: _adaptiveParams.spawnIntervalMs.round()),
      (_) {
        if (!_state.isRunning || _state.isPaused) return;
        _spawnDrop();
      },
    );
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isRunning || _state.isPaused) return;
      
      final remaining = _state.timeRemaining;
      if (remaining == null) return;
      
      final newRemaining = remaining - const Duration(seconds: 1);
      _state = _state.copyWith(timeRemaining: newRemaining);
      
      if (newRemaining.inSeconds <= 0) {
        final endResult = _scoringEngine.checkGameEnd(_state);
        if (endResult != null) {
          _handleGameEnd(endResult);
        }
      }
      
      notifyListeners();
    });
  }

  void _stopAllTimers() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    _gameTimer = null;
    _spawnTimer = null;
    _countdownTimer = null;
  }

  void _updateDrops() {
    if (_state.activeDrops.isEmpty) return;
    
    final updatedDrops = <FallingDrop>[];
    final dropsToRemove = <FallingDrop>[];
    
    for (final drop in _state.activeDrops) {
      // Actualizar posición (speed es unidades por segundo, 60fps)
      final newY = drop.y + (drop.speed / 60);
      
      if (newY >= 1.0) {
        // Llegó al suelo
        dropsToRemove.add(drop);
      } else {
        updatedDrops.add(drop.copyWith(y: newY));
      }
    }
    
    // Procesar gotas perdidas
    for (final drop in dropsToRemove) {
      _handleMiss(drop);
    }
    
    _state = _state.copyWith(activeDrops: updatedDrops);
    
    // Verificar fin de juego
    final endResult = _scoringEngine.checkGameEnd(_state);
    if (endResult != null) {
      _handleGameEnd(endResult);
    }
    
    notifyListeners();
  }

  void _spawnDrop() {
    // Limitar número de gotas activas
    if (_state.activeDrops.length >= 8) return;
    
    // Determinar tier basado en modo adaptativo
    int tier = _state.currentTier;
    
    // En modo aprendizaje, variar tier según params adaptativos
    if (_state.mode == GameMode.aprendizaje) {
      if (_adaptiveParams.shouldIncreaseDifficulty && tier < 5) {
        tier = min(5, tier + 1);
        _state = _state.copyWith(currentTier: tier);
      } else if (_adaptiveParams.shouldDecreaseDifficulty && tier > 1) {
        tier = max(1, tier - 1);
        _state = _state.copyWith(currentTier: tier);
      }
    }
    
    // Generar operación
    final operation = _generator.generate(
      tier: tier,
      family: _state.selectedFamily,
    );
    
    // Calcular velocidad base según modo y nivel
    double baseSpeed = 0.15; // unidades por segundo
    switch (_state.mode) {
      case GameMode.aprendizaje:
        baseSpeed = 0.10;
        break;
      case GameMode.porTiempo:
        baseSpeed = 0.18;
        break;
      case GameMode.porPuntuacion:
        baseSpeed = 0.15;
        break;
      case GameMode.supervivencia:
        baseSpeed = 0.20;
        break;
      case GameMode.porNiveles:
        baseSpeed = 0.15;
        break;
    }
    
    // Ajustar por nivel y parámetros adaptativos
    final speedMultiplier = _adaptiveParams.speedMultiplier;
    final levelBonus = (_state.level - 1) * 0.02;
    final speed = baseSpeed * speedMultiplier + levelBonus + _random.nextDouble() * 0.03;
    
    // Posición X aleatoria evitando bordes
    final x = 0.1 + _random.nextDouble() * 0.8;
    
    final drop = FallingDrop(
      id: _uuid.v4(),
      operation: operation,
      x: x,
      y: -0.1, // Empieza arriba fuera de pantalla
      speed: speed,
      spawnedAt: DateTime.now(),
    );
    
    _state = _state.copyWith(
      activeDrops: [..._state.activeDrops, drop],
    );
  }

  // ========== ANSWER HANDLING ==========

  void _handleCorrectAnswer(AnswerResult result) {
    _audio.playHit();
    
    // Actualizar estado de juego
    _state = _state.copyWith(
      score: _state.score + result.pointsGained,
      streak: result.newStreak,
      correctThisSession: _state.correctThisSession + 1,
      activeDrops: _state.activeDrops
          .where((d) => d.id != result.hitDrop!.id)
          .toList(),
      lastMessage: result.message,
    );
    
    // Actualizar nivel si corresponde
    _updateLevel();
    
    // Actualizar perfil
    if (_currentProfile != null && result.hitDrop != null) {
      _currentProfile = _adaptiveEngine.updateProfileAfterAnswer(
        profile: _currentProfile!,
        operation: result.hitDrop!.operation,
        correct: true,
        responseTimeMs: result.hitDrop!.responseTimeMs,
      );
      _updateAdaptiveParams();
      _saveProfile();
    }
    
    // Notificar multijugador
    _multiplayer.sendGameUpdate(
      score: _state.score,
      lives: _state.lives,
      correctAnswers: _state.correctThisSession,
    );
  }

  void _handleIncorrectAnswer(AnswerResult result) {
    _audio.playMiss();
    
    _state = _state.copyWith(
      streak: 0,
      incorrectThisSession: _state.incorrectThisSession + 1,
      lastMessage: result.message,
    );
    
    // Actualizar perfil (registrar fallo)
    if (_currentProfile != null && _state.activeDrops.isNotEmpty) {
      _currentProfile = _adaptiveEngine.updateProfileAfterAnswer(
        profile: _currentProfile!,
        operation: _state.activeDrops.first.operation,
        correct: false,
        responseTimeMs: 0,
      );
      _updateAdaptiveParams();
      _saveProfile();
    }
  }

  void _handleMiss(FallingDrop drop) {
    _audio.playMiss();
    
    final missResult = _scoringEngine.calculateMiss(
      drop: drop,
      state: _state,
    );
    
    _state = _state.copyWith(
      lives: _state.lives - missResult.livesLost,
      streak: missResult.streakReset ? 0 : _state.streak,
      incorrectThisSession: _state.incorrectThisSession + 1,
      lastMessage: missResult.message,
    );
    
    // Actualizar perfil
    if (_currentProfile != null) {
      _currentProfile = _adaptiveEngine.updateProfileAfterAnswer(
        profile: _currentProfile!,
        operation: drop.operation,
        correct: false,
        responseTimeMs: drop.responseTimeMs,
      );
      _updateAdaptiveParams();
      _saveProfile();
    }
  }

  void _handleGameEnd(GameEndResult result) {
    _stopAllTimers();
    
    if (result.victory) {
      _audio.playVictory();
    } else {
      _audio.playGameOver();
    }
    
    // Calcular bonus final
    final endBonus = _scoringEngine.calculateEndGameBonus(_state);
    final finalScore = _state.score + endBonus;
    
    _state = _state.copyWith(
      isRunning: false,
      isPaused: false,
      isGameOver: true,
      score: finalScore,
      lastMessage: result.message + (endBonus > 0 ? ' (+$endBonus bonus)' : ''),
    );
    
    // Actualizar perfil final
    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(
        bestScore: max(_currentProfile!.bestScore, finalScore),
        totalSessions: _currentProfile!.totalSessions + 1,
        lastMode: _state.mode.name,
        lastFamily: _state.selectedFamily.name,
        lastPlayedAt: DateTime.now(),
      );
      _saveProfile();
      
      // Guardar en ranking local
      _storage.addToRanking(RankingEntry(
        playerId: _currentProfile!.id,
        playerName: _currentProfile!.name,
        score: finalScore,
        mode: _state.mode.name,
        playedAt: DateTime.now(),
        accuracy: _state.sessionAccuracy,
        level: _state.level,
      ));
    }
    
    // Notificar multijugador
    _multiplayer.sendGameOver(finalScore);
    
    notifyListeners();
  }

  void _updateLevel() {
    int newLevel;
    
    switch (_state.mode) {
      case GameMode.aprendizaje:
        newLevel = 1 + (_state.score ~/ 100);
        break;
      case GameMode.porTiempo:
        newLevel = 1 + (_state.score ~/ 80);
        break;
      case GameMode.porPuntuacion:
        newLevel = 1 + (_state.correctThisSession ~/ 10);
        break;
      case GameMode.supervivencia:
        newLevel = 1 + (_state.score ~/ 60);
        break;
      case GameMode.porNiveles:
        newLevel = 1 + (_state.score ~/ 120);
        // Desbloquear tier en modo niveles
        if (newLevel > _state.level && newLevel <= 5) {
          _state = _state.copyWith(currentTier: min(5, newLevel));
          _state = _state.copyWith(
            lastMessage: '🎉 ¡Desbloqueado nivel $newLevel!'
          );
        }
        break;
    }
    
    if (newLevel != _state.level) {
      _state = _state.copyWith(level: newLevel);
      _restartSpawnTimer(); // Ajustar velocidad de spawn
    }
  }

  void _restartSpawnTimer() {
    _spawnTimer?.cancel();
    _updateAdaptiveParams();
    _startSpawnTimer();
  }

  void _updateAdaptiveParams() {
    if (_currentProfile != null) {
      _adaptiveParams = _adaptiveEngine.calculate(
        profile: _currentProfile!,
        currentSession: _state,
        mode: _state.mode,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_currentProfile != null) {
      await _storage.saveProfile(_currentProfile!);
    }
  }

  // ========== RANKING ==========

  Future<List<RankingEntry>> getLocalRanking() async {
    return _storage.getLocalRanking();
  }

  Future<int> getCurrentRankPosition() async {
    return _storage.getRankPosition(_state.score);
  }

  // ========== SOUND ==========

  void toggleSound() {
    _audio.soundEnabled = !_audio.soundEnabled;
    notifyListeners();
  }

  bool get soundEnabled => _audio.soundEnabled;

  @override
  void dispose() {
    _stopAllTimers();
    super.dispose();
  }
}
