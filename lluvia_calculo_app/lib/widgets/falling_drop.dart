import 'package:flutter/material.dart';
import '../models/game_state.dart';

/// Widget que representa una gota cayendo con una operación matemática.
class FallingDropWidget extends StatelessWidget {
  final FallingDrop drop;
  final double areaHeight;
  final double areaWidth;

  const FallingDropWidget({
    super.key,
    required this.drop,
    required this.areaHeight,
    required this.areaWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Calcular posición en pixels
    final x = drop.x * areaWidth;
    final y = drop.y * areaHeight;
    
    // Determinar color basado en urgencia (qué tan cerca del suelo)
    final urgency = drop.y;
    Color baseColor;
    if (urgency > 0.8) {
      baseColor = theme.colorScheme.error;
    } else if (urgency > 0.6) {
      baseColor = theme.colorScheme.tertiary;
    } else {
      baseColor = theme.colorScheme.primary;
    }
    
    return Positioned(
      left: x - 44, // Centrar el widget
      top: y,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 88,
          maxWidth: 120,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              baseColor.withOpacity(0.95),
              baseColor.withOpacity(0.8),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(22),
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          drop.operation.expression,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Widget que muestra el área de juego con las gotas cayendo.
class GamePlayfield extends StatelessWidget {
  final List<FallingDrop> drops;
  final String? message;

  const GamePlayfield({
    super.key,
    required this.drops,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F2A39),
                const Color(0xFF07131D),
              ],
              stops: const [0.0, 0.7],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Fondo con efecto de bosque/niebla
                _buildBackground(),
                
                // Línea del suelo
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF194423).withOpacity(0.3),
                          const Color(0xFF123119).withOpacity(0.9),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFA4FFC3).withOpacity(0.15),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Gotas cayendo
                ...drops.map((drop) => FallingDropWidget(
                  drop: drop,
                  areaHeight: height - 60, // Restar altura del suelo
                  areaWidth: width,
                )),
                
                // Mensaje de feedback
                if (message != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Efecto de luz superior
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.5,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Puntos de luz decorativos
        Positioned(
          top: 40,
          left: 30,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: 50,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.4),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
