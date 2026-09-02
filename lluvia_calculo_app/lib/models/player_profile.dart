import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'operation.dart';

/// Estadísticas por tier dentro de una familia
class TierStats extends Equatable {
  final int correct;
  final int incorrect;
  final double avgTimeMs;

  const TierStats({
    this.correct = 0,
    this.incorrect = 0,
    this.avgTimeMs = 0,
  });

  double get accuracy => (correct + incorrect) > 0 
    ? correct / (correct + incorrect) 
    : 0.0;

  TierStats copyWith({
    int? correct,
    int? incorrect,
    double? avgTimeMs,
  }) {
    return TierStats(
      correct: correct ?? this.correct,
      incorrect: incorrect ?? this.incorrect,
      avgTimeMs: avgTimeMs ?? this.avgTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'correct': correct,
    'incorrect': incorrect,
    'avgTimeMs': avgTimeMs,
  };

  factory TierStats.fromJson(Map<String, dynamic> json) => TierStats(
    correct: json['correct'] ?? 0,
    incorrect: json['incorrect'] ?? 0,
    avgTimeMs: (json['avgTimeMs'] ?? 0).toDouble(),
  );

  @override
  List<Object?> get props => [correct, incorrect, avgTimeMs];
}

/// Estadísticas por familia de operaciones
class FamilyStats extends Equatable {
  final int correct;
  final int incorrect;
  final double avgResponseTimeMs;
  final int maxTierUnlocked;
  final Map<int, TierStats> tierStats;

  const FamilyStats({
    this.correct = 0,
    this.incorrect = 0,
    this.avgResponseTimeMs = 0,
    this.maxTierUnlocked = 1,
    this.tierStats = const {},
  });

  double get accuracy => (correct + incorrect) > 0 
    ? correct / (correct + incorrect) 
    : 0.0;

  FamilyStats copyWith({
    int? correct,
    int? incorrect,
    double? avgResponseTimeMs,
    int? maxTierUnlocked,
    Map<int, TierStats>? tierStats,
  }) {
    return FamilyStats(
      correct: correct ?? this.correct,
      incorrect: incorrect ?? this.incorrect,
      avgResponseTimeMs: avgResponseTimeMs ?? this.avgResponseTimeMs,
      maxTierUnlocked: maxTierUnlocked ?? this.maxTierUnlocked,
      tierStats: tierStats ?? this.tierStats,
    );
  }

  Map<String, dynamic> toJson() => {
    'correct': correct,
    'incorrect': incorrect,
    'avgResponseTimeMs': avgResponseTimeMs,
    'maxTierUnlocked': maxTierUnlocked,
    'tierStats': tierStats.map((k, v) => MapEntry(k.toString(), v.toJson())),
  };

