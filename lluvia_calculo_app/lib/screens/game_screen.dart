import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../models/game_state.dart';
import '../models/operation.dart';
import '../models/player_profile.dart';
import '../widgets/falling_drop.dart';
import '../widgets/numeric_keypad.dart';

/// Pantalla principal del juego.
/// KEYPAD SOLO APARECE cuando state.isRunning && !state.isPaused && !state.isGameOver
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state;
    final profile = provider.currentProfile;
    
    // CONDICIÓN CLAVE: keypad SOLO si está jugando activamente
    final bool showKeypad = state.isRunning && !state.isPaused && !state.isGameOver;

    return Scaffold(
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
          child: showKeypad
            ? _ActiveGameLayout(provider: provider, state: state, profile: profile)
            : _MenuLayout(provider: provider, state: state, profile: profile),
        ),
      ),
    );
  }
}

/// Layout DURANTE el juego: HUD + Playfield + Keypad compacto
class _ActiveGameLayout extends StatelessWidget {
  final GameProvider provider;
  final GameState state;
  final PlayerProfile? profile;

  const _ActiveGameLayout({
    required this.provider,
    required this.state,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        const hudHeight = 48.0;
        final keypadMaxHeight = (totalHeight * 0.38).clamp(160.0, 280.0);
        
        return Column(
          children: [
            // HUD compacto
            SizedBox(
              height: hudHeight,
              child: _CompactHud(state: state, onPause: provider.togglePause),
            ),
            // Área de gotas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: GamePlayfield(drops: state.activeDrops, message: state.lastMessage),
              ),
            ),
            // Keypad compacto con safe area
            SafeArea(
              top: false,
              child: SizedBox(
                height: keypadMaxHeight,
                child: CompactNumericKeypad(
                  currentValue: provider.inputBuffer,
                  onDigit: provider.appendDigit,
                  onBackspace: provider.backspace,
                  onClear: provider.clearInput,
                  onSubmit: provider.submitAnswer,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Layout para MENÚ (inicio y game over): pantalla completa SIN keypad
class _MenuLayout extends StatelessWidget {
  final GameProvider provider;
  final GameState state;
  final PlayerProfile? profile;

  const _MenuLayout({
    required this.provider,
    required this.state,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    // Pausado: mostrar overlay sobre el playfield
    if (state.isPaused) {
      return Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 48, child: _CompactHud(state: state, onPause: provider.togglePause)),
              Expanded(child: GamePlayfield(drops: state.activeDrops, message: null)),
            ],
          ),
          _PauseOverlay(onResume: provider.togglePause, onQuit: provider.resetGame),
        ],
      );
    }
    
    // Game Over
    if (state.isGameOver) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _GameOverScreen(
            state: state,
            profile: profile,
            onRestart: provider.resetGame,
          ),
        ),
      );
    }
    
