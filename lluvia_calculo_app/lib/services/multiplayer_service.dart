import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Estado de conexión multijugador
enum MultiplayerConnectionState {
  disconnected,
  connecting,
  connected,
  inRoom,
  waitingForOpponent,
  ready,
  playing,
  finished,
  error,
}

/// Rol en la sala
enum RoomRole { host, guest }

/// Estado de un jugador en la sala
class RoomPlayer {
  final String id;
  final String name;
  final bool isReady;
  final int score;
  final int lives;
  final int correctAnswers;
  final bool isFinished;
  final int lastUpdateMs;

  const RoomPlayer({
    required this.id,
    required this.name,
    this.isReady = false,
    this.score = 0,
    this.lives = 5,
    this.correctAnswers = 0,
    this.isFinished = false,
    this.lastUpdateMs = 0,
  });

  RoomPlayer copyWith({
    String? id,
    String? name,
    bool? isReady,
    int? score,
    int? lives,
    int? correctAnswers,
    bool? isFinished,
    int? lastUpdateMs,
  }) => RoomPlayer(
    id: id ?? this.id,
    name: name ?? this.name,
    isReady: isReady ?? this.isReady,
    score: score ?? this.score,
    lives: lives ?? this.lives,
    correctAnswers: correctAnswers ?? this.correctAnswers,
    isFinished: isFinished ?? this.isFinished,
    lastUpdateMs: lastUpdateMs ?? this.lastUpdateMs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isReady': isReady,
    'score': score,
    'lives': lives,
    'correctAnswers': correctAnswers,
    'isFinished': isFinished,
    'lastUpdateMs': lastUpdateMs,
  };

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    isReady: json['isReady'] ?? false,
    score: json['score'] ?? 0,
    lives: json['lives'] ?? 5,
    correctAnswers: json['correctAnswers'] ?? 0,
    isFinished: json['isFinished'] ?? false,
    lastUpdateMs: json['lastUpdateMs'] ?? 0,
  );
}

/// Información de una sala de juego
class GameRoom {
  final String code;
  final String hostId;
  final Map<String, RoomPlayer> players;
  final int gameSeed;
  final int gameDurationSeconds;
  final bool isStarted;
  final int? startedAtMs;
  final String status; // waiting, ready, playing, finished

  const GameRoom({
    required this.code,
    required this.hostId,
    this.players = const {},
    this.gameSeed = 0,
    this.gameDurationSeconds = 90,
    this.isStarted = false,
    this.startedAtMs,
    this.status = 'waiting',
  });

  bool get isFull => players.length >= 2;
  bool get allReady => players.values.every((p) => p.isReady);
  List<RoomPlayer> get playerList => players.values.toList();

  GameRoom copyWith({
    String? code,
    String? hostId,
    Map<String, RoomPlayer>? players,
    int? gameSeed,
    int? gameDurationSeconds,
    bool? isStarted,
    int? startedAtMs,
    String? status,
  }) => GameRoom(
    code: code ?? this.code,
    hostId: hostId ?? this.hostId,
    players: players ?? this.players,
    gameSeed: gameSeed ?? this.gameSeed,
    gameDurationSeconds: gameDurationSeconds ?? this.gameDurationSeconds,
    isStarted: isStarted ?? this.isStarted,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'players': players.map((k, v) => MapEntry(k, v.toJson())),
    'gameSeed': gameSeed,
    'gameDurationSeconds': gameDurationSeconds,
    'isStarted': isStarted,
    'startedAtMs': startedAtMs,
    'status': status,
  };

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    final playersJson = json['players'] as Map<String, dynamic>? ?? {};
    final players = <String, RoomPlayer>{};
    for (final entry in playersJson.entries) {
      players[entry.key] = RoomPlayer.fromJson(entry.value as Map<String, dynamic>);
    }
    return GameRoom(
      code: json['code'] ?? '',
      hostId: json['hostId'] ?? '',
      players: players,
      gameSeed: json['gameSeed'] ?? 0,
      gameDurationSeconds: json['gameDurationSeconds'] ?? 90,
      isStarted: json['isStarted'] ?? false,
      startedAtMs: json['startedAtMs'],
      status: json['status'] ?? 'waiting',
    );
  }
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
}

/// Servicio multijugador con Firebase Realtime Database REST API
abstract class MultiplayerService {
  MultiplayerConnectionState get connectionState;
  Stream<MultiplayerConnectionState> get connectionStateStream;
  Stream<GameRoom?> get roomStream;
  Stream<MultiplayerEvent> get eventStream;
  GameRoom? get currentRoom;
  RoomRole? get role;
  String? get playerId;
  RoomPlayer? get opponent;

