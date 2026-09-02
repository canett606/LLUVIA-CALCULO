import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Estado del torneo
enum TournamentStatus {
  lobby,      // Esperando jugadores
  inProgress, // Partidas en curso
  finished,   // Campeón declarado
}

/// Estado de un jugador en el torneo
class TournamentPlayer {
  final String id;
  final String name;
  final int seed; // Posición en el bracket (0-15)
  final bool eliminated;
  final int currentRound; // Ronda actual (1=primera, 2=segunda, etc)
  
  const TournamentPlayer({
    required this.id,
    required this.name,
    required this.seed,
    this.eliminated = false,
    this.currentRound = 1,
  });
  
  TournamentPlayer copyWith({
    String? id,
    String? name,
    int? seed,
    bool? eliminated,
    int? currentRound,
  }) => TournamentPlayer(
    id: id ?? this.id,
    name: name ?? this.name,
    seed: seed ?? this.seed,
    eliminated: eliminated ?? this.eliminated,
    currentRound: currentRound ?? this.currentRound,
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seed': seed,
    'eliminated': eliminated,
    'currentRound': currentRound,
  };
  
  factory TournamentPlayer.fromJson(Map<String, dynamic> json) => TournamentPlayer(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    seed: json['seed'] ?? 0,
    eliminated: json['eliminated'] ?? false,
    currentRound: json['currentRound'] ?? 1,
  );
}

/// Un partido del torneo
class TournamentMatch {
  final String id;
  final int round;        // 1=octavos/cuartos/semis según tamaño, última=final
  final int position;     // Posición en la ronda (0-7 para octavos, 0-3 cuartos, etc)
  final String? player1Id;
  final String? player2Id;
  final String? winnerId;
  final String? roomCode;  // Código de sala 1v1 para este match
  final int? startedAtMs;
  final bool finished;
  final int? player1Score;
  final int? player2Score;
  
  const TournamentMatch({
    required this.id,
    required this.round,
    required this.position,
    this.player1Id,
    this.player2Id,
    this.winnerId,
    this.roomCode,
    this.startedAtMs,
    this.finished = false,
    this.player1Score,
    this.player2Score,
  });
  
  bool get isReady => player1Id != null && player2Id != null && !finished;
  bool get isWaitingForPlayers => player1Id == null || player2Id == null;
  
  TournamentMatch copyWith({
    String? id,
    int? round,
    int? position,
    String? player1Id,
    String? player2Id,
    String? winnerId,
    String? roomCode,
    int? startedAtMs,
    bool? finished,
    int? player1Score,
    int? player2Score,
  }) => TournamentMatch(
    id: id ?? this.id,
    round: round ?? this.round,
    position: position ?? this.position,
    player1Id: player1Id ?? this.player1Id,
    player2Id: player2Id ?? this.player2Id,
    winnerId: winnerId ?? this.winnerId,
    roomCode: roomCode ?? this.roomCode,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    finished: finished ?? this.finished,
    player1Score: player1Score ?? this.player1Score,
    player2Score: player2Score ?? this.player2Score,
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'round': round,
    'position': position,
    'player1Id': player1Id,
    'player2Id': player2Id,
    'winnerId': winnerId,
    'roomCode': roomCode,
    'startedAtMs': startedAtMs,
    'finished': finished,
    'player1Score': player1Score,
    'player2Score': player2Score,
  };
  
  factory TournamentMatch.fromJson(Map<String, dynamic> json) => TournamentMatch(
    id: json['id'] ?? '',
    round: json['round'] ?? 1,
    position: json['position'] ?? 0,
    player1Id: json['player1Id'],
    player2Id: json['player2Id'],
    winnerId: json['winnerId'],
    roomCode: json['roomCode'],
    startedAtMs: json['startedAtMs'],
    finished: json['finished'] ?? false,
    player1Score: json['player1Score'],
    player2Score: json['player2Score'],
  );
}

/// Torneo completo
class Tournament {
  final String code;
  final String hostId;
  final int size; // 4, 8, o 16
  final TournamentStatus status;
  final Map<String, TournamentPlayer> players;
  final Map<String, TournamentMatch> matches;
  final String? championId;
  final int createdAtMs;
  
