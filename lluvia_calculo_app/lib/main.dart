import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/game_provider.dart';
import 'services/storage_service.dart';
import 'services/audio_service.dart';
import 'services/multiplayer_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/game_screen.dart';
import 'screens/multiplayer_screen.dart';
import 'screens/multiplayer_game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar orientación preferida (retrato en móvil)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Configurar estilo de barra de estado
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF07131D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  runApp(const LluviaCalculoApp());
}

class LluviaCalculoApp extends StatelessWidget {
  const LluviaCalculoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inicializar servicios
        Provider<StorageService>(
          create: (_) => StorageService(),
          dispose: (_, s) => s,
        ),
        Provider<AudioService>(
          create: (_) => AudioService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<MultiplayerService>(
          create: (_) => MultiplayerServiceFactory.create(),
          dispose: (_, service) => service.dispose(),
        ),
        
        // Provider principal del juego
        ChangeNotifierProxyProvider3<StorageService, AudioService, MultiplayerService, GameProvider>(
          create: (context) => GameProvider(
            storage: context.read<StorageService>(),
            audio: context.read<AudioService>(),
            multiplayer: context.read<MultiplayerService>(),
          ),
          update: (_, storage, audio, multiplayer, previous) =>
            previous ?? GameProvider(
              storage: storage,
              audio: audio,
              multiplayer: multiplayer,
            ),
        ),
      ],
      child: MaterialApp(
        title: 'Lluvia de Cálculo Mental',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.dark, // Siempre modo oscuro para consistencia visual
        initialRoute: '/welcome',
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/game': (context) => const GameScreen(),
          '/multiplayer': (context) => const MultiplayerScreen(),
          '/multiplayer-game': (context) => const MultiplayerGameScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF62D6FF),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF62D6FF),
        brightness: Brightness.dark,
        surface: const Color(0xFF0C2431),
        onSurface: const Color(0xFFEFF9FF),
        primary: const Color(0xFF62D6FF),
        secondary: const Color(0xFF78F0B4),
        tertiary: const Color(0xFFFFB74D),
        error: const Color(0xFFFF8997),
      ),
      scaffoldBackgroundColor: const Color(0xFF07131D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0C2431),
        foregroundColor: Color(0xFFEFF9FF),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0C2431).withAlpha(204),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF62D6FF),
          foregroundColor: const Color(0xFF022433),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF62D6FF),
          side: const BorderSide(color: Color(0xFF62D6FF)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A151E).withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFAFE6FF).withOpacity(0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF62D6FF),
            width: 2,
          ),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}