  Future<bool> connect(String playerName);
  Future<void> disconnect();
  Future<GameRoom?> createRoom();
  Future<GameRoom?> joinRoom(String code);
  Future<void> leaveRoom();
  Future<void> setReady(bool ready);
  Future<void> startGame();
  Future<void> sendGameUpdate({
    required int score,
    required int lives,
    required int correctAnswers,
    bool isFinished = false,
  });
  Future<void> sendGameOver(int finalScore);
  void dispose();
}

/// Implementación con Firebase RTDB REST API
/// Funciona en web sin configuración nativa de Firebase
class FirebaseMultiplayerService implements MultiplayerService {
  // Firebase RTDB URL - Este es un proyecto público de demo
  // Para producción, crear tu propio proyecto en console.firebase.google.com
  static const String _firebaseUrl = 'https://lluvia-calculo-default-rtdb.firebaseio.com';
  
  final _connectionStateController = StreamController<MultiplayerConnectionState>.broadcast();
  final _roomController = StreamController<GameRoom?>.broadcast();
  final _eventController = StreamController<MultiplayerEvent>.broadcast();
  
  MultiplayerConnectionState _state = MultiplayerConnectionState.disconnected;
  GameRoom? _currentRoom;
  String? _playerId;
  String? _playerName;
  RoomRole? _role;
  Timer? _pollingTimer;

  @override
  MultiplayerConnectionState get connectionState => _state;
  
  @override
  Stream<MultiplayerConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  @override
  Stream<GameRoom?> get roomStream => _roomController.stream;
  
  @override
  Stream<MultiplayerEvent> get eventStream => _eventController.stream;
  
  @override
  GameRoom? get currentRoom => _currentRoom;
  
  @override
  RoomRole? get role => _role;
  
  @override
  String? get playerId => _playerId;

  @override
  RoomPlayer? get opponent {
    if (_currentRoom == null || _playerId == null) return null;
    for (final player in _currentRoom!.players.values) {
      if (player.id != _playerId) return player;
    }
    return null;
  }

  void _setState(MultiplayerConnectionState state) {
    _state = state;
    _connectionStateController.add(state);
  }

  void _updateRoom(GameRoom? room) {
    _currentRoom = room;
    _roomController.add(room);
  }