  const Tournament({
    required this.code,
    required this.hostId,
    required this.size,
    this.status = TournamentStatus.lobby,
    this.players = const {},
    this.matches = const {},
    this.championId,
    required this.createdAtMs,
  });
  
  int get totalRounds {
    if (size == 4) return 2;  // Semis + Final
    if (size == 8) return 3;  // Cuartos + Semis + Final
    return 4; // Octavos + Cuartos + Semis + Final
  }
  
  String getRoundName(int round) {
    final remaining = totalRounds - round + 1;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semifinales';
    if (remaining == 3) return 'Cuartos de Final';
    return 'Octavos de Final';
  }
  
  bool get isFull => players.length >= size;
  
  List<TournamentPlayer> get playerList => players.values.toList()
    ..sort((a, b) => a.seed.compareTo(b.seed));
  
  Tournament copyWith({
    String? code,
    String? hostId,
    int? size,
    TournamentStatus? status,
    Map<String, TournamentPlayer>? players,
    Map<String, TournamentMatch>? matches,
    String? championId,
    int? createdAtMs,
  }) => Tournament(
    code: code ?? this.code,
    hostId: hostId ?? this.hostId,
    size: size ?? this.size,
    status: status ?? this.status,
    players: players ?? this.players,
    matches: matches ?? this.matches,
    championId: championId ?? this.championId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  
  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'size': size,
    'status': status.name,
    'players': players.map((k, v) => MapEntry(k, v.toJson())),
    'matches': matches.map((k, v) => MapEntry(k, v.toJson())),
    'championId': championId,
    'createdAtMs': createdAtMs,
  };
  
  factory Tournament.fromJson(Map<String, dynamic> json) {
    final playersJson = json['players'] as Map<String, dynamic>? ?? {};
    final players = <String, TournamentPlayer>{};
    for (final entry in playersJson.entries) {
      players[entry.key] = TournamentPlayer.fromJson(entry.value as Map<String, dynamic>);
    }
    
    final matchesJson = json['matches'] as Map<String, dynamic>? ?? {};
    final matches = <String, TournamentMatch>{};
    for (final entry in matchesJson.entries) {
      matches[entry.key] = TournamentMatch.fromJson(entry.value as Map<String, dynamic>);
    }
    
    return Tournament(
      code: json['code'] ?? '',
      hostId: json['hostId'] ?? '',
      size: json['size'] ?? 4,
      status: TournamentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TournamentStatus.lobby,
      ),
      players: players,
      matches: matches,
      championId: json['championId'],
      createdAtMs: json['createdAtMs'] ?? 0,
    );
  }
}

/// Servicio de torneos con Firebase RTDB
class TournamentService {
  static const String _firebaseUrl = 
    'https://lluvia-calculo-app-default-rtdb.europe-west1.firebasedatabase.app';
  
  final _tournamentController = StreamController<Tournament?>.broadcast();
  
  Tournament? _currentTournament;
  String? _playerId;
  String? _playerName;
  Timer? _pollingTimer;
  String? _errorMessage;
  
  Stream<Tournament?> get tournamentStream => _tournamentController.stream;
  Tournament? get currentTournament => _currentTournament;
  String? get playerId => _playerId;
  String? get errorMessage => _errorMessage;
  
  bool get isHost => _currentTournament?.hostId == _playerId;
  
  TournamentPlayer? get myPlayer {
    if (_currentTournament == null || _playerId == null) return null;
    return _currentTournament!.players[_playerId];
  }
  
  void _updateTournament(Tournament? t) {
    _currentTournament = t;
    _tournamentController.add(t);
  }
  
