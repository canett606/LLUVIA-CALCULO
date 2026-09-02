import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../models/game_state.dart';
import '../models/operation.dart';
import '../models/player_profile.dart';
import '../widgets/game_hud.dart';
import '../widgets/falling_drop.dart';
import '../widgets/numeric_keypad.dart';

/// Pantalla principal del juego.
/// Layout diseñado para iPhone portrait (390×844):
/// - ANTES de jugar: pantalla de inicio a pantalla completa, SIN teclado
/// - DURANTE la partida: HUD compacto + área de gotas + teclado compacto
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
    
    // Determinar si mostrar el layout de juego activo (con keypad)
    final bool isActiveGame = state.isRunning && !state.isGameOver;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C2431),
              Color(0xFF07131D),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: isActiveGame
            ? _buildActiveGameLayout(context, provider, state, profile)
            : _buildMenuLayout(context, provider, state, profile),
        ),
      ),
    );
  }

  /// Layout cuando el juego está activo: HUD + Playfield + Keypad
  Widget _buildActiveGameLayout(
    BuildContext context,
    GameProvider provider,
    GameState state,
    PlayerProfile? profile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        
        // Distribuir altura: HUD ~48px, Keypad ~38%, Playfield el resto
        const hudHeight = 48.0;
        final keypadHeight = (totalHeight * 0.38).clamp(180.0, 320.0);
        final playfieldHeight = totalHeight - hudHeight - keypadHeight;
        
        return Column(
          children: [
            // HUD compacto
            SizedBox(
              height: hudHeight,
              child: _CompactHud(
                state: state,
                profile: profile,
                onPause: provider.togglePause,
              ),
            ),
            
            // Área de juego
            SizedBox(
              height: playfieldHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: state.isPaused
                  ? Stack(
                      children: [
                        GamePlayfield(drops: state.activeDrops, message: null),
                        _PauseOverlay(
                          onResume: provider.togglePause,
                          onQuit: provider.resetGame,
                        ),
                      ],
                    )
                  : GamePlayfield(
                      drops: state.activeDrops,
                      message: state.lastMessage,
                    ),
              ),
            ),
            
            // Teclado numérico compacto
            SizedBox(
              height: keypadHeight,
              child: SafeArea(
                top: false,
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

  /// Layout para menú (inicio y game over): pantalla completa, SIN keypad
  Widget _buildMenuLayout(
    BuildContext context,
    GameProvider provider,
    GameState state,
    PlayerProfile? profile,
  ) {
    return SafeArea(
      child: state.isGameOver
        ? _GameOverScreen(
            state: state,
            profile: profile,
            onRestart: provider.resetGame,
            onChangeMode: provider.resetGame,
          )
        : _StartScreen(
            mode: state.mode,
            family: state.selectedFamily,
            profile: profile,
            onModeChanged: provider.setMode,
            onFamilyChanged: provider.setFamily,
            onStart: provider.startGame,
            onSettings: () => _showSettingsSheet(context),
          ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final provider = context.read<GameProvider>();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuración', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Sonido'),
                value: provider.soundEnabled,
                onChanged: (_) => provider.toggleSound(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Cambiar jugador'),
                subtitle: Text(provider.currentProfile?.name ?? ''),
                onTap: () {
                  Navigator.pop(context);
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

/// HUD ultra compacto para durante el juego
class _CompactHud extends StatelessWidget {
  final GameState state;
  final PlayerProfile? profile;
  final VoidCallback onPause;

  const _CompactHud({
    required this.state,
    required this.profile,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2431).withAlpha(230),
      ),
      child: Row(
        children: [
          // Score
          _MiniStat(icon: Icons.star, value: '${state.score}', color: Colors.amber),
          const SizedBox(width: 8),
          // Lives
          _MiniStat(
            icon: Icons.favorite,
            value: state.lives > 99 ? '∞' : '${state.lives}',
            color: state.lives <= 2 ? Colors.red : Colors.pink,
          ),
          const SizedBox(width: 8),
          // Streak
          _MiniStat(
            icon: Icons.local_fire_department,
            value: '${state.streak}',
            color: state.streak >= 5 ? Colors.orange : Colors.grey,
          ),
          const Spacer(),
          // Time remaining (if applicable)
          if (state.timeRemaining != null)
            Text(
              '${state.timeRemaining!.inSeconds}s',
              style: TextStyle(
                color: state.timeRemaining!.inSeconds <= 10 ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(width: 8),
          // Pause button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPause,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                state.isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniStat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

/// Pantalla de inicio - SIN teclado, a pantalla completa
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
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header con nombre y settings
          Row(
            children: [
              Expanded(
                child: Text(
                  '👋 ${profile?.name ?? "Jugador"}',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSettings,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.settings, color: Colors.white70),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Título
          Text(
            '🌧️ Lluvia de Cálculo',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Contenido principal
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(230),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Selector de modo
                  _buildDropdown<GameMode>(
                    context,
                    label: 'Modo de juego',
                    value: mode,
                    items: GameMode.values,
                    labelBuilder: _getModeLabel,
                    onChanged: onModeChanged,
                  ),
                  const SizedBox(height: 12),
                  
                  // Selector de familia
                  _buildDropdown<OperationFamily>(
                    context,
                    label: 'Tipo de operaciones',
                    value: family,
                    items: OperationFamily.values,
                    labelBuilder: _getFamilyLabel,
                    onChanged: onFamilyChanged,
                  ),
                  const SizedBox(height: 20),
                  
                  // Descripción breve
                  Text(
                    _getModeDescription(mode),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Botón INICIAR grande y prominente
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onStart,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow, size: 28, color: Colors.black87),
                              const SizedBox(width: 8),
                              Text(
                                'INICIAR',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Stats del jugador
                  if (profile != null && profile!.bestScore > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Récord: ${profile!.bestScore} pts · ${profile!.totalSessions} partidas',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T) onChanged,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(labelBuilder(item), style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ),
      ],
    );
  }

  String _getModeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.aprendizaje: return '📚 Aprendizaje';
      case GameMode.porTiempo: return '⏱️ Contrarreloj';
      case GameMode.porPuntuacion: return '🎯 Por puntuación';
      case GameMode.supervivencia: return '💀 Supervivencia';
      case GameMode.porNiveles: return '📈 Por niveles';
    }
  }

  String _getFamilyLabel(OperationFamily family) {
    switch (family) {
      case OperationFamily.todas: return '🔢 Todas';
      case OperationFamily.sumas: return '➕ Sumas';
      case OperationFamily.restas: return '➖ Restas';
      case OperationFamily.multiplicaciones: return '✖️ Multiplicaciones';
      case OperationFamily.divisiones: return '➗ Divisiones';
      case OperationFamily.mixtas: return '🔀 Mixtas';
    }
  }

  String _getModeDescription(GameMode mode) {
    switch (mode) {
      case GameMode.aprendizaje: return 'Empieza fácil y sube gradualmente';
      case GameMode.porTiempo: return '90 segundos, máxima puntuación';
      case GameMode.porPuntuacion: return 'Alcanza 500 puntos';
      case GameMode.supervivencia: return '5 vidas, dificultad creciente';
      case GameMode.porNiveles: return 'Desbloquea niveles por maestría';
    }
  }
}

/// Overlay de pausa
class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const _PauseOverlay({required this.onResume, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle, size: 48),
              const SizedBox(height: 12),
              Text('Pausado', style: theme.textTheme.titleLarge),
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

/// Pantalla de Game Over - SIN teclado
class _GameOverScreen extends StatelessWidget {
  final GameState state;
  final PlayerProfile? profile;
  final VoidCallback onRestart;
  final VoidCallback onChangeMode;

  const _GameOverScreen({
    required this.state,
    required this.profile,
    required this.onRestart,
    required this.onChangeMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(240),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.score >= (profile?.bestScore ?? 0) ? Icons.emoji_events : Icons.sports_score,
                size: 56,
                color: Colors.amber,
              ),
              const SizedBox(height: 12),
              Text(
                'Fin del Juego',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              _StatRow(label: 'Puntuación', value: '${state.score}'),
              _StatRow(label: 'Precisión', value: '${(state.sessionAccuracy * 100).toStringAsFixed(0)}%'),
              _StatRow(label: 'Aciertos', value: '${state.correctThisSession}'),
              if (profile != null)
                _StatRow(
                  label: 'Récord',
                  value: '${profile!.bestScore}',
                  highlight: state.score >= profile!.bestScore,
                ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay),
                  label: const Text('Jugar de nuevo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
