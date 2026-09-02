# 🌧️ Lluvia de Cálculo Mental

Aplicación móvil nativa para mejorar el cálculo mental jugando. Operaciones matemáticas caen como gotas de lluvia y el jugador debe resolverlas antes de que lleguen al suelo.

## 📱 Plataformas

- **iOS** (iPhone y iPad)
- **Android** (teléfonos y tablets)

## ✨ Características

### Juego Principal
- **Lluvia de operaciones**: Las operaciones caen del cielo, ¡resuélvelas antes de que toquen el suelo!
- **Teclado numérico integrado**: Sin depender del teclado del sistema. El teclado siempre está visible junto al área de juego.
- **Efectos de sonido**: Feedback auditivo para aciertos y fallos.

### Modos de Juego
- **📚 Aprendizaje**: Empieza fácil y sube gradualmente según tu rendimiento. Ideal para principiantes.
- **⏱️ Contrarreloj**: 90 segundos para conseguir la mayor puntuación posible.
- **🎯 Por puntuación**: Alcanza 500 puntos lo más rápido posible.
- **💀 Supervivencia**: 5 vidas, dificultad creciente. ¿Cuánto puedes aguantar?
- **📈 Por niveles**: Desbloquea niveles demostrando maestría.

### Familias de Operaciones
- ➕ Sumas
- ➖ Restas
- ✖️ Multiplicaciones
- ➗ Divisiones
- 🔀 Mixtas (operaciones de dos pasos)

### Sistema Adaptativo
- El juego ajusta la dificultad según tu rendimiento
- Empieza desde operaciones muy básicas (1+1, 2×3) hasta complejas
- Trackea fortalezas y debilidades por familia de operaciones
- Sugiere qué practicar basado en tu historial

### Persistencia
- Perfiles de jugador guardados localmente
- Historial de sesiones, aciertos, fallos
- Mejor puntuación por modo
- Progreso que sobrevive al reinicio de la app

### Arquitectura Multijugador (preparada)
- Salas de juego con códigos
- Sincronización de inicio
- Comparación de puntuaciones en tiempo real
- Ranking local incluido, ranking online preparado

## 🚀 Instalación para Desarrollo

### Requisitos
- Flutter SDK 3.10+
- Android Studio o Xcode
- Dispositivo físico o emulador

### Pasos

```bash
# Clonar el repositorio
git clone <repo-url>
cd lluvia_calculo_app

# Instalar dependencias
flutter pub get

# Verificar configuración
flutter doctor

# Ejecutar en modo debug
flutter run
```

### Android Emulator

```bash
# Listar emuladores disponibles
flutter emulators

# Lanzar emulador
flutter emulators --launch <emulator_id>

# O crear uno nuevo
flutter emulators --create --name pixel_phone

# Ejecutar la app
flutter run
```

### iOS Simulator (solo macOS)

```bash
# Abrir simulador
open -a Simulator

# Ejecutar la app
flutter run
```

## 📦 Generar Builds

### APK para Android

```bash
# APK debug (para pruebas)
flutter build apk --debug

# APK release (para distribución)
flutter build apk --release

# El APK estará en: build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle para Google Play

```bash
flutter build appbundle --release
# Resultado en: build/app/outputs/bundle/release/app-release.aab
```

### iOS (requiere macOS)

```bash
# Build para simulador
flutter build ios --simulator

# Build para dispositivo real (requiere cuenta de desarrollador Apple)
flutter build ios --release

# Abrir en Xcode para firmar y archivar
open ios/Runner.xcworkspace
```

## 🧪 Tests

```bash
# Ejecutar todos los tests
flutter test

# Tests específicos
flutter test test/core/operation_generator_test.dart
flutter test test/core/adaptive_engine_test.dart
flutter test test/core/scoring_engine_test.dart