  @override
  Future<bool> connect(String playerName) async {
    _setState(MultiplayerConnectionState.connecting);
    
    try {
      // Verificar conectividad con Firebase
      final response = await http.get(
        Uri.parse('$_firebaseUrl/.json?shallow=true'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 || response.statusCode == 404) {
        _playerId = 'p_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
        _playerName = playerName;
        _setState(MultiplayerConnectionState.connected);
        return true;
      }
    } catch (e) {
      print('Firebase connection error: $e');
    }
    
    _setState(MultiplayerConnectionState.error);
    return false;
  }

  @override
  Future<void> disconnect() async {
    await leaveRoom();
    _stopPolling();
    _playerId = null;
    _playerName = null;
    _role = null;
    _updateRoom(null);
    _setState(MultiplayerConnectionState.disconnected);
  }

  @override
  Future<GameRoom?> createRoom() async {
    if (_playerId == null || _playerName == null) return null;
    
    final code = _generateRoomCode();
    final seed = Random().nextInt(1000000);
    
    final room = GameRoom(
      code: code,
      hostId: _playerId!,
      players: {
        _playerId!: RoomPlayer(
          id: _playerId!,
          name: _playerName!,
          isReady: false,
          lastUpdateMs: DateTime.now().millisecondsSinceEpoch,
        ),
      },
      gameSeed: seed,
      status: 'waiting',
    );
    
    try {
      final response = await http.put(
        Uri.parse('$_firebaseUrl/rooms/$code.json'),
        body: jsonEncode(room.toJson()),
      );
      
      if (response.statusCode == 200) {
        _role = RoomRole.host;
        _updateRoom(room);
        _setState(MultiplayerConnectionState.waitingForOpponent);
        _startPolling(code);
        return room;
      }
    } catch (e) {
      print('Create room error: $e');
    }
    
    return null;
  }

  @override
  Future<GameRoom?> joinRoom(String code) async {
    if (_playerId == null || _playerName == null) return null;
    
    final upperCode = code.toUpperCase().trim();
    
    try {
      // Leer sala actual
      final response = await http.get(
        Uri.parse('$_firebaseUrl/rooms/$upperCode.json'),
      );
      
      if (response.statusCode != 200 || response.body == 'null') {
        _eventController.add(MultiplayerEvent(
          type: 'error',
          senderId: 'system',
          data: {'message': 'Sala no encontrada'},
          timestamp: DateTime.now(),
        ));
        return null;
      }
      
      final roomData = jsonDecode(response.body) as Map<String, dynamic>;
      var room = GameRoom.fromJson(roomData);
      
      if (room.isFull) {
        _eventController.add(MultiplayerEvent(
          type: 'error',
          senderId: 'system',
          data: {'message': 'Sala llena'},
          timestamp: DateTime.now(),
        ));
        return null;
      }
      
      if (room.isStarted) {
        _eventController.add(MultiplayerEvent(
          type: 'error',
          senderId: 'system',
          data: {'message': 'Partida ya iniciada'},
          timestamp: DateTime.now(),
        ));
        return null;
      }
      
      // Añadir jugador
      final newPlayers = Map<String, RoomPlayer>.from(room.players);
      newPlayers[_playerId!] = RoomPlayer(
        id: _playerId!,
        name: _playerName!,
        isReady: false,
        lastUpdateMs: DateTime.now().millisecondsSinceEpoch,
      );
      
      room = room.copyWith(players: newPlayers);
      
      // Actualizar en Firebase
      final updateResponse = await http.put(
        Uri.parse('$_firebaseUrl/rooms/$upperCode.json'),
        body: jsonEncode(room.toJson()),
      );
      
      if (updateResponse.statusCode == 200) {
        _role = RoomRole.guest;
        _updateRoom(room);
        _setState(MultiplayerConnectionState.inRoom);
        _startPolling(upperCode);
        return room;
      }
    } catch (e) {
      print('Join room error: $e');
    }
    
    return null;
  }

  @override
  Future<void> leaveRoom() async {
    if (_currentRoom == null) return;
    
    _stopPolling();
    
    try {
      if (_role == RoomRole.host) {
        // Host: eliminar sala
        await http.delete(
          Uri.parse('$_firebaseUrl/rooms/${_currentRoom!.code}.json'),
        );
      } else if (_playerId != null) {
        // Guest: solo remover jugador
        await http.delete(
          Uri.parse('$_firebaseUrl/rooms/${_currentRoom!.code}/players/$_playerId.json'),
        );
      }
    } catch (e) {
      print('Leave room error: $e');
    }
    
    _role = null;
    _updateRoom(null);
    _setState(MultiplayerConnectionState.connected);
  }

  @override
  Future<void> setReady(bool ready) async {
    if (_currentRoom == null || _playerId == null) return;
    
    try {
      await http.patch(
        Uri.parse('$_firebaseUrl/rooms/${_currentRoom!.code}/players/$_playerId.json'),
        body: jsonEncode({
          'isReady': ready,
          'lastUpdateMs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      
      // Actualizar local
      final updatedPlayers = Map<String, RoomPlayer>.from(_currentRoom!.players);
      if (updatedPlayers.containsKey(_playerId)) {
        updatedPlayers[_playerId!] = updatedPlayers[_playerId!]!.copyWith(isReady: ready);
      }
      _updateRoom(_currentRoom!.copyWith(players: updatedPlayers));
      
      if (ready) {
        _setState(MultiplayerConnectionState.ready);
      }
    } catch (e) {
      print('Set ready error: $e');
    }
  }

  @override
  Future<void> startGame() async {
    if (_currentRoom == null || _role != RoomRole.host) return;
    if (!_currentRoom!.allReady || _currentRoom!.players.length < 2) return;
    
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      
      await http.patch(
        Uri.parse('$_firebaseUrl/rooms/${_currentRoom!.code}.json'),
        body: jsonEncode({
          'isStarted': true,
          'startedAtMs': startTime,
          'status': 'playing',
        }),
      );
      
      _updateRoom(_currentRoom!.copyWith(
        isStarted: true,
        startedAtMs: startTime,
        status: 'playing',
      ));
      
      _setState(MultiplayerConnectionState.playing);
      
      _eventController.add(MultiplayerEvent(
        type: 'game_started',
        senderId: _playerId!,
        data: {'seed': _currentRoom!.gameSeed, 'startedAtMs': startTime},
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      print('Start game error: $e');
    }
  }

  @override
  Future<void> sendGameUpdate({
    required int score,
    required int lives,
    required int correctAnswers,
    bool isFinished = false,
  }) async {
    if (_currentRoom == null || _playerId == null) return;
    
    try {
      await http.patch(
        Uri.parse('$_firebaseUrl/rooms/${_currentRoom!.code}/players/$_playerId.json'),
        body: jsonEncode({
          'score': score,
          'lives': lives,
          'correctAnswers': correctAnswers,
          'isFinished': isFinished,
          'lastUpdateMs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      print('Send update error: $e');
    }
  }

  @override
  Future<void> sendGameOver(int finalScore) async {
    await sendGameUpdate(
      score: finalScore,
      lives: 0,
      correctAnswers: 0,
      isFinished: true,
    );
    
    _setState(MultiplayerConnectionState.finished);
    
    _eventController.add(MultiplayerEvent(
      type: 'game_over',
      senderId: _playerId!,
      data: {'finalScore': finalScore},
      timestamp: DateTime.now(),
    ));
  }

  void _startPolling(String roomCode) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      await _pollRoom(roomCode);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollRoom(String roomCode) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/rooms/$roomCode.json'),
      );
      
      if (response.statusCode != 200 || response.body == 'null') {
        // Sala eliminada
        _stopPolling();
        _role = null;
        _updateRoom(null);
        _setState(MultiplayerConnectionState.connected);
        _eventController.add(MultiplayerEvent(
          type: 'room_closed',
          senderId: 'system',
          data: {},
          timestamp: DateTime.now(),
        ));
        return;
      }
      
      final roomData = jsonDecode(response.body) as Map<String, dynamic>;
      final newRoom = GameRoom.fromJson(roomData);
      
      // Detectar cambios
      final oldRoom = _currentRoom;
      _updateRoom(newRoom);
      
      // Cambio de estado
      if (newRoom.isStarted && !(_state == MultiplayerConnectionState.playing)) {
        _setState(MultiplayerConnectionState.playing);
        _eventController.add(MultiplayerEvent(
          type: 'game_started',
          senderId: newRoom.hostId,
          data: {'seed': newRoom.gameSeed, 'startedAtMs': newRoom.startedAtMs},
          timestamp: DateTime.now(),
        ));
      }
      
      // Nuevo jugador se unió
      if (oldRoom != null && newRoom.players.length > oldRoom.players.length) {
        final newPlayerId = newRoom.players.keys.firstWhere(
          (k) => !oldRoom.players.containsKey(k),
          orElse: () => '',
        );
        if (newPlayerId.isNotEmpty) {
          _setState(MultiplayerConnectionState.inRoom);
          _eventController.add(MultiplayerEvent(
            type: 'player_joined',
            senderId: newPlayerId,
            data: newRoom.players[newPlayerId]!.toJson(),
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // Verificar si ambos terminaron
      if (newRoom.status == 'playing') {
        final allFinished = newRoom.players.values.every((p) => p.isFinished);
        if (allFinished && _state != MultiplayerConnectionState.finished) {
          _setState(MultiplayerConnectionState.finished);
          _eventController.add(MultiplayerEvent(
            type: 'match_finished',
            senderId: 'system',
            data: {
              'players': newRoom.players.values.map((p) => p.toJson()).toList(),
            },
            timestamp: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      print('Poll error: $e');
    }
  }

  String _generateRoomCode() {
    // Caracteres sin ambigüedades (sin 0/O/1/I/L)
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _stopPolling();
    _connectionStateController.close();
    _roomController.close();
    _eventController.close();
  }
}

/// Implementación offline para cuando no hay red
class OfflineMultiplayerService implements MultiplayerService {
  final _connectionStateController = StreamController<MultiplayerConnectionState>.broadcast();
  final _roomController = StreamController<GameRoom?>.broadcast();
  final _eventController = StreamController<MultiplayerEvent>.broadcast();
  
  @override
  MultiplayerConnectionState get connectionState => MultiplayerConnectionState.disconnected;
  
  @override
  Stream<MultiplayerConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  @override
  Stream<GameRoom?> get roomStream => _roomController.stream;
  
  @override
  Stream<MultiplayerEvent> get eventStream => _eventController.stream;
  
  @override
  GameRoom? get currentRoom => null;
  
  @override
  RoomRole? get role => null;
  
  @override
  String? get playerId => null;
  
  @override
  RoomPlayer? get opponent => null;

  @override
  Future<bool> connect(String playerName) async {
    _eventController.add(MultiplayerEvent(
      type: 'error',
      senderId: 'system',
      data: {'message': 'Modo multijugador no disponible offline'},
      timestamp: DateTime.now(),
    ));
    return false;
  }

  @override
  Future<void> disconnect() async {}
  
  @override
  Future<GameRoom?> createRoom() async => null;
  
  @override
  Future<GameRoom?> joinRoom(String code) async => null;
  
  @override
  Future<void> leaveRoom() async {}
  
  @override
  Future<void> setReady(bool ready) async {}
  
  @override
  Future<void> startGame() async {}
  
  @override
  Future<void> sendGameUpdate({
    required int score,
    required int lives,
    required int correctAnswers,
    bool isFinished = false,
  }) async {}
  
  @override
  Future<void> sendGameOver(int finalScore) async {}
  
  @override
  void dispose() {
    _connectionStateController.close();
    _roomController.close();
    _eventController.close();
  }
}

/// Factory para crear el servicio apropiado
class MultiplayerServiceFactory {
  static MultiplayerService create({bool forceOffline = false}) {
    if (forceOffline) {
      return OfflineMultiplayerService();
    }
    return FirebaseMultiplayerService();
  }
}