  factory FamilyStats.fromJson(Map<String, dynamic> json) {
    final tierStatsJson = json['tierStats'] as Map<String, dynamic>? ?? {};
    final tierStats = <int, TierStats>{};
    
    for (final entry in tierStatsJson.entries) {
      final tier = int.tryParse(entry.key);
      if (tier != null) {
        tierStats[tier] = TierStats.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    
    return FamilyStats(
      correct: json['correct'] ?? 0,
      incorrect: json['incorrect'] ?? 0,
      avgResponseTimeMs: (json['avgResponseTimeMs'] ?? 0).toDouble(),
      maxTierUnlocked: json['maxTierUnlocked'] ?? 1,
      tierStats: tierStats,
    );
  }

  @override
  List<Object?> get props => [correct, incorrect, avgResponseTimeMs, maxTierUnlocked, tierStats];
}

/// Perfil completo del jugador con persistencia
class PlayerProfile extends Equatable {
  final String id;
  final String name;
  final int bestScore;
  final int totalSessions;
  final int totalCorrect;
  final int totalIncorrect;
  final int globalTierUnlocked;
  final String lastMode;
  final String lastFamily;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final Map<OperationFamily, FamilyStats> familyStats;
  
  // Parámetros adaptativos
  final double adaptiveSpeedFactor;
  final int adaptiveStartTier;

  const PlayerProfile({
    required this.id,
    required this.name,
    this.bestScore = 0,
    this.totalSessions = 0,
    this.totalCorrect = 0,
    this.totalIncorrect = 0,
    this.globalTierUnlocked = 1,
    this.lastMode = 'aprendizaje',
    this.lastFamily = 'todas',
    required this.createdAt,
    required this.lastPlayedAt,
    this.familyStats = const {},
    this.adaptiveSpeedFactor = 1.0,
    this.adaptiveStartTier = 1,
  });

  double get globalAccuracy => (totalCorrect + totalIncorrect) > 0
    ? totalCorrect / (totalCorrect + totalIncorrect)
    : 0.0;

  /// Obtiene el tier sugerido para una familia específica
  int getTierForFamily(OperationFamily family) {
    final stats = familyStats[family];
    if (stats == null) return 1;
    return stats.maxTierUnlocked.clamp(1, 5);
  }

  /// Obtiene precisión para una familia específica
  double getAccuracyForFamily(OperationFamily family) {
    final stats = familyStats[family];
    return stats?.accuracy ?? 0.0;
  }

  PlayerProfile copyWith({
    String? id,
    String? name,
    int? bestScore,
    int? totalSessions,
    int? totalCorrect,
    int? totalIncorrect,
    int? globalTierUnlocked,
    String? lastMode,
    String? lastFamily,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    Map<OperationFamily, FamilyStats>? familyStats,
    double? adaptiveSpeedFactor,
    int? adaptiveStartTier,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      bestScore: bestScore ?? this.bestScore,
      totalSessions: totalSessions ?? this.totalSessions,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalIncorrect: totalIncorrect ?? this.totalIncorrect,
      globalTierUnlocked: globalTierUnlocked ?? this.globalTierUnlocked,
      lastMode: lastMode ?? this.lastMode,
      lastFamily: lastFamily ?? this.lastFamily,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      familyStats: familyStats ?? this.familyStats,
      adaptiveSpeedFactor: adaptiveSpeedFactor ?? this.adaptiveSpeedFactor,
      adaptiveStartTier: adaptiveStartTier ?? this.adaptiveStartTier,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bestScore': bestScore,
    'totalSessions': totalSessions,
    'totalCorrect': totalCorrect,
    'totalIncorrect': totalIncorrect,
    'globalTierUnlocked': globalTierUnlocked,
    'lastMode': lastMode,
    'lastFamily': lastFamily,
    'createdAt': createdAt.toIso8601String(),
    'lastPlayedAt': lastPlayedAt.toIso8601String(),
    'familyStats': familyStats.map((k, v) => MapEntry(k.name, v.toJson())),
    'adaptiveSpeedFactor': adaptiveSpeedFactor,
    'adaptiveStartTier': adaptiveStartTier,
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final familyStatsJson = json['familyStats'] as Map<String, dynamic>? ?? {};
    final familyStats = <OperationFamily, FamilyStats>{};
    
    for (final entry in familyStatsJson.entries) {
      try {
        final family = OperationFamily.values.firstWhere((f) => f.name == entry.key);
        familyStats[family] = FamilyStats.fromJson(entry.value as Map<String, dynamic>);
      } catch (_) {
        // Skip invalid family names
      }
    }

    return PlayerProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bestScore: json['bestScore'] ?? 0,
      totalSessions: json['totalSessions'] ?? 0,
      totalCorrect: json['totalCorrect'] ?? 0,
      totalIncorrect: json['totalIncorrect'] ?? 0,
      globalTierUnlocked: json['globalTierUnlocked'] ?? 1,
      lastMode: json['lastMode'] ?? 'aprendizaje',
      lastFamily: json['lastFamily'] ?? 'todas',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      lastPlayedAt: DateTime.tryParse(json['lastPlayedAt'] ?? '') ?? DateTime.now(),
      familyStats: familyStats,
      adaptiveSpeedFactor: (json['adaptiveSpeedFactor'] ?? 1.0).toDouble(),
      adaptiveStartTier: json['adaptiveStartTier'] ?? 1,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PlayerProfile.fromJsonString(String jsonStr) => 
    PlayerProfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  factory PlayerProfile.create(String name) {
    final now = DateTime.now();
    return PlayerProfile(
      id: '${name.toLowerCase().replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}',
      name: name,
      createdAt: now,
      lastPlayedAt: now,
    );
  }

  @override
  List<Object?> get props => [id, name, bestScore, totalSessions, totalCorrect, 
    totalIncorrect, globalTierUnlocked, lastMode, lastFamily, familyStats,
    adaptiveSpeedFactor, adaptiveStartTier];
}
