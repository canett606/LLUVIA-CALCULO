import 'package:flutter/material.dart';

/// Teclado numérico compacto para el juego.
/// Diseñado para iOS Safari con toques que funcionan.
/// Altura adaptativa usando LayoutBuilder.
class CompactNumericKeypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final String currentValue;

  const CompactNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
    this.currentValue = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;
        
        // Calcular tamaños adaptativos
        // Display: ~15% de altura
        // Keypad: 4 filas para números + 1 fila para acciones
        final displayHeight = (availableHeight * 0.15).clamp(32.0, 48.0);
        final keypadHeight = availableHeight - displayHeight - 8; // 8 for padding
        final rowHeight = (keypadHeight / 5).clamp(36.0, 56.0);
        final keyWidth = (availableWidth - 32) / 3; // 32 for padding and gaps
        
        return Container(
          color: const Color(0xFF0A151E),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Column(
            children: [
              // Display del valor actual
              Container(
                height: displayHeight,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  currentValue.isEmpty ? '—' : currentValue,
                  style: TextStyle(
                    fontSize: displayHeight * 0.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                    color: currentValue.isEmpty ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              
              // Teclado numérico
              Expanded(
                child: Column(
                  children: [
                    // Fila 1: 1, 2, 3
                    _buildRow(['1', '2', '3'], rowHeight, keyWidth),
                    // Fila 2: 4, 5, 6
                    _buildRow(['4', '5', '6'], rowHeight, keyWidth),
                    // Fila 3: 7, 8, 9
                    _buildRow(['7', '8', '9'], rowHeight, keyWidth),
                    // Fila 4: ⌫, 0, OK
                    _buildActionRow(rowHeight, keyWidth),
                    // Fila 5: Borrar todo (ancho completo)
                    _buildClearRow(rowHeight),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(List<String> digits, double height, double width) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: digits.map((digit) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _KeyButton(
            label: digit,
            height: height,
            width: width,
            onTap: () => onDigit(digit),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildActionRow(double height, double width) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _KeyButton(
              label: '⌫',
              height: height,
              width: width,
              onTap: onBackspace,
              color: const Color(0xFF5C1320),
              textColor: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _KeyButton(
              label: '0',
              height: height,
              width: width,
              onTap: () => onDigit('0'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _KeyButton(
              label: 'OK',
              height: height,
              width: width,
              onTap: onSubmit,
              color: const Color(0xFF0A5840),
              textColor: Colors.white,
              enabled: currentValue.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearRow(double height) {
    return _KeyButton(
      label: 'BORRAR',
      height: height * 0.7,
      width: double.infinity,
      onTap: onClear,
      color: const Color(0xFF3A2A10),
      textColor: Colors.amber,
      enabled: currentValue.isNotEmpty,
      isFullWidth: true,
    );
  }
}

/// Botón de tecla individual con manejo táctil para iOS Safari
class _KeyButton extends StatefulWidget {
  final String label;
  final double height;
  final double width;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final bool enabled;
  final bool isFullWidth;

  const _KeyButton({
    required this.label,
    required this.height,
    required this.width,
    required this.onTap,
    this.color,
    this.textColor,
    this.enabled = true,
    this.isFullWidth = false,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? const Color(0xFF2A3A4A);
    final effectiveTextColor = widget.textColor ?? Colors.white;
    final opacity = widget.enabled ? 1.0 : 0.4;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      } : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        height: widget.height,
        width: widget.isFullWidth ? double.infinity : widget.width,
        margin: widget.isFullWidth ? const EdgeInsets.symmetric(horizontal: 3) : null,
        decoration: BoxDecoration(
          color: _isPressed 
            ? effectiveColor.withAlpha(180)
            : effectiveColor.withAlpha((255 * opacity).round()),
          borderRadius: BorderRadius.circular(10),
          boxShadow: _isPressed ? null : [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.isFullWidth ? 14 : (widget.height * 0.4).clamp(14.0, 24.0),
            fontWeight: FontWeight.bold,
            color: effectiveTextColor.withAlpha((255 * opacity).round()),
          ),
        ),
      ),
    );
  }
}

// Keep the old NumericKeypad for backwards compatibility but redirect to compact
class NumericKeypad extends CompactNumericKeypad {
  const NumericKeypad({
    super.key,
    required super.onDigit,
    required super.onBackspace,
    required super.onClear,
    required super.onSubmit,
    super.currentValue,
    bool enabled = true,
  });
}
