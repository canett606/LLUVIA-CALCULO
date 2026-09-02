import 'package:flutter/material.dart';

/// Teclado numérico compacto para iPhone (máx ~38% altura, min 44px teclas)
/// Usa GestureDetector + HitTestBehavior.opaque para iOS Safari
class CompactNumericKeypad extends StatelessWidget {
  final String currentValue;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  const CompactNumericKeypad({
    super.key,
    required this.currentValue,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        
        // 4 filas de teclas, display en top
        final displayH = (height * 0.12).clamp(28.0, 40.0);
        final keypadH = height - displayH - 8;
        final rowH = (keypadH / 4).clamp(44.0, 60.0);
        final keyW = (width - 24) / 3; // 3 columnas con padding
        
        return Container(
          color: const Color(0xFF0A151E),
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Column(
            children: [
              // Display
              Container(
                height: displayH,
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
                    fontSize: displayH * 0.55,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 3,
                    color: currentValue.isEmpty ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              // Filas de teclas
              _Row(keys: ['1','2','3'], h: rowH, w: keyW, onTap: onDigit),
              _Row(keys: ['4','5','6'], h: rowH, w: keyW, onTap: onDigit),
              _Row(keys: ['7','8','9'], h: rowH, w: keyW, onTap: onDigit),
              // Fila especial: ⌫, 0, OK
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Key('⌫', h: rowH, w: keyW, color: const Color(0xFF5C1320), onTap: (_) => onBackspace()),
                    const SizedBox(width: 4),
                    _Key('0', h: rowH, w: keyW, onTap: onDigit),
                    const SizedBox(width: 4),
                    _Key('OK', h: rowH, w: keyW, 
                      color: currentValue.isNotEmpty ? const Color(0xFF0A5840) : Colors.grey[800]!,
                      onTap: currentValue.isNotEmpty ? (_) => onSubmit() : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final List<String> keys;
  final double h;
  final double w;
  final void Function(String) onTap;

  const _Row({required this.keys, required this.h, required this.w, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((k) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _Key(k, h: h, w: w, onTap: onTap),
        )).toList(),
      ),
    );
  }
}

class _Key extends StatefulWidget {
  final String label;
  final double h;
  final double w;
  final Color? color;
  final void Function(String)? onTap;

  const _Key(this.label, {required this.h, required this.w, this.color, this.onTap});

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? const Color(0xFF2A3A4A);
    final enabled = widget.onTap != null;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) {
        setState(() => _pressed = false);
        widget.onTap!(widget.label);
      } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        height: widget.h,
        width: widget.w,
        decoration: BoxDecoration(
          color: _pressed ? baseColor.withAlpha(150) : baseColor.withAlpha(enabled ? 255 : 100),
          borderRadius: BorderRadius.circular(10),
          boxShadow: _pressed ? null : [
            BoxShadow(color: Colors.black26, blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: (widget.h * 0.4).clamp(16.0, 24.0),
            fontWeight: FontWeight.bold,
            color: enabled ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}

// Alias para compatibilidad
class NumericKeypad extends CompactNumericKeypad {
  const NumericKeypad({
    super.key,
    required super.currentValue,
    required super.onDigit,
    required super.onBackspace,
    required super.onClear,
    required super.onSubmit,
    bool enabled = true,
  });
}
