# Changelog

Historial de cambios entre la PWA original y la nueva app Flutter nativa.

## [1.0.0] - 2024 - Reconstrucción Completa en Flutter

### ✅ Cambiado (vs PWA original)

#### Plataforma
- **ANTES**: PWA con HTML/CSS/JS, dependiente del navegador
- **AHORA**: App nativa Flutter para iOS y Android
- **ANTES**: "Añadir a pantalla de inicio" como método de instalación
- **AHORA**: Instalación real desde APK/App Store

#### Teclado e Input
- **ANTES**: `<input inputmode="numeric">` que invocaba teclado del sistema iOS/Android
- **AHORA**: Teclado numérico personalizado (`NumericKeypad`) siempre visible
- **ANTES**: Bug donde el teclado del sistema cubría las gotas cayendo
- **AHORA**: Layout fijo: HUD arriba, área de juego en medio, teclado abajo
- **ANTES**: `playTap()` referenciado pero no definido (error en consola)
- **AHORA**: AudioService con generación de tonos funcional

#### Generación de Operaciones
- **ANTES**: Lista estática de 102 operaciones hardcodeadas
- **AHORA**: `OperationGenerator` procedural con infinitas combinaciones
- **ANTES**: Sin división, sin operaciones para principiantes verdaderos
- **AHORA**: Sumas desde 1+1, divisiones exactas, 5 tiers de dificultad
- **ANTES**: Tiers 1-4 con operaciones fijas
- **AHORA**: Tiers 1-5 con complejidad escalada:
  - Tier 1: Sumas ≤20, restas simples, tablas 1-5, división por 1-2
  - Tier 2: Números hasta 40, tablas 1-10
  - Tier 3: Números hasta 200, tablas extendidas
  - Tier 4: Números mayores, operaciones mixtas
  - Tier 5: Máxima dificultad

#### Sistema Adaptativo
- **ANTES**: Dificultad basada solo en score y modo
- **AHORA**: `AdaptiveEngine` que trackea:
  - Precisión por familia de operaciones
  - Tiempo de respuesta promedio
  - Fortalezas y debilidades
  - Ajuste automático de tier y velocidad
- **ANTES**: Sin sugerencias de qué practicar
- **AHORA**: Sugiere familia débil para entrenar

#### Persistencia
- **ANTES**: `localStorage` con key por nombre de jugador (frágil)
- **AHORA**: `SharedPreferences` con estructura robusta:
  - ID único por perfil
  - Estadísticas detalladas por familia
  - Parámetros adaptativos guardados
  - Ranking local persistente

#### Modos de Juego
- **ANTES**: Fácil, Entrenamiento, Mejora por niveles, Supervivencia
- **AHORA**: 
  - Aprendizaje (adaptativo, nuevo)
  - Por tiempo (contrarreloj 90s)
  - Por puntuación (objetivo 500 pts)
  - Supervivencia (vidas limitadas)
  - Por niveles (desbloqueo progresivo)

#### Scoring
- **ANTES**: Puntos fijos + bonus por velocidad básico
- **AHORA**: `ScoringEngine` con:
  - Puntos base por tier
  - Bonus por respuesta rápida (3 niveles)
  - Bonus por racha (escalado, capped)
  - Bonus por complejidad de operación
  - Bonus de fin de partida (vidas + precisión)
  - Multiplicadores por modo de juego

#### UI/UX
- **ANTES**: CSS responsivo pero problemas en iOS Safari
- **AHORA**: Flutter widgets nativos, safe areas respetadas
- **ANTES**: Paneles de información ocupando espacio vertical
- **AHORA**: HUD compacto con solo lo esencial
- **ANTES**: Botón "Instalar" que no funcionaba en iOS
- **AHORA**: Eliminado (se instala como app nativa)

#### Multijugador
- **ANTES**: Panel visual "Modo batalla" sin funcionalidad
- **AHORA**: Arquitectura completa implementada:
  - `MultiplayerService` con interface definida
  - `GameRoom`, `RoomPlayer`, eventos
  - `OfflineMultiplayerService` para modo local
  - Documentación para integrar Firebase/Supabase

### ✅ Corregido

- `playTap()` ahora existe y funciona
- Teclado del sistema ya no aparece durante el juego
- Layout siempre muestra área de juego + teclado
- Persistencia robusta que no se pierde al refrescar
- Código de keypad duplicado eliminado (estaba 2 veces en game.js)

### ✅ Añadido

- Tests unitarios para generador, motor adaptativo y scoring
- Documentación completa en español
- Arquitectura limpia con separación de responsabilidades
- Soporte para modo oscuro consistente
- Pantalla de bienvenida con selección de perfiles
- Sistema de ranking local con historial
- Exportación/importación de datos de jugador

### 🔧 Estructura de Archivos

```
PWA Original:
├── index.html
├── game.js (490 líneas, todo junto)
├── style.css
├── manifest.webmanifest
└── sw.js

Flutter Nuevo:
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── operation_generator.dart
│   │   ├── adaptive_engine.dart
│   │   └── scoring_engine.dart
│   ├── models/
│   │   ├── operation.dart
│   │   ├── player_profile.dart
│   │   └── game_state.dart
│   ├── providers/
│   │   └── game_provider.dart
│   ├── services/
│   │   ├── storage_service.dart
│   │   ├── audio_service.dart
│   │   └── multiplayer_service.dart
│   ├── screens/
│   │   ├── welcome_screen.dart
│   │   └── game_screen.dart
│   └── widgets/
│       ├── numeric_keypad.dart
│       ├── falling_drop.dart
│       └── game_hud.dart
├── test/
│   └── core/
│       ├── operation_generator_test.dart
│       ├── adaptive_engine_test.dart
│       └── scoring_engine_test.dart
├── README.md
└── CHANGELOG.md
```
