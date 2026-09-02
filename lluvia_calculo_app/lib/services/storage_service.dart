import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';

/// Servicio de persistencia local robusta.
/// Usa SharedPreferences que persiste entre sesiones y reinstalaciones
/// (mientras no se borren datos de la app).
class StorageService {
  static const String _profilesKey = 'lluvia_profiles';
  static const String _currentPlayerKey = 'lluvia_current_player';
  static const String _settingsKey = 'lluvia_settings';
  static const String _localRankingKey = 'lluvia_local_ranking';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // ========== PROFILES ==========

  /// Obtiene todos los perfiles guardados
  Future<Map<String, PlayerProfile>> getAllProfiles() async {
    final jsonStr = _safePrefs.getString(_profilesKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final profiles = <String, PlayerProfile>{};
      
      for (final entry in data.entries) {
        try {
          profiles[entry.key] = PlayerProfile.fromJson(
            entry.value as Map<String, dynamic>
          );
        } catch (e) {
          // Skip corrupted profile
          print('Error loading profile ${entry.key}: $e');
        }
      }
      
      return profiles;
    } catch (e) {
      print('Error loading profiles: $e');
      return {};
    }
  }

  /// Guarda un perfil
  Future<bool> saveProfile(PlayerProfile profile) async {
    try {
      final profiles = await getAllProfiles();
      profiles[profile.id] = profile;
      
      final jsonMap = profiles.map((k, v) => MapEntry(k, v.toJson()));
      return _safePrefs.setString(_profilesKey, jsonEncode(jsonMap));
    } catch (e) {
      print('Error saving profile: $e');
      return false;
    }
  }

  /// Obtiene un perfil por ID
  Future<PlayerProfile?> getProfile(String id) async {
    final profiles = await getAllProfiles();
    return profiles[id];
  }

  /// Obtiene o crea un perfil por nombre
  Future<PlayerProfile> getOrCreateProfile(String name) async {
    final profiles = await getAllProfiles();
    
    // Buscar por nombre (case-insensitive)
    for (final profile in profiles.values) {
      if (profile.name.toLowerCase() == name.toLowerCase()) {
        return profile;
      }
    }
    
    // Crear nuevo
    final newProfile = PlayerProfile.create(name);
    await saveProfile(newProfile);
    return newProfile;
  }

  /// Elimina un perfil
  Future<bool> deleteProfile(String id) async {
    final profiles = await getAllProfiles();
    profiles.remove(id);
    
    final jsonMap = profiles.map((k, v) => MapEntry(k, v.toJson()));
    return _safePrefs.setString(_profilesKey, jsonEncode(jsonMap));
  }

  /// Lista nombres de todos los perfiles (para selector)
  Future<List<String>> getProfileNames() async {
    final profiles = await getAllProfiles();
    return profiles.values.map((p) => p.name).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  // ========== CURRENT PLAYER ==========

  /// Obtiene el ID del jugador actual
  Future<String?> getCurrentPlayerId() async {
    return _safePrefs.getString(_currentPlayerKey);
  }

  /// Establece el jugador actual
  Future<bool> setCurrentPlayerId(String id) async {
    return _safePrefs.setString(_currentPlayerKey, id);
  }

  /// Obtiene el perfil del jugador actual
  Future<PlayerProfile?> getCurrentPlayer() async {
    final id = await getCurrentPlayerId();
    if (id == null) return null;
    return getProfile(id);
  }

  // ========== SETTINGS ==========

  /// Guarda configuración
  Future<bool> saveSetting(String key, dynamic value) async {
    final settings = await getSettings();
    settings[key] = value;
    return _safePrefs.setString(_settingsKey, jsonEncode(settings));
  }

  /// Obtiene configuración
  Future<Map<String, dynamic>> getSettings() async {
    final jsonStr = _safePrefs.getString(_settingsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {};
    }
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Obtiene un valor de configuración
  Future<T?> getSetting<T>(String key, [T? defaultValue]) async {
    final settings = await getSettings();
    return (settings[key] as T?) ?? defaultValue;
  }

  // ========== LOCAL RANKING ==========

  /// Estructura de entrada de ranking
  Future<List<RankingEntry>> getLocalRanking() async {
    final jsonStr = _safePrefs.getString(_localRankingKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> data = jsonDecode(jsonStr);
      return data
        .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
        .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } catch (e) {
      print('Error loading ranking: $e');
      return [];
    }
  }

  /// Añade una entrada al ranking local
  Future<bool> addToRanking(RankingEntry entry) async {
    final ranking = await getLocalRanking();
    ranking.add(entry);
    
    // Mantener solo top 100
    ranking.sort((a, b) => b.score.compareTo(a.score));
    final trimmed = ranking.take(100).toList();
    
    final jsonList = trimmed.map((e) => e.toJson()).toList();
    return _safePrefs.setString(_localRankingKey, jsonEncode(jsonList));
  }

  /// Obtiene la posición de un score en el ranking
  Future<int> getRankPosition(int score) async {
    final ranking = await getLocalRanking();
    int position = 1;
    for (final entry in ranking) {
      if (entry.score > score) {
        position++;
      } else {
        break;
      }
    }
    return position;
  }

  // ========== UTILITIES ==========

  /// Limpia todos los datos (para debug/reset)
  Future<bool> clearAll() async {
    return _safePrefs.clear();
  }

  /// Exporta todos los datos como JSON (para backup)
  Future<String> exportData() async {
    final profiles = await getAllProfiles();
    final settings = await getSettings();
    final ranking = await getLocalRanking();
    final currentPlayer = await getCurrentPlayerId();
    
    return jsonEncode({
      'profiles': profiles.map((k, v) => MapEntry(k, v.toJson())),
      'settings': settings,
      'ranking': ranking.map((e) => e.toJson()).toList(),
      'currentPlayer': currentPlayer,
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Importa datos desde JSON (para restore)
  Future<bool> importData(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Importar perfiles
      if (data['profiles'] != null) {
        await _safePrefs.setString(_profilesKey, jsonEncode(data['profiles']));
      }
      
      // Importar settings
      if (data['settings'] != null) {
        await _safePrefs.setString(_settingsKey, jsonEncode(data['settings']));
      }
      
      // Importar ranking
      if (data['ranking'] != null) {
        await _safePrefs.setString(_localRankingKey, jsonEncode(data['ranking']));
      }
      
      // Importar jugador actual
      if (data['currentPlayer'] != null) {
        await _safePrefs.setString(_currentPlayerKey, data['currentPlayer']);
      }
      
      return true;
    } catch (e) {
      print('Error importing data: $e');
      return false;
    }
  }
}

/// Entrada de ranking local
class RankingEntry {
  final String playerId;
  final String playerName;
  final int score;
  final String mode;
  final DateTime playedAt;
  final double accuracy;
  final int level;

  const RankingEntry({
    required this.playerId,
    required this.playerName,
    required this.score,
    required this.mode,
    required this.playedAt,
    required this.accuracy,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'score': score,
    'mode': mode,
    'playedAt': playedAt.toIso8601String(),
    'accuracy': accuracy,
    'level': level,
  };

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
    playerId: json['playerId'] ?? '',
    playerName: json['playerName'] ?? '',
    score: json['score'] ?? 0,
    mode: json['mode'] ?? '',
    playedAt: DateTime.tryParse(json['playedAt'] ?? '') ?? DateTime.now(),
    accuracy: (json['accuracy'] ?? 0).toDouble(),
    level: json['level'] ?? 1,
  );
}
