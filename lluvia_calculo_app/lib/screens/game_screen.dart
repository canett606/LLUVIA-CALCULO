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
/// Layout diseñado para móvil en retrato:
/// - HUD compacto arriba
/// - Área de juego en el centro (siempre visible)
/// - Teclado numérico fijo abajo (siempre visible)
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    // Ocultar overlays del sistema para maximizar espacio
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

    return Scaffold(
      resizeToAvoidBottomInset: false, // CRÍTICO: No redimensionar por teclado del sistema
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
        child: Column(
          children: [
            // HUD superior compacto
            GameHud(
              state: state,
              profile: profile,
              onPause: state.isRunning ? provider.togglePause : null,
              onSettings: () => _showSettingsSheet(context),
            ),
            
            // Área de juego (expandible)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildGameArea(context, state, provider),
              ),
            ),
            
            // Teclado numérico fijo
            NumericKeypad(
              currentValue: provider.inputBuffer,
              enabled: state.isRunning && !state.isPaused,
              onDigit: provider.appendDigit,
              onBackspace: provider.backspace,
              onClear: provider.clearInput,
              onSubmit: provider.submitAnswer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea(BuildContext context, GameState state, GameProvider provider) {
    // Estado: No iniciado
    if (!state.isRunning && !state.isGameOver) {
      return _StartScreen(
        mode: state.mode,
        family: state.selectedFamily,
        onModeChanged: provider.setMode,
        onFamilyChanged: provider.setFamily,
        onStart: provider.startGame,
      );
    }
    
    // Estado: Pausado
    if (state.isPaused) {
      return Stack(
        children: [
          GamePlayfield(
            drops: state.activeDrops,
            message: null,
          ),
          _PauseOverlay(
            onResume: provider.togglePause,
            onQuit: provider.resetGame,
          ),
        ],
      );
    }
    
    // Estado: Game Over
    if (state.isGameOver) {
      return _GameOverScreen(
        state: state,
        profile: provider.currentProfile,
        onRestart: provider.resetGame,
        onChangeMode: () {
          provider.resetGame();
        },
      );
    }
    
    // Estado: Jugando
    return GamePlayfield(
      drops: state.activeDrops,
      message: state.lastMessage,
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
              Text(
                'Configuración',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Toggle sonido
              SwitchListTile(
                title: const Text('Sonido'),
                subtitle: const Text('Efectos de acierto/fallo'),
                value: provider.soundEnabled,
                onChanged: (_) => provider.toggleSound(),
              ),
              
              const Divider(),
              
              // Reiniciar partida
              if (provider.state.isRunning)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reiniciar partida'),
                  onTap: () {
                    Navigator.pop(context);
                    provider.resetGame();
                  },
                ),
              
              // Cambiar jugador
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Cambiar jugador'),
                subtitle: Text(provider.currentProfile?.name ?? 'Sin jugador'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushReplacementNamed('/welcome');
                },
              ),
              
              // Ver ranking
              ListTile(
                leading: const Icon(Icons.leaderboard),
                title: const Text('Ranking local'),
                onTap: () {
                  Navigator.pop(context);
                  _showRankingSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRankingSheet(BuildContext context) async {
    final provider = context.read<GameProvider>();
    final ranking = await provider.getLocalRanking();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '🏆 Ranking Local',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ranking.isEmpty
                  ? const Center(
                      child: Text('Aún no hay partidas registradas'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: ranking.length,
                      itemBuilder: (context, index) {
                        final entry = ranking[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: index == 0
                              ? Colors.amber
                              : index == 1
                                ? Colors.grey[400]
                                : index == 2
                                  ? Colors.brown[300]
                                  : null,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(entry.playerName),
                          subtitle: Text(
                            '${entry.mode} · ${(entry.accuracy * 100).toStringAsFixed(0)}% precisión',
                          ),
                          trailing: Text(
                            '${entry.score}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de inicio antes de jugar
class _StartScreen extends StatelessWidget {
  final GameMode mode;
  final OperationFamily family;
  final void Function(GameMode) onModeChanged;
  final void Function(OperationFamily) onFamilyChanged;
  final VoidCallback onStart;

  const _StartScreen({
    required this.mode,
    required this.family,
    required this.onModeChanged,
    required this.onFamilyChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🌧️ Lluvia de Cálculo',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Selector de modo
          _buildDropdown<GameMode>(
            context,
            label: 'Modo de juego',
            value: mode,
            items: GameMode.values,
            labelBuilder: _getModeLabel,
            onChanged: onModeChanged,
          ),
          const SizedBox(height: 16),
          
          // Selector de familia
          _buildDropdown<OperationFamily>(
            context,
            label: 'Tipo de operaciones',
            value: family,
            items: OperationFamily.values,
            labelBuilder: _getFamilyLabel,
            onChanged: onFamilyChanged,
          ),
          const SizedBox(height: 32),
          
          // Botón de inicio
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text(
                'INICIAR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Descripción del modo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getModeDescription(mode),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(labelBuilder(item)),
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
      case GameMode.aprendizaje:
        return '📚 Aprendizaje';
      case GameMode.porTiempo:
        return '⏱️ Contrarreloj';
      case GameMode.porPuntuacion:
        return '🎯 Por puntuación';
      case GameMode.supervivencia:
        return '💀 Supervivencia';
      case GameMode.porNiveles:
        return '📈 Por niveles';
    }
  }

  String _getFamilyLabel(OperationFamily family) {
    switch (family) {
      case OperationFamily.todas:
        return '🔢 Todas';
      case OperationFamily.sumas:
        return '➕ Sumas';
      case OperationFamily.restas:
        return '➖ Restas';
      case OperationFamily.multiplicaciones:
        return '✖️ Multiplicaciones';
      case OperationFamily.divisiones:
        return '➗ Divisiones';
      case OperationFamily.mixtas:
        return '🔀 Mixtas';
    }
  }

  String _getModeDescription(GameMode mode) {
    switch (mode) {
      case GameMode.aprendizaje:
        return 'Empieza con operaciones fáciles y sube gradualmente según tu rendimiento. Ideal para principiantes.';
      case GameMode.porTiempo:
        return 'Resuelve tantas operaciones como puedas en 90 segundos. ¡Velocidad y precisión!';
      case GameMode.porPuntuacion:
        return 'Alcanza 500 puntos lo más rápido posible. Sin límite de vidas.';
      case GameMode.supervivencia:
        return 'Sobrevive con 5 vidas mientras la dificultad aumenta progresivamente.';
      case GameMode.porNiveles:
        return 'Desbloquea niveles de dificultad demostrando tu maestría en cada uno.';
    }
  }
}

/// Overlay de pausa
class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const _PauseOverlay({
    required this.onResume,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle, size: 64),
              const SizedBox(height: 16),
              Text(
                'Juego en Pausa',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onQuit,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Salir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de Game Over
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
    final isVictory = state.mode == GameMode.porTiempo || 
                      state.mode == GameMode.porPuntuacion;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVictory ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 64,
            color: isVictory ? Colors.amber : theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            isVictory ? '¡Victoria!' : 'Fin del Juego',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Estadísticas finales
          _StatRow(label: 'Puntuación', value: '${state.score}'),
          _StatRow(
            label: 'Precisión', 
            value: '${(state.sessionAccuracy * 100).toStringAsFixed(1)}%',
          ),
          _StatRow(label: 'Aciertos', value: '${state.correctThisSession}'),
          _StatRow(label: 'Nivel alcanzado', value: '${state.level}'),
          if (profile != null)
            _StatRow(
              label: 'Mejor puntuación', 
              value: '${profile!.bestScore}',
              highlight: state.score >= profile!.bestScore,
            ),
          
          const SizedBox(height: 32),
          
          // Botones
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.replay),
              label: const Text('Jugar de nuevo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChangeMode,
              icon: const Icon(Icons.settings),
              label: const Text('Cambiar modo'),
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

  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.amber : null,
            ),
          ),
        ],
      ),
    );
  }
}
