import 'dart:async';
import 'dart:math';

/// Estado de conexión multijugador
enum MultiplayerConnectionState {
  disconnected,
  connecting,
  connected,
  inRoom,
  playing,
  error,
}

/// Rol en la sala
enum RoomRole {
  host,
  guest,
}

/// Estado de un jugador en la sala
class RoomPlayer {
  final String id;
  final String name;
  final bool isReady;
  final int score;
  final int lives;
  final int correctAnswers;
  final bool isFinished;

  const RoomPlayer({
    required this.id,
    required this.name,
    this.isReady = false,
    this.score = 0,
    this.lives = 5,
    this.correctAnswers = 0,
    this.isFinished = false,
  });

  RoomPlayer copyWith({
    String? id,
    String? name,
    bool? isReady,
    int? score,
    int? lives,
    int? correctAnswers,
    bool? isFinished,
  }) {
    return RoomPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isReady: isReady ?? this.isReady,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isReady': isReady,
    'score': score,
    'lives': lives,
    'correctAnswers': correctAnswers,
    'isFinished': isFinished,
  };

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    isReady: json['isReady'] ?? false,
    score: json['score'] ?? 0,
    lives: json['lives'] ?? 5,
    correctAnswers: json['correctAnswers'] ?? 0,
    isFinished: json['isFinished'] ?? false,
  );
}

/// Información de una sala de juego
class GameRoom {
  final String code;
  final String hostId;
  final List<RoomPlayer> players;
  final String mode;
  final String family;
  final int maxPlayers;
  final bool isStarted;
  final DateTime? startedAt;
  final int? gameDurationSeconds;

  const GameRoom({
    required this.code,
    required this.hostId,
    this.players = const [],
    this.mode = 'supervivencia',
    this.family = 'todas',
    this.maxPlayers = 4,
    this.isStarted = false,
    this.startedAt,
    this.gameDurationSeconds,
  });

  bool get isFull => players.length >= maxPlayers;
  bool get allReady => players.every((p) => p.isReady);

  GameRoom copyWith({
    String? code,
    String? hostId,
    List<RoomPlayer>? players,
    String? mode,
    String? family,
    int? maxPlayers,
    bool? isStarted,
    DateTime? startedAt,
    int? gameDurationSeconds,
  }) {
    return GameRoom(
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      players: players ?? this.players,
      mode: mode ?? this.mode,
      family: family ?? this.family,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isStarted: isStarted ?? this.isStarted,
      startedAt: startedAt ?? this.startedAt,
      gameDurationSeconds: gameDurationSeconds ?? this.gameDurationSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'players': players.map((p) => p.toJson()).toList(),
    'mode': mode,
    'family': family,
    'maxPlayers': maxPlayers,
    'isStarted': isStarted,
    'startedAt': startedAt?.toIso8601String(),
    'gameDurationSeconds': gameDurationSeconds,
  };

  factory GameRoom.fromJson(Map<String, dynamic> json) => GameRoom(
    code: json['code'] ?? '',
    hostId: json['hostId'] ?? '',
    players: (json['players'] as List<dynamic>?)
      ?.map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>))
      .toList() ?? [],
    mode: json['mode'] ?? 'supervivencia',
    family: json['family'] ?? 'todas',
    maxPlayers: json['maxPlayers'] ?? 4,
    isStarted: json['isStarted'] ?? false,
    startedAt: json['startedAt'] != null 
      ? DateTime.tryParse(json['startedAt']) 
      : null,
    gameDurationSeconds: json['gameDurationSeconds'],
  );
}

