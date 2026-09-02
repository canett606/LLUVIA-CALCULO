import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/tournament_service.dart';

/// Pantalla principal del Campeonato
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final _codeController = TextEditingController();
  final _tournamentService = TournamentService();
  
  bool _isCreating = false;
  bool _isJoining = false;
  String? _errorMessage;
  int _selectedSize = 4;
  
  StreamSubscription<Tournament?>? _tournamentSubscription;

  @override
  void initState() {
    super.initState();
    _setupService();
  }

  void _setupService() {
    final provider = context.read<GameProvider>();
    if (provider.multiplayer.playerId != null) {
      _tournamentService.setPlayer(
        provider.multiplayer.playerId!,
        provider.currentProfile?.name ?? 'Jugador',
      );
    }
    
    _tournamentSubscription = _tournamentService.tournamentStream.listen((t) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tournamentSubscription?.cancel();
    _tournamentService.dispose();
    super.dispose();
  }

  Future<void> _createTournament() async {
    final provider = context.read<GameProvider>();
    
    // Asegurar conexión
    if (provider.multiplayer.playerId == null) {
      await provider.multiplayer.connect(provider.currentProfile?.name ?? 'Jugador');
    }
    
    _tournamentService.setPlayer(
      provider.multiplayer.playerId!,
      provider.currentProfile?.name ?? 'Jugador',
    );
    
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });
    
    final tournament = await _tournamentService.createTournament(_selectedSize);
    
    if (mounted) {
      setState(() => _isCreating = false);
      if (tournament == null) {
        setState(() => _errorMessage = _tournamentService.errorMessage ?? 'No se pudo crear el campeonato.');
      }
    }
  }

  Future<void> _joinTournament() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Introduce el código del campeonato');
      return;
    }
    
    final provider = context.read<GameProvider>();
    
    if (provider.multiplayer.playerId == null) {
      await provider.multiplayer.connect(provider.currentProfile?.name ?? 'Jugador');
    }
    
    _tournamentService.setPlayer(
      provider.multiplayer.playerId!,
      provider.currentProfile?.name ?? 'Jugador',
    );
    
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });
    
    final tournament = await _tournamentService.joinTournament(code);
    
    if (mounted) {
      setState(() => _isJoining = false);
      if (tournament == null) {
        setState(() => _errorMessage = _tournamentService.errorMessage ?? 'No se pudo unir al campeonato.');
      }
    }
  }

  Future<void> _startTournament() async {
    await _tournamentService.startTournament();
  }

  Future<void> _leaveTournament() async {
    await _tournamentService.leaveTournament();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tournament = _tournamentService.currentTournament;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campeonato'),
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
        child: SafeArea(
          child: tournament == null
            ? _buildLobbyCreation()
            : _buildTournamentView(tournament),
        ),
      ),
    );
  }

  Widget _buildLobbyCreation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'Campeonato Mundial',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Eliminación directa · El mejor avanza',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Selector de tamaño
          const Text('Número de jugadores:', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              _SizeButton(size: 4, selected: _selectedSize == 4, onTap: () => setState(() => _selectedSize = 4)),
              const SizedBox(width: 8),
              _SizeButton(size: 8, selected: _selectedSize == 8, onTap: () => setState(() => _selectedSize = 8)),
              const SizedBox(width: 8),
              _SizeButton(size: 16, selected: _selectedSize == 16, onTap: () => setState(() => _selectedSize = 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getSizeDescription(_selectedSize),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Crear
          _buildButton('Crear Campeonato', Icons.add_circle, _createTournament, isLoading: _isCreating, primary: true),
          const SizedBox(height: 16),
          
          // Separador
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white24)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('o', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Unirse
          const Text('Unirse con código:', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'ABCD',
                    hintStyle: TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withAlpha(20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z2-9]')),
                    _UpperCaseFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildButton('Unirse', Icons.login, _joinTournament, isLoading: _isJoining, compact: true),
            ],
          ),
          
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentView(Tournament tournament) {
    if (tournament.status == TournamentStatus.lobby) {
      return _buildLobbyWaiting(tournament);
    }
    return _buildBracketView(tournament);
  }

  Widget _buildLobbyWaiting(Tournament tournament) {
    final isHost = _tournamentService.isHost;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Código
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text('Código del campeonato:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tournament.code,
                      style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.amber),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tournament.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Jugadores
          Text(
            'Jugadores: ${tournament.players.length}/${tournament.size}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: ListView.builder(
              itemCount: tournament.size,
              itemBuilder: (context, index) {
                final players = tournament.playerList;
                final player = index < players.length ? players[index] : null;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: player != null ? Colors.green.withAlpha(30) : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: player?.id == _tournamentService.playerId ? Colors.amber : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('${index + 1}.', style: const TextStyle(color: Colors.white54)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          player?.name ?? 'Esperando...',
                          style: TextStyle(
                            color: player != null ? Colors.white : Colors.white38,
                            fontWeight: player?.id == _tournamentService.playerId ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (player?.id == tournament.hostId)
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Botones
          if (isHost && tournament.isFull)
            _buildButton('¡COMENZAR CAMPEONATO!', Icons.play_arrow, _startTournament, primary: true),
          
          if (isHost && !tournament.isFull)
            const Text(
              'Esperando a que se llene el campeonato...',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 12),
          _buildButton('Salir', Icons.exit_to_app, _leaveTournament, destructive: true),
        ],
      ),
    );
  }

  Widget _buildBracketView(Tournament tournament) {
    final myPlayer = _tournamentService.myPlayer;
    final myMatch = _tournamentService.getMyCurrentMatch();
    final isEliminated = myPlayer?.eliminated ?? false;
    final isChampion = tournament.championId == _tournamentService.playerId;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Estado del jugador
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isChampion ? Colors.amber.withAlpha(50) : isEliminated ? Colors.red.withAlpha(30) : Colors.blue.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isChampion ? Icons.emoji_events : isEliminated ? Icons.cancel : Icons.person,
                  color: isChampion ? Colors.amber : isEliminated ? Colors.red : Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isChampion ? '¡CAMPEÓN!' : isEliminated ? 'Eliminado' : myPlayer?.name ?? 'Tú',
                        style: TextStyle(
                          color: isChampion ? Colors.amber : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isChampion && !isEliminated && myMatch != null)
                        Text(
                          'Ronda: ${tournament.getRoundName(myMatch.round)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Match actual
          if (myMatch != null && !isEliminated && !isChampion) ...[
            _buildMatchCard(tournament, myMatch, isMyMatch: true),
            const SizedBox(height: 16),
          ],
          
          // Bracket
          const Text('Bracket:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Expanded(
            child: ListView.builder(
              itemCount: tournament.totalRounds,
              itemBuilder: (context, roundIndex) {
                final round = roundIndex + 1;
                final roundMatches = tournament.matches.values
                  .where((m) => m.round == round)
                  .toList()
                  ..sort((a, b) => a.position.compareTo(b.position));
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tournament.getRoundName(round),
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...roundMatches.map((match) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMatchCard(tournament, match, isMyMatch: false, compact: true),
                    )),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          
          // Botón salir
          _buildButton('Salir del campeonato', Icons.exit_to_app, _leaveTournament, destructive: true),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Tournament tournament, TournamentMatch match, {required bool isMyMatch, bool compact = false}) {
    final p1 = match.player1Id != null ? tournament.players[match.player1Id] : null;
    final p2 = match.player2Id != null ? tournament.players[match.player2Id] : null;
    final isMyTurn = match.player1Id == _tournamentService.playerId || match.player2Id == _tournamentService.playerId;
    
    final rivalId = match.player1Id == _tournamentService.playerId ? match.player2Id : match.player1Id;
    final rival = rivalId != null ? tournament.players[rivalId] : null;
    
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 16),
      decoration: BoxDecoration(
        color: isMyTurn && !match.finished ? Colors.blue.withAlpha(30) : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.finished ? (match.winnerId == _tournamentService.playerId ? Colors.green : Colors.white24) : 
                 isMyTurn ? Colors.blue : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMyMatch && !match.finished) ...[
            if (rival != null)
              Text('Tu rival: ${rival.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            else
              const Text('Esperando rival...', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            if (match.isReady)
              _buildButton(
                '¡JUGAR!',
                Icons.play_arrow,
                () => _goToMatch(match),
                primary: true,
              ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    p1?.name ?? '???',
                    style: TextStyle(
                      color: match.winnerId == p1?.id ? Colors.green : Colors.white,
                      fontWeight: match.winnerId == p1?.id ? FontWeight.bold : FontWeight.normal,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                ),
                if (match.finished)
                  Text(
                    '${match.player1Score ?? 0}',
                    style: TextStyle(color: Colors.white70, fontSize: compact ? 12 : 14),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p2?.name ?? '???',
                    style: TextStyle(
                      color: match.winnerId == p2?.id ? Colors.green : Colors.white,
                      fontWeight: match.winnerId == p2?.id ? FontWeight.bold : FontWeight.normal,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                ),
                if (match.finished)
                  Text(
                    '${match.player2Score ?? 0}',
                    style: TextStyle(color: Colors.white70, fontSize: compact ? 12 : 14),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _goToMatch(TournamentMatch match) {
    if (match.roomCode == null) return;
    
    Navigator.of(context).pushNamed(
      '/tournament-match',
      arguments: {
        'roomCode': match.roomCode,
        'matchId': match.id,
        'tournamentCode': _tournamentService.currentTournament?.code,
        'tournamentService': _tournamentService,
      },
    );
  }

  String _getSizeDescription(int size) {
    if (size == 4) return 'Semifinales + Final';
    if (size == 8) return 'Cuartos + Semifinales + Final';
    return 'Octavos + Cuartos + Semifinales + Final';
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onPressed, {bool isLoading = false, bool primary = false, bool destructive = false, bool compact = false}) {
    final color = destructive ? Colors.red : primary ? Colors.amber : Colors.white24;
    
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: compact ? 48 : 56,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
        decoration: BoxDecoration(
          color: color.withAlpha(primary || destructive ? 255 : 50),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
            else
              Icon(icon, color: primary || destructive ? Colors.black87 : Colors.white70),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: primary || destructive ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  final int size;
  final bool selected;
  final VoidCallback onTap;
  
  const _SizeButton({required this.size, required this.selected, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? Colors.amber : Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.amber : Colors.white24),
          ),
          child: Column(
            children: [
              Text(
                '$size',
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'jugadores',
                style: TextStyle(
                  color: selected ? Colors.black54 : Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
