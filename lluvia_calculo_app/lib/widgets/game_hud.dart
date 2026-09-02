import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player_profile.dart';

/// HUD compacto que muestra estadísticas del juego.
/// Diseñado para ocupar poco espacio vertical en móvil.
class GameHud extends StatelessWidget {
  final GameState state;
  final PlayerProfile? profile;
  final VoidCallback? onPause;
  final VoidCallback? onSettings;

  const GameHud({
    super.key,
    required this.state,
    this.profile,
    this.onPause,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila superior: Jugador + controles
            Row(
              children: [
                // Nombre del jugador
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          profile?.name ?? 'Jugador',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Modo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getModeLabel(state.mode),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Botones de control
                if (state.isRunning) ...[
                  IconButton(
                    onPressed: onPause,
                    icon: Icon(
                      state.isPaused ? Icons.play_arrow : Icons.pause,
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
                IconButton(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings),
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Fila de estadísticas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBox(
                  icon: Icons.star,
                  label: 'Puntos',
                  value: state.score.toString(),
                  color: theme.colorScheme.primary,
                ),
                _StatBox(
                  icon: Icons.favorite,
                  label: 'Vidas',
                  value: state.lives > 99 ? '∞' : state.lives.toString(),
                  color: state.lives <= 2 
                    ? theme.colorScheme.error 
                    : theme.colorScheme.error.withOpacity(0.7),
                ),
                _StatBox(
                  icon: Icons.local_fire_department,
                  label: 'Racha',
                  value: state.streak.toString(),
                  color: state.streak >= 5 
                    ? Colors.orange 
                    : theme.colorScheme.tertiary,
                ),
                _StatBox(
                  icon: Icons.trending_up,
                  label: 'Nivel',
                  value: state.level.toString(),
                  color: theme.colorScheme.secondary,
                ),
                if (profile != null)
                  _StatBox(
                    icon: Icons.emoji_events,
                    label: 'Récord',
                    value: profile!.bestScore.toString(),
                    color: Colors.amber,
                  ),
              ],
            ),
            
            // Tiempo restante (si aplica)
            if (state.mode == GameMode.porTiempo && state.timeRemaining != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TimeBar(
                  remaining: state.timeRemaining!,
                  total: const Duration(seconds: 90),
                ),
              ),
            
            // Objetivo de puntuación (si aplica)
            if (state.mode == GameMode.porPuntuacion && state.targetScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ProgressBar(
                  current: state.score,
                  target: state.targetScore!,
                  label: 'Objetivo',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getModeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.aprendizaje:
        return 'Aprendizaje';
      case GameMode.porTiempo:
        return 'Contrarreloj';
      case GameMode.porPuntuacion:
        return 'Por puntos';
      case GameMode.supervivencia:
        return 'Supervivencia';
      case GameMode.porNiveles:
        return 'Por niveles';
    }
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBar extends StatelessWidget {
  final Duration remaining;
  final Duration total;

  const _TimeBar({
    required this.remaining,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = remaining.inSeconds / total.inSeconds;
    final isLow = remaining.inSeconds <= 10;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tiempo',
              style: theme.textTheme.labelSmall,
            ),
            Text(
              _formatDuration(remaining),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isLow ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              isLow ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int target;
  final String label;

  const _ProgressBar({
    required this.current,
    required this.target,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = current / target;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall,
            ),
            Text(
              '$current / $target',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