/// Evento multijugador
class MultiplayerEvent {
  final String type;
  final String senderId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const MultiplayerEvent({
    required this.type,
    required this.senderId,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'senderId': senderId,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MultiplayerEvent.fromJson(Map<String, dynamic> json) => MultiplayerEvent(
    type: json['type'] ?? '',
    senderId: json['senderId'] ?? '',
    data: json['data'] as Map<String, dynamic>? ?? {},
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
  );
}

/// Configuración del servidor multijugador
class MultiplayerConfig {
  final String serverUrl;
  final String apiKey;
  final bool enabled;

  const MultiplayerConfig({
    this.serverUrl = '',
    this.apiKey = '',
    this.enabled = false,
  });

  bool get isConfigured => serverUrl.isNotEmpty;

  factory MultiplayerConfig.fromEnv() {
    // Leer de variables de entorno o configuración
    return const MultiplayerConfig(
      serverUrl: String.fromEnvironment('MULTIPLAYER_URL', defaultValue: ''),
      apiKey: String.fromEnvironment('MULTIPLAYER_API_KEY', defaultValue: ''),
      enabled: bool.fromEnvironment('MULTIPLAYER_ENABLED', defaultValue: false),
    );
  }
}

/// Servicio de multijugador.
/// 
/// ARQUITECTURA PREPARADA PARA:
/// - Firebase Realtime Database / Firestore
/// - Supabase Realtime
/// - WebSocket personalizado
/// 
/// Para activar:
/// 1. Configurar MULTIPLAYER_URL y MULTIPLAYER_API_KEY
/// 2. Implementar _connectToServer() con el backend elegido
/// 3. Los métodos ya definen la interfaz completa
abstract class MultiplayerService {
  MultiplayerConnectionState get connectionState;
  Stream<MultiplayerConnectionState> get connectionStateStream;
  Stream<MultiplayerEvent> get eventStream;
  GameRoom? get currentRoom;
  RoomRole? get role;
  String? get playerId;

  /// Conecta al servidor multijugador
  Future<bool> connect(String playerName);

  /// Desconecta del servidor
  Future<void> disconnect();

  /// Crea una nueva sala
  Future<GameRoom?> createRoom({
    required String mode,
    required String family,
    int maxPlayers = 4,
    int? gameDurationSeconds,
  });

  /// Une a una sala existente por código
  Future<GameRoom?> joinRoom(String code);

  /// Sale de la sala actual
  Future<void> leaveRoom();

  /// Marca al jugador como listo
  Future<void> setReady(bool ready);

  /// Inicia la partida (solo host)
  Future<void> startGame();

  /// Envía actualización de estado de juego
  Future<void> sendGameUpdate({
    required int score,
    required int lives,
    required int correctAnswers,
    bool isFinished = false,
  });

  /// Notifica respuesta correcta (para efectos visuales en otros)
  Future<void> sendCorrectAnswer(String expression);

  /// Notifica fin de partida personal
  Future<void> sendGameOver(int finalScore);
}

/// Implementación offline/mock del servicio multijugador.
/// Usa esto mientras no haya backend configurado.
class OfflineMultiplayerService implements MultiplayerService {
  final _connectionStateController = StreamController<MultiplayerConnectionState>.broadcast();
  final _eventController = StreamController<MultiplayerEvent>.broadcast();
  
  MultiplayerConnectionState _state = MultiplayerConnectionState.disconnected;
  GameRoom? _currentRoom;
  String? _playerId;
  RoomRole? _role;

  @override
  MultiplayerConnectionState get connectionState => _state;

  @override
  Stream<MultiplayerConnectionState> get connectionStateStream => 
    _connectionStateController.stream;

  @override
  Stream<MultiplayerEvent> get eventStream => _eventController.stream;

  @override
  GameRoom? get currentRoom => _currentRoom;

  @override
  RoomRole? get role => _role;

  @override
  String? get playerId => _playerId;

  void _setState(MultiplayerConnectionState state) {
    _state = state;
    _connectionStateController.add(state);
  }

  @override
  Future<bool> connect(String playerName) async {
    _setState(MultiplayerConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 500));
    
    _playerId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    _setState(MultiplayerConnectionState.connected);
    
    return true;
  }

  @override
  Future<void> disconnect() async {
    _playerId = null;
    _currentRoom = null;
    _role = null;
    _setState(MultiplayerConnectionState.disconnected);
  }

  @override
  Future<GameRoom?> createRoom({
    required String mode,
    required String family,
    int maxPlayers = 4,
    int? gameDurationSeconds,
  }) async {
    if (_playerId == null) return null;

    // Generar código de sala aleatorio
    final code = _generateRoomCode();
    
    _currentRoom = GameRoom(
      code: code,
      hostId: _playerId!,
      players: [
        RoomPlayer(id: _playerId!, name: 'Tú', isReady: false),
      ],
      mode: mode,
      family: family,
      maxPlayers: maxPlayers,
      gameDurationSeconds: gameDurationSeconds,
    );
    
    _role = RoomRole.host;
    _setState(MultiplayerConnectionState.inRoom);
    
    return _currentRoom;
  }

  @override
  Future<GameRoom?> joinRoom(String code) async {
    if (_playerId == null) return null;
    
    // En modo offline, simular que no hay sala
    _eventController.add(MultiplayerEvent(
      type: 'error',
      senderId: 'system',
      data: {'message': 'Modo multijugador no disponible sin conexión al servidor.'},
      timestamp: DateTime.now(),
    ));
    
    return null;
  }

  @override
  Future<void> leaveRoom() async {
    _currentRoom = null;
    _role = null;
    _setState(MultiplayerConnectionState.connected);
  }

  @override
  Future<void> setReady(bool ready) async {
    if (_currentRoom == null || _playerId == null) return;
    
    final players = _currentRoom!.players.map((p) {
      if (p.id == _playerId) {
        return p.copyWith(isReady: ready);
      }
      return p;
    }).toList();
    
    _currentRoom = _currentRoom!.copyWith(players: players);
  }

  @override
  Future<void> startGame() async {
    if (_currentRoom == null || _role != RoomRole.host) return;
    
    _currentRoom = _currentRoom!.copyWith(
      isStarted: true,
      startedAt: DateTime.now(),
    );
    
    _setState(MultiplayerConnectionState.playing);
    
    _eventController.add(MultiplayerEvent(
      type: 'game_started',
      senderId: _playerId!,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> sendGameUpdate({
    required int score,
    required int lives,
    required int correctAnswers,
    bool isFinished = false,
  }) async {
    // En modo offline, solo actualizar estado local
    if (_currentRoom == null || _playerId == null) return;
    
    final players = _currentRoom!.players.map((p) {
      if (p.id == _playerId) {
        return p.copyWith(
          score: score,
          lives: lives,
          correctAnswers: correctAnswers,
          isFinished: isFinished,
        );
      }
      return p;
    }).toList();
    
    _currentRoom = _currentRoom!.copyWith(players: players);
  }

  @override
  Future<void> sendCorrectAnswer(String expression) async {
    // Noop en offline
  }

  @override
  Future<void> sendGameOver(int finalScore) async {
    await sendGameUpdate(
      score: finalScore,
      lives: 0,
      correctAnswers: 0,
      isFinished: true,
    );
    
    _eventController.add(MultiplayerEvent(
      type: 'player_finished',
      senderId: _playerId!,
      data: {'score': finalScore},
      timestamp: DateTime.now(),
    ));
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void dispose() {
    _connectionStateController.close();
    _eventController.close();
  }
}

/// Factory para crear el servicio apropiado según configuración
class MultiplayerServiceFactory {
  static MultiplayerService create() {
    final config = MultiplayerConfig.fromEnv();
    
    if (config.enabled && config.isConfigured) {
      // TODO: Retornar implementación real cuando haya backend
      // return FirebaseMultiplayerService(config);
      // return SupabaseMultiplayerService(config);
    }
    
    return OfflineMultiplayerService();
  }
}