  Future<bool> _checkBackend() async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/tournaments.json?shallow=true'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  void setPlayer(String id, String name) {
    _playerId = id;
    _playerName = name;
  }
  
  Future<Tournament?> createTournament(int size) async {
    if (_playerId == null || _playerName == null) return null;
    if (size != 4 && size != 8 && size != 16) return null;
    
    _errorMessage = null;
    
    if (!await _checkBackend()) {
      _errorMessage = 'El servidor no está disponible.';
      return null;
    }
    
    final code = _generateCode();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final tournament = Tournament(
      code: code,
      hostId: _playerId!,
      size: size,
      status: TournamentStatus.lobby,
      players: {
        _playerId!: TournamentPlayer(
          id: _playerId!,
          name: _playerName!,
          seed: 0,
        ),
      },
      createdAtMs: now,
    );
    
    try {
      final response = await http.put(
        Uri.parse('$_firebaseUrl/tournaments/$code.json'),
        body: jsonEncode(tournament.toJson()),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        _updateTournament(tournament);
        _startPolling(code);
        return tournament;
      }
    } catch (e) {
      _errorMessage = 'No se pudo crear el campeonato.';
    }
    
    return null;
  }
  
  Future<Tournament?> joinTournament(String code) async {
    if (_playerId == null || _playerName == null) return null;
    
    _errorMessage = null;
    final upperCode = code.toUpperCase().trim();
    
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/tournaments/$upperCode.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200 || response.body == 'null') {
        _errorMessage = 'Campeonato no encontrado.';
        return null;
      }
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      var tournament = Tournament.fromJson(data);
      
      if (tournament.isFull) {
        _errorMessage = 'El campeonato está lleno.';
        return null;
      }
      
      if (tournament.status != TournamentStatus.lobby) {
        _errorMessage = 'El campeonato ya comenzó.';
        return null;
      }
      
      // Añadir jugador
      final newPlayers = Map<String, TournamentPlayer>.from(tournament.players);
      newPlayers[_playerId!] = TournamentPlayer(
        id: _playerId!,
        name: _playerName!,
        seed: newPlayers.length,
      );
      
      tournament = tournament.copyWith(players: newPlayers);
      
      final updateResponse = await http.put(
        Uri.parse('$_firebaseUrl/tournaments/$upperCode.json'),
        body: jsonEncode(tournament.toJson()),
      ).timeout(const Duration(seconds: 10));
      
      if (updateResponse.statusCode == 200) {
        _updateTournament(tournament);
        _startPolling(upperCode);
        return tournament;
      }
    } catch (e) {
      _errorMessage = 'El servidor no está disponible.';
    }
    
    return null;
  }
  
  Future<void> startTournament() async {
    if (_currentTournament == null || !isHost) return;
    if (!_currentTournament!.isFull) return;
    
    // Shuffle players para bracket aleatorio
    final playerList = _currentTournament!.players.values.toList();
    playerList.shuffle(Random());
    
    final newPlayers = <String, TournamentPlayer>{};
    for (int i = 0; i < playerList.length; i++) {
      newPlayers[playerList[i].id] = playerList[i].copyWith(seed: i);
    }
    
    // Generar matches de la primera ronda
    final matches = <String, TournamentMatch>{};
    final matchCount = _currentTournament!.size ~/ 2;
    
    for (int i = 0; i < matchCount; i++) {
      final matchId = 'r1_m$i';
      final p1 = playerList[i * 2];
      final p2 = playerList[i * 2 + 1];
      final roomCode = _generateCode();
      
      matches[matchId] = TournamentMatch(
        id: matchId,
        round: 1,
        position: i,
        player1Id: p1.id,
        player2Id: p2.id,
        roomCode: roomCode,
      );
    }
    
    // Generar matches vacíos para rondas siguientes
    int matchesInRound = matchCount ~/ 2;
    int round = 2;
    while (matchesInRound >= 1) {
      for (int i = 0; i < matchesInRound; i++) {
        final matchId = 'r${round}_m$i';
        matches[matchId] = TournamentMatch(
          id: matchId,
          round: round,
          position: i,
        );
      }
      matchesInRound ~/= 2;
      round++;
    }
    
    final updated = _currentTournament!.copyWith(
      status: TournamentStatus.inProgress,
      players: newPlayers,
      matches: matches,
    );
    
    try {
      await http.put(
        Uri.parse('$_firebaseUrl/tournaments/${_currentTournament!.code}.json'),
        body: jsonEncode(updated.toJson()),
      ).timeout(const Duration(seconds: 10));
      
      _updateTournament(updated);
    } catch (e) {
      // Silent fail
    }
  }
  
  /// Encuentra el match actual del jugador
  TournamentMatch? getMyCurrentMatch() {
    if (_currentTournament == null || _playerId == null) return null;
    if (_currentTournament!.status != TournamentStatus.inProgress) return null;
    
    final me = myPlayer;
    if (me == null || me.eliminated) return null;
    
    // Buscar match no terminado donde estoy
    for (final match in _currentTournament!.matches.values) {
      if (match.finished) continue;
      if (match.player1Id == _playerId || match.player2Id == _playerId) {
        return match;
      }
    }
    return null;
  }
  
  /// Reportar resultado de un match
  Future<void> reportMatchResult(String matchId, String winnerId, int winnerScore, int loserScore) async {
    if (_currentTournament == null) return;
    
    final match = _currentTournament!.matches[matchId];
    if (match == null) return;
    
    final loserId = match.player1Id == winnerId ? match.player2Id : match.player1Id;
    
    // Actualizar match
    final updatedMatches = Map<String, TournamentMatch>.from(_currentTournament!.matches);
    updatedMatches[matchId] = match.copyWith(
      winnerId: winnerId,
      finished: true,
      player1Score: match.player1Id == winnerId ? winnerScore : loserScore,
      player2Score: match.player2Id == winnerId ? winnerScore : loserScore,
    );
    
    // Marcar perdedor como eliminado
    final updatedPlayers = Map<String, TournamentPlayer>.from(_currentTournament!.players);
    if (loserId != null && updatedPlayers.containsKey(loserId)) {
      updatedPlayers[loserId] = updatedPlayers[loserId]!.copyWith(eliminated: true);
    }
    if (updatedPlayers.containsKey(winnerId)) {
      updatedPlayers[winnerId] = updatedPlayers[winnerId]!.copyWith(
        currentRound: match.round + 1,
      );
    }
    
    // Avanzar ganador al siguiente match
    final nextRound = match.round + 1;
    final nextPosition = match.position ~/ 2;
    final nextMatchId = 'r${nextRound}_m$nextPosition';
    
    if (updatedMatches.containsKey(nextMatchId)) {
      final nextMatch = updatedMatches[nextMatchId]!;
      final isFirstSlot = match.position % 2 == 0;
      
      updatedMatches[nextMatchId] = isFirstSlot
        ? nextMatch.copyWith(player1Id: winnerId, roomCode: nextMatch.roomCode ?? _generateCode())
        : nextMatch.copyWith(player2Id: winnerId, roomCode: nextMatch.roomCode ?? _generateCode());
    }
    
    // Verificar si hay campeón
    String? championId;
    TournamentStatus status = TournamentStatus.inProgress;
    
    final finalMatch = updatedMatches.values.where((m) => 
      m.round == _currentTournament!.totalRounds).firstOrNull;
    if (finalMatch != null && finalMatch.finished) {
      championId = finalMatch.winnerId;
      status = TournamentStatus.finished;
    }
    
    final updated = _currentTournament!.copyWith(
      matches: updatedMatches,
      players: updatedPlayers,
      championId: championId,
      status: status,
    );
    
    try {
      await http.put(
        Uri.parse('$_firebaseUrl/tournaments/${_currentTournament!.code}.json'),
        body: jsonEncode(updated.toJson()),
      ).timeout(const Duration(seconds: 10));
      
      _updateTournament(updated);
    } catch (e) {
      // Silent fail
    }
  }
  
  /// Forfeit: avanzar por abandono
  Future<void> claimForfeit(String matchId) async {
    if (_currentTournament == null || _playerId == null) return;
    
    final match = _currentTournament!.matches[matchId];
    if (match == null || match.finished) return;
    if (match.player1Id != _playerId && match.player2Id != _playerId) return;
    
    // Verificar que pasaron 120s desde que el match está listo
    final startTime = match.startedAtMs ?? _currentTournament!.createdAtMs;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
    if (elapsed < 120000) return; // 2 minutos
    
    await reportMatchResult(matchId, _playerId!, 0, 0);
  }
  
  Future<void> leaveTournament() async {
    _stopPolling();
    _updateTournament(null);
  }
  
  void _startPolling(String code) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      await _pollTournament(code);
    });
  }
  
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  Future<void> _pollTournament(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/tournaments/$code.json'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode != 200 || response.body == 'null') {
        _stopPolling();
        _updateTournament(null);
        return;
      }
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tournament = Tournament.fromJson(data);
      _updateTournament(tournament);
    } catch (e) {
      // Silent fail
    }
  }
  
  String _generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  }
  
  void dispose() {
    _stopPolling();
    _tournamentController.close();
  }
}
