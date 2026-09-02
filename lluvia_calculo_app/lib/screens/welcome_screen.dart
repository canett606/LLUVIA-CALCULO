import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

/// Pantalla de bienvenida para seleccionar/crear jugador.
/// Esta es la única pantalla donde se permite el teclado del sistema
/// (para escribir el nombre del jugador).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _existingProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final provider = context.read<GameProvider>();
    
    // Esperar inicialización
    if (!provider.isInitialized) {
      await provider.initialize();
    }
    
    final profiles = await provider.getExistingProfiles();
    
    setState(() {
      _existingProfiles = profiles;
      _isLoading = false;
    });
    
    // Si ya hay un jugador cargado, ir directo al juego
    if (provider.hasPlayer && mounted) {
      Navigator.of(context).pushReplacementNamed('/game');
    }
  }

  Future<void> _selectOrCreatePlayer(String name) async {
    if (name.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    final provider = context.read<GameProvider>();
    await provider.loadOrCreatePlayer(name.trim());
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/game');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
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
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo/Título
                    const Text(
                      '🌧️',
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lluvia de Cálculo Mental',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mejora tu cálculo mental jugando',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Card de entrada
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '👋 ¡Bienvenido!',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Escribe tu nombre para guardar tu progreso.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Campo de nombre
                          Form(
                            key: _formKey,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nombre del jugador',
                                hintText: 'Ej: Pablo',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                              ),
                              textCapitalization: TextCapitalization.words,
                              maxLength: 24,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Por favor, escribe tu nombre';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submitName(),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Botón de guardar
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _submitName,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text(
                                'COMENZAR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Perfiles existentes
                    if (_existingProfiles.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Jugadores anteriores',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _existingProfiles.map((name) => 
                                ActionChip(
                                  avatar: const Icon(Icons.person, size: 18),
                                  label: Text(name),
                                  onPressed: () => _selectOrCreatePlayer(name),
                                ),
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 40),
                    
                    // Info
                    Text(
                      'Tu progreso se guardará en este dispositivo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  void _submitName() {
    if (_formKey.currentState?.validate() ?? false) {
      _selectOrCreatePlayer(_nameController.text);
    }
  }
}
