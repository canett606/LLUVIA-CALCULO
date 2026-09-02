import 'package:equatable/equatable.dart';
import 'operation.dart';

/// Modos de juego disponibles
enum GameMode {
  aprendizaje, // Adaptativo, empieza fácil y sube gradualmente
  porTiempo,   // Carrera contra el reloj
  porPuntuacion, // Alcanzar puntuación objetivo
  supervivencia, // Vidas limitadas, dificultad creciente
  porNiveles,  // Desbloquear niveles por maestría
}

/// Estado de una gota cayendo
class FallingDrop extends Equatable {
  final String id;
  final Operation operation;
  final double x; // posición X (0.0 - 1.0)
  final double y; // posición Y (0.0 - 1.0, 1.0 = suelo)
  final double speed; // velocidad en unidades/segundo
  final DateTime spawnedAt;

  const FallingDrop({
    required this.id,
    required this.operation,
    required this.x,
    required this.y,
    required this.speed,
    required this.spawnedAt,
  });

  FallingDrop copyWith({
    String? id,
    Operation? operation,
    double? x,
    double? y,
    double? speed,
    DateTime? spawnedAt,
  }) {
    return FallingDrop(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      x: x ?? this.x,
      y: y ?? this.y,
      speed: speed ?? this.speed,
      spawnedAt: spawnedAt ?? this.spawnedAt,
    );
  }

  int get responseTimeMs => DateTime.now().difference(spawnedAt).inMilliseconds;

  @override
  List<Object?> get props => [id, operation, x, y, speed, spawnedAt];
}

/// Estado completo del juego
class GameState extends Equatable {
  final GameMode mode;
  final OperationFamily selectedFamily;
  final bool isRunning;
  final bool isPaused;
  final int score;
  final int lives;
  final int maxLives;
  final int streak;
  final int level;
  final int currentTier;
  final List<FallingDrop> activeDrops;
  final Duration? timeRemaining; // para modo porTiempo
  final int? targetScore; // para modo porPuntuacion
  final int correctThisSession;
  final int incorrectThisSession;
  final String? lastMessage;
  final bool isGameOver;

  const GameState({
    this.mode = GameMode.aprendizaje,
    this.selectedFamily = OperationFamily.todas,
    this.isRunning = false,
    this.isPaused = false,
    this.score = 0,
    this.lives = 5,
    this.maxLives = 5,
    this.streak = 0,
    this.level = 1,
    this.currentTier = 1,
    this.activeDrops = const [],
    this.timeRemaining,
    this.targetScore,
    this.correctThisSession = 0,
    this.incorrectThisSession = 0,
    this.lastMessage,
    this.isGameOver = false,
  });

  double get sessionAccuracy => (correctThisSession + incorrectThisSession) > 0
    ? correctThisSession / (correctThisSession + incorrectThisSession)
    : 0.0;

  GameState copyWith({
    GameMode? mode,
    OperationFamily? selectedFamily,
    bool? isRunning,
    bool? isPaused,
    int? score,
    int? lives,
    int? maxLives,
    int? streak,
    int? level,
    int? currentTier,
    List<FallingDrop>? activeDrops,
    Duration? timeRemaining,
    int? targetScore,
    int? correctThisSession,
    int? incorrectThisSession,
    String? lastMessage,
    bool? isGameOver,
  }) {
    return GameState(
      mode: mode ?? this.mode,
      selectedFamily: selectedFamily ?? this.selectedFamily,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      maxLives: maxLives ?? this.maxLives,
      streak: streak ?? this.streak,
      level: level ?? this.level,
      currentTier: currentTier ?? this.currentTier,
      activeDrops: activeDrops ?? this.activeDrops,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      targetScore: targetScore ?? this.targetScore,
      correctThisSession: correctThisSession ?? this.correctThisSession,
      incorrectThisSession: incorrectThisSession ?? this.incorrectThisSession,
      lastMessage: lastMessage ?? this.lastMessage,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }

  factory GameState.initial() => const GameState();

  factory GameState.forMode(GameMode mode, {OperationFamily family = OperationFamily.todas}) {
    switch (mode) {
      case GameMode.aprendizaje:
        return GameState(
          mode: mode,
          selectedFamily: family,
          lives: 7,
          maxLives: 7,
          currentTier: 1,
        );
      case GameMode.porTiempo:
        return GameState(
          mode: mode,
          selectedFamily: family,
          lives: 999, // sin límite
          maxLives: 999,
          timeRemaining: const Duration(seconds: 90),
          currentTier: 2,
        );
      case GameMode.porPuntuacion:
        return GameState(
          mode: mode,
          selectedFamily: family,
          lives: 999,
          maxLives: 999,
          targetScore: 500,
          currentTier: 2,
        );
      case GameMode.supervivencia:
        return GameState(
          mode: mode,
          selectedFamily: family,
          lives: 5,
          maxLives: 5,
          currentTier: 2,
        );
      case GameMode.porNiveles:
        return GameState(
          mode: mode,
          selectedFamily: family,
          lives: 6,
          maxLives: 6,
          currentTier: 1,
        );
    }
  }

  @override
  List<Object?> get props => [mode, selectedFamily, isRunning, isPaused, score, 
    lives, maxLives, streak, level, currentTier, activeDrops, timeRemaining,
    targetScore, correctThisSession, incorrectThisSession, lastMessage, isGameOver];
}
