import 'package:flutter/material.dart';

/// Teclado numérico personalizado para el juego.
/// Diseñado para ser visible siempre junto al área de juego,
/// sin invocar el teclado del sistema.
class NumericKeypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final String currentValue;
  final bool enabled;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
    this.currentValue = '',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display del valor actual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Text(
                currentValue.isEmpty ? '—' : currentValue,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                  color: currentValue.isEmpty 
                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                    : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Teclado numérico
            _buildKeypadGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadGrid(BuildContext context) {
    return Column(
      children: [
        // Fila 1: 1, 2, 3
        _buildRow(context, ['1', '2', '3']),
        const SizedBox(height: 8),
        // Fila 2: 4, 5, 6
        _buildRow(context, ['4', '5', '6']),
        const SizedBox(height: 8),
        // Fila 3: 7, 8, 9
        _buildRow(context, ['7', '8', '9']),
        const SizedBox(height: 8),
        // Fila 4: Borrar, 0, OK
        _buildBottomRow(context),
        const SizedBox(height: 8),
        // Fila 5: Limpiar todo (ancho completo)
        _buildClearButton(context),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> digits) {
    return Row(
      children: digits.map((digit) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _DigitButton(
              digit: digit,
              onTap: enabled ? () => onDigit(digit) : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // Backspace
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ActionButton(
              icon: Icons.backspace_outlined,
              label: '⌫',
              onTap: enabled ? onBackspace : null,
              color: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
        // 0
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _DigitButton(
              digit: '0',
              onTap: enabled ? () => onDigit('0') : null,
            ),
          ),
        ),
        // OK / Submit
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ActionButton(
              label: 'OK',
              onTap: enabled && currentValue.isNotEmpty ? onSubmit : null,
              color: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              isSubmit: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClearButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: enabled && currentValue.isNotEmpty ? onClear : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'BORRAR TODO',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitButton extends StatelessWidget {
  final String digit;
  final VoidCallback? onTap;

  const _DigitButton({
    required this.digit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color foregroundColor;
  final bool isSubmit;

  const _ActionButton({
    this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.foregroundColor,
    this.isSubmit = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          elevation: isSubmit ? 4 : 2,
          shadowColor: isSubmit ? color.withOpacity(0.5) : Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: icon != null
          ? Icon(icon, size: 28)
          : Text(
              label,
              style: TextStyle(
                fontSize: isSubmit ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }
}
