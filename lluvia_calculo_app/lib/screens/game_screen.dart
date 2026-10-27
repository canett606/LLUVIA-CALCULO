import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/physical_keyboard.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart';
import '../models/operation.dart';
import '../models/player_profile.dart';
import '../widgets/falling_drop.dart';
import '../widgets/numeric_keypad.dart';
import 'local_duel_screen.dart';

/// En iPhone Safari el Focus/autofocus de Flutter crea un <input> oculto
/// que se come los toques del botón INICIAR. Solo usamos teclado físico en desktop.
bool get _usePhysicalKeyboard {
  // En iOS/Android (app o Safari) el Focus de Flutter Web crea un input
  // oculto que intercepta el botón INICIAR. Solo escritorio.
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

/// Pantalla principal del juego.
/// KEYPAD SOLO APARECE cuando state.isRunning && !state.isPaused && !state.isGameOver
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FocusNode _focus = FocusNode();
  bool _duelActive = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    // No pedir foco en iPhone: el input oculto de Flutter Web bloquea INICIAR
    if (_usePhysicalKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _startFromMenu() {
    final provider = context.read<GameProvider>();
    if (provider.state.mode == GameMode.dueloLocal) {
      setState(() => _duelActive = true);
      return;
    }
    provider.startGame();
    if (_usePhysicalKeyboard && mounted) {
      _focus.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final action = PhysicalKeyAction.fromKey(event.logicalKey);
    if (action == null) return KeyEventResult.ignored;

    final provider = context.read<GameProvider>();
    final state = provider.state;
    final inMenu = !state.isRunning || state.isGameOver;

    if (inMenu) {
      if (action.submit) {
        _startFromMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (action.quit) {
      provider.resetGame();
      return KeyEventResult.handled;
    }
    if (action.pause) {
      provider.togglePause();
      return KeyEventResult.handled;
    }
    if (state.isPaused) return KeyEventResult.ignored;
    if (action.backspace) {
      provider.backspace();
      return KeyEventResult.handled;
    }
    if (action.submit) {
      provider.submitAnswer();
      return KeyEventResult.handled;
    }
    if (action.digit != null) {
      provider.appendDigit(action.digit!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_duelActive) {
      final family = context.read<GameProvider>().state.selectedFamily;
      return LocalDuelScreen(
        family: family,
        onExit: () {
          if (!mounted) return;
          setState(() => _duelActive = false);
          _focus.requestFocus();
        },
      );
    }

    final provider = context.watch<GameProvider>();
    final state = provider.state;
    final profile = provider.currentProfile;

    // Keypad solo durante la partida activa. En infinito (pizarra) no hay teclado.
    final bool inMatch = state.isRunning && !state.isPaused && !state.isGameOver;
    final maxWidth = state.mode == GameMode.infinito && state.isRunning ? 1100.0 : 560.0;

    Widget body = Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C2431), Color(0xFF07131D)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SafeArea(
              bottom: false,
              child: inMatch
                  ? _ActiveGameLayout(provider: provider, state: state, profile: profile)
                  : _MenuLayout(
                      provider: provider,
                      state: state,
                      profile: profile,
                      onStart: _startFromMenu,
                    ),
            ),
          ),
        ),
      ),
    );

    // Teclado físico solo en escritorio. En iPhone Safari el Focus crea un
    // <input> oculto que intercepta el toque de INICIAR.
    if (!_usePhysicalKeyboard) return body;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!_focus.hasFocus) _focus.requestFocus();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: body,
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
        final infinite = state.mode == GameMode.infinito;
        final keypadMaxHeight = (totalHeight * 0.38).clamp(160.0, 280.0);
        
        return Column(
          children: [
            SizedBox(
              height: hudHeight,
              child: _CompactHud(state: state, onPause: provider.togglePause),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: GamePlayfield(
                  drops: state.activeDrops,
                  message: state.lastMessage,
                  enlarged: infinite,
                ),
              ),
            ),
            if (infinite)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BigButton(
                          label: 'Pausa',
                          icon: Icons.pause,
                          color: const Color(0xFF62D6FF),
                          onTap: provider.togglePause,
                          height: 52,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BigButton(
                          label: 'Salir',
                          icon: Icons.close,
                          color: const Color(0xFFE57373),
                          onTap: provider.resetGame,
                          height: 52,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
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
  final VoidCallback onStart;

  const _MenuLayout({
    required this.provider,
    required this.state,
    required this.profile,
    required this.onStart,
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
    
    // Inicio: selectores con scroll, INICIAR fijo abajo (Safari se come el tap dentro del scroll).
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _StartScreen(
              mode: state.mode,
              family: state.selectedFamily,
              profile: profile,
              onModeChanged: provider.setMode,
              onFamilyChanged: provider.setFamily,
              onSettings: () => _showSettingsSheet(context, provider),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              _BigButton(
                label: 'INICIAR',
                icon: Icons.play_arrow,
                color: const Color(0xFF62D6FF),
                onTap: onStart,
                height: 56,
              ),
              const SizedBox(height: 8),
              _BigButton(
                label: '1 vs 1 Online',
                icon: Icons.people,
                color: const Color(0xFFFFB74D),
                onTap: () => Navigator.of(context).pushNamed('/multiplayer'),
                height: 48,
              ),
            ],
          ),
        ),
      ],
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
          _Stat(
            icon: Icons.favorite,
            value: state.mode == GameMode.infinito ? '∞' : '${state.lives}',
            color: Colors.pink,
          ),
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
  final VoidCallback onSettings;

  const _StartScreen({
    required this.mode,
    required this.family,
    required this.profile,
    required this.onModeChanged,
    required this.onFamilyChanged,
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
              Text('Modo de juego', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GameMode.values.map((m) => _ChoiceChip(
                  label: _getModeLabel(m),
                  selected: mode == m,
                  onTap: () => onModeChanged(m),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Text('Tipo de operaciones', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OperationFamily.values.map((f) => _ChoiceChip(
                  label: _getFamilyLabel(f),
                  selected: family == f,
                  onTap: () => onFamilyChanged(f),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Text(_getModeDescription(mode),
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Ordenador: números, signo menos y retroceso. Espacio pausa. Esc salir.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
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
      case GameMode.infinito: return '♾️ Infinito';
      case GameMode.dueloLocal: return '👥 Misma pantalla';
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
      case GameMode.infinito: return 'No para. Decid el resultado en voz alta. Pausa y Salir.';
      case GameMode.dueloLocal: return 'Dos teclados. A: numérico. B: teclas 1-0. 90 segundos.';
    }
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF62D6FF) : Colors.grey[800],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black87 : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double height;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    // ElevatedButton + onPointerUp: fiable en iPhone Safari
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) => onTap(),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 26, color: Colors.black87),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black87,
            elevation: 3,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
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
          width: 320,
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
              _BigButton(
                label: 'Continuar',
                icon: Icons.play_arrow,
                color: const Color(0xFF62D6FF),
                onTap: onResume,
              ),
              const SizedBox(height: 8),
              _BigButton(
                label: 'Salir',
                icon: Icons.close,
                color: const Color(0xFFE57373),
                onTap: onQuit,
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
          
          _BigButton(
            label: 'Jugar de nuevo',
            icon: Icons.replay,
            color: theme.colorScheme.primary,
            onTap: onRestart,
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