# Con coverage
flutter test --coverage
```

## 📐 Arquitectura

```
lib/
├── main.dart              # Punto de entrada
├── core/                  # Lógica de negocio
│   ├── operation_generator.dart  # Generador procedural de operaciones
│   ├── adaptive_engine.dart      # Motor adaptativo de dificultad
│   └── scoring_engine.dart       # Sistema de puntuación
├── models/                # Modelos de datos
│   ├── operation.dart
│   ├── player_profile.dart
│   └── game_state.dart
├── providers/             # Estado global (Provider)
│   └── game_provider.dart
├── services/              # Servicios
│   ├── storage_service.dart      # Persistencia local
│   ├── audio_service.dart        # Efectos de sonido
│   └── multiplayer_service.dart  # Multijugador (preparado)
├── screens/               # Pantallas
│   ├── welcome_screen.dart
│   └── game_screen.dart
└── widgets/               # Componentes reutilizables
    ├── numeric_keypad.dart
    ├── falling_drop.dart
    └── game_hud.dart
```

## 🌐 Multijugador y Ranking Online

La arquitectura está preparada para multijugador, pero requiere un backend. Opciones documentadas:

### Firebase Realtime Database
```dart
// En multiplayer_service.dart, implementar FirebaseMultiplayerService
// Configurar firebase_options.dart con tu proyecto
```

### Supabase
```dart
// Implementar SupabaseMultiplayerService
// Configurar SUPABASE_URL y SUPABASE_ANON_KEY
```

### Variables de entorno necesarias
```
MULTIPLAYER_ENABLED=true
MULTIPLAYER_URL=https://tu-backend.com
MULTIPLAYER_API_KEY=tu-api-key
```

## 🔧 Qué Funciona Offline vs Online

| Característica | Offline | Online (requiere backend) |
|---------------|---------|---------------------------|
| Juego individual | ✅ | ✅ |
| Persistencia local | ✅ | ✅ |
| Ranking local | ✅ | ✅ |
| Sistema adaptativo | ✅ | ✅ |
| Multijugador salas | ❌ | ✅ |
| Ranking global | ❌ | ✅ |
| Sincronización entre dispositivos | ❌ | ✅ |

## 🎨 Layout del Juego (Retrato)

```
┌─────────────────────────┐
│  HUD (Puntos, Vidas,    │
│  Racha, Nivel, Récord)  │
├─────────────────────────┤
│                         │
│     ÁREA DE JUEGO       │
│                         │
│   ┌─────┐    ┌─────┐    │
│   │3 × 4│    │12+15│    │  ← Gotas cayendo
│   └─────┘    └─────┘    │
│                         │
│         ┌─────┐         │
│         │ 27  │         │
│         └─────┘         │
│                         │
│ ═══════════════════════ │  ← Línea del suelo
├─────────────────────────┤
│    ┌───────────────┐    │
│    │      12       │    │  ← Display de entrada
│    └───────────────┘    │
│  ┌───┐ ┌───┐ ┌───┐      │
│  │ 1 │ │ 2 │ │ 3 │      │
│  ├───┤ ├───┤ ├───┤      │
│  │ 4 │ │ 5 │ │ 6 │      │  ← Teclado numérico
│  ├───┤ ├───┤ ├───┤      │     siempre visible
│  │ 7 │ │ 8 │ │ 9 │      │
│  ├───┤ ├───┤ ├───┤      │
│  │ ⌫ │ │ 0 │ │OK │      │
│  └───┴─┴───┴─┴───┘      │
│  ┌─────────────────┐    │
│  │   BORRAR TODO   │    │
│  └─────────────────┘    │
└─────────────────────────┘
```

**Importante**: El teclado del sistema iOS/Android **nunca** aparece durante el juego. Solo se usa para escribir el nombre del jugador en la pantalla de bienvenida.

## 📄 Licencia

MIT

## 🙏 Créditos

Desarrollado como reconstrucción de la PWA original "Lluvia de Cálculo Mental".