    // Inicio (no running, no game over)
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _StartScreen(
          mode: state.mode,
          family: state.selectedFamily,
          profile: profile,
          onModeChanged: provider.setMode,
          onFamilyChanged: provider.setFamily,
          onStart: provider.startGame,
          onSettings: () => _showSettingsSheet(context, provider),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, GameProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Sonido'),
                value: provider.soundEnabled,
                onChanged: (_) => provider.toggleSound(),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Cambiar jugador'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushReplacementNamed('/welcome');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HUD ultra compacto (48px)
class _CompactHud extends StatelessWidget {
  final GameState state;
  final VoidCallback onPause;

  const _CompactHud({required this.state, required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF0C2431),
      child: Row(
        children: [
          _Stat(icon: Icons.star, value: '${state.score}', color: Colors.amber),
          const SizedBox(width: 12),
          _Stat(icon: Icons.favorite, value: '${state.lives}', color: Colors.pink),
          const SizedBox(width: 12),
          _Stat(icon: Icons.local_fire_department, value: '${state.streak}', color: Colors.orange),
          const Spacer(),
          if (state.timeRemaining != null)
            Text('${state.timeRemaining!.inSeconds}s',
              style: TextStyle(
                color: state.timeRemaining!.inSeconds <= 10 ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPause,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(state.isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _Stat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Pantalla de inicio - SIN KEYPAD
class _StartScreen extends StatelessWidget {
  final GameMode mode;
  final OperationFamily family;
  final PlayerProfile? profile;
  final void Function(GameMode) onModeChanged;
  final void Function(OperationFamily) onFamilyChanged;
  final VoidCallback onStart;
  final VoidCallback onSettings;

  const _StartScreen({
    required this.mode,
    required this.family,
    required this.profile,
    required this.onModeChanged,
    required this.onFamilyChanged,
    required this.onStart,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text('👋 ${profile?.name ?? "Jugador"}',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSettings,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.settings, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Título
        Center(
          child: Text('🌧️ Lluvia de Cálculo',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        
        // Card principal
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(240),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector modo
              _Dropdown<GameMode>(
                label: 'Modo de juego',
                value: mode,
                items: GameMode.values,
                labelBuilder: _getModeLabel,
                onChanged: onModeChanged,
              ),
              const SizedBox(height: 16),
              
              // Selector familia
              _Dropdown<OperationFamily>(
                label: 'Tipo de operaciones',
                value: family,
                items: OperationFamily.values,
                labelBuilder: _getFamilyLabel,
                onChanged: onFamilyChanged,
              ),
              const SizedBox(height: 16),
              
              // Descripción
              Text(_getModeDescription(mode),
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // BOTÓN INICIAR - grande y visible
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onStart,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, size: 28, color: Colors.black87),
                      const SizedBox(width: 8),
                      Text('INICIAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // BOTÓN 1 VS 1
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pushNamed('/multiplayer'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, size: 22, color: Colors.black87),
                      const SizedBox(width: 8),
                      const Text('1 vs 1 Online',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Stats
              if (profile != null && profile!.bestScore > 0) ...[
                const SizedBox(height: 12),
                Text('Récord: ${profile!.bestScore} pts',
                  style: const TextStyle(color: Colors.amber),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getModeLabel(GameMode m) {
    switch (m) {
      case GameMode.aprendizaje: return '📚 Aprendizaje';
      case GameMode.porTiempo: return '⏱️ Contrarreloj';
      case GameMode.porPuntuacion: return '🎯 Por puntuación';
      case GameMode.supervivencia: return '💀 Supervivencia';
      case GameMode.porNiveles: return '📈 Por niveles';
    }
  }

  String _getFamilyLabel(OperationFamily f) {
    switch (f) {
      case OperationFamily.todas: return '🔢 Todas';
      case OperationFamily.sumas: return '➕ Sumas';
      case OperationFamily.restas: return '➖ Restas';
      case OperationFamily.multiplicaciones: return '✖️ Multiplicaciones';
      case OperationFamily.divisiones: return '➗ Divisiones';
      case OperationFamily.mixtas: return '🔀 Mixtas';
    }
  }

  String _getModeDescription(GameMode m) {
    switch (m) {
      case GameMode.aprendizaje: return 'Empieza fácil y sube gradualmente';
      case GameMode.porTiempo: return '90 segundos, máxima puntuación';
      case GameMode.porPuntuacion: return 'Alcanza 500 puntos';
      case GameMode.supervivencia: return '5 vidas, dificultad creciente';
      case GameMode.porNiveles: return 'Desbloquea niveles por maestría';
    }
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final void Function(T) onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.grey[800],
              items: items.map((i) => DropdownMenuItem(
                value: i,
                child: Text(labelBuilder(i), style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Overlay de pausa
class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const _PauseOverlay({required this.onResume, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle, size: 48),
              const SizedBox(height: 12),
              const Text('Pausado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(onPressed: onResume, child: const Text('Continuar')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: onQuit, child: const Text('Salir')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de Game Over - SIN KEYPAD
class _GameOverScreen extends StatelessWidget {
  final GameState state;
  final PlayerProfile? profile;
  final VoidCallback onRestart;

  const _GameOverScreen({
    required this.state,
    required this.profile,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(240),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
          const SizedBox(height: 12),
          Text('Fin del Juego',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          _StatRow('Puntuación', '${state.score}'),
          _StatRow('Precisión', '${(state.sessionAccuracy * 100).toStringAsFixed(0)}%'),
          _StatRow('Aciertos', '${state.correctThisSession}'),
          if (profile != null)
            _StatRow('Récord', '${profile!.bestScore}', state.score >= profile!.bestScore),
          
          const SizedBox(height: 24),
          
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRestart,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Jugar de nuevo',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatRow(this.label, this.value, [this.highlight = false]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.amber : Colors.white,
          )),
        ],
      ),
    );
  }
}
