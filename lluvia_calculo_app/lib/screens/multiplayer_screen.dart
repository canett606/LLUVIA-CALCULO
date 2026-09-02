import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/multiplayer_service.dart';

/// Pantalla de lobby multijugador 1v1
/// Va DIRECTO a crear/unirse, sin pantalla de "conectar"
class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({super.key});

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final _codeController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;
  String? _errorMessage;
  
  StreamSubscription<MultiplayerConnectionState>? _stateSubscription;
  StreamSubscription<MultiplayerEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    final mp = context.read<GameProvider>().multiplayer;
    
    _stateSubscription = mp.connectionStateStream.listen((state) {
      if (mounted) setState(() {});
      
      if (state == MultiplayerConnectionState.playing) {
        Navigator.of(context).pushReplacementNamed('/multiplayer-game');
      }
    });
    
    _eventSubscription = mp.eventStream.listen((event) {
      if (event.type == 'error' && mounted) {
        setState(() {
          _errorMessage = event.data['message'] as String?;
        });
      } else if (event.type == 'player_joined' && mounted) {
        setState(() {});
      } else if (event.type == 'room_closed' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La sala fue cerrada')),
        );
      }
    });
  }

  Future<void> _createRoom() async {
    final provider = context.read<GameProvider>();
    final mp = provider.multiplayer;
    
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });
    
    final room = await mp.createRoom();
    
    if (mounted) {
      setState(() => _isCreating = false);
      if (room == null) {
        setState(() => _errorMessage = mp.errorMessage ?? 'No se pudo crear la sala. Verifica tu conexión.');
      }
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Introduce el código de la sala');
      return;
    }
    
    final mp = context.read<GameProvider>().multiplayer;
    
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });
    
    final room = await mp.joinRoom(code);
    
    if (mounted) {
      setState(() => _isJoining = false);
      if (room == null) {
        setState(() => _errorMessage = mp.errorMessage ?? 'No se pudo unir a la sala. Verifica el código.');
      }
    }
  }

  Future<void> _setReady() async {
    final mp = context.read<GameProvider>().multiplayer;
    final currentPlayer = mp.currentRoom?.players[mp.playerId];
    await mp.setReady(!(currentPlayer?.isReady ?? false));
    if (mounted) setState(() {});
  }

  Future<void> _startGame() async {
    final mp = context.read<GameProvider>().multiplayer;
    await mp.startGame();
  }

  Future<void> _leaveRoom() async {
    final mp = context.read<GameProvider>().multiplayer;
    await mp.leaveRoom();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<GameProvider>().multiplayer;
    final room = mp.currentRoom;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('1 vs 1'),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: room != null 
              ? _buildRoomView(room, mp)
              : _buildLobbyView(),
          ),
        ),
      ),
    );
  }

  /// Lobby: crear o unirse - SIN pantalla de wifi
  Widget _buildLobbyView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.sports_esports, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            '1 vs 1 Online',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '90 segundos · Mismas operaciones',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Crear sala
          _buildButton(
            'Crear Sala',
            Icons.add_circle,
            _createRoom,
            isLoading: _isCreating,
            primary: true,
          ),
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
          
          // Unirse con código
          const Text(
            'Unirse con código:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Código de sala',
                    hintStyle: TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withAlpha(20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildButton(
                'Unirse',
                Icons.login,
                _joinRoom,
                isLoading: _isJoining,
                compact: true,
              ),
            ],
          ),
          
          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[300], size: 18),
                    const SizedBox(width: 8),
                    Text('Cómo funciona:', style: TextStyle(color: Colors.blue[300], fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Uno crea sala y comparte el código\n'
                  '2. El otro introduce el código y se une\n'
                  '3. Ambos pulsan "Listo"\n'
                  '4. El host inicia la partida',
                  style: TextStyle(color: Colors.blue[200], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomView(GameRoom room, MultiplayerService mp) {
    final isHost = mp.role == RoomRole.host;
    final myPlayer = room.players[mp.playerId];
    final opponent = mp.opponent;
    final canStart = isHost && room.allReady && room.players.length >= 2;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Código de sala
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('Código de sala:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    room.code,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.amber),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: room.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
              const Text(
                'Comparte este código con tu rival',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Jugadores
        const Text('Jugadores:', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        
        // Yo
        _PlayerCard(player: myPlayer, isMe: true, isHost: isHost),
        const SizedBox(height: 8),
        
        // Oponente o esperando
        if (opponent != null)
          _PlayerCard(player: opponent, isMe: false, isHost: room.hostId == opponent.id)
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ),
                const SizedBox(width: 12),
                const Text('Esperando rival...', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        
        const Spacer(),
        
        // Error
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 12),
        ],
        
        // Acciones
        if (opponent != null) ...[
          _buildButton(
            myPlayer?.isReady == true ? 'Cancelar' : '¡Estoy Listo!',
            myPlayer?.isReady == true ? Icons.close : Icons.check_circle,
            _setReady,
            primary: myPlayer?.isReady != true,
          ),
          if (canStart) ...[
            const SizedBox(height: 12),
            _buildButton('¡EMPEZAR!', Icons.play_arrow, _startGame, primary: true),
          ],
        ],
        const SizedBox(height: 12),
        _buildButton('Salir', Icons.exit_to_app, _leaveRoom, destructive: true),
      ],
    );
  }

  Widget _buildButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool isLoading = false,
    bool primary = false,
    bool destructive = false,
    bool compact = false,
  }) {
    final color = destructive 
      ? Colors.red 
      : primary 
        ? Colors.amber 
        : Colors.white24;
    
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
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
              )
            else
              Icon(icon, color: primary || destructive ? Colors.black87 : Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: primary || destructive ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final RoomPlayer? player;
  final bool isMe;
  final bool isHost;

  const _PlayerCard({required this.player, required this.isMe, required this.isHost});

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.withAlpha(30) : Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: player!.isReady ? Colors.green : Colors.white24,
          width: player!.isReady ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(isHost ? Icons.star : Icons.person, color: isHost ? Colors.amber : Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player!.name}${isMe ? ' (Tú)' : ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(isHost ? 'Anfitrión' : 'Invitado', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (player!.isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
              child: const Text('LISTO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
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
