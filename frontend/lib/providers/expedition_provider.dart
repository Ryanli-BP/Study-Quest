import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Expedition locations
// ---------------------------------------------------------------------------

class ExpeditionLocation {
  final String id;
  final String name;
  final String emoji;
  final String difficulty;
  final int coins;
  final int materials;
  final int xpPerCompanion;
  final Color color;
  final double mapX;
  final double mapY;

  const ExpeditionLocation({
    required this.id,
    required this.name,
    required this.emoji,
    required this.difficulty,
    required this.coins,
    required this.materials,
    required this.xpPerCompanion,
    required this.color,
    required this.mapX,
    required this.mapY,
  });
}

const expeditionLocations = <ExpeditionLocation>[
  ExpeditionLocation(
    id: 'forest', name: 'Forest of Knowledge', emoji: '🌲',
    difficulty: 'Easy', coins: 50, materials: 2, xpPerCompanion: 30,
    color: Color(0xFF2E7D32), mapX: 140, mapY: 200,
  ),
  ExpeditionLocation(
    id: 'library', name: 'Ancient Library', emoji: '📜',
    difficulty: 'Easy', coins: 60, materials: 2, xpPerCompanion: 35,
    color: Color(0xFF1565C0), mapX: 380, mapY: 90,
  ),
  ExpeditionLocation(
    id: 'caves', name: 'Crystal Caves', emoji: '💎',
    difficulty: 'Medium', coins: 100, materials: 4, xpPerCompanion: 55,
    color: Color(0xFF6A1B9A), mapX: 680, mapY: 180,
  ),
  ExpeditionLocation(
    id: 'temple', name: 'Sky Temple', emoji: '⛩️',
    difficulty: 'Hard', coins: 150, materials: 5, xpPerCompanion: 75,
    color: Color(0xFFE65100), mapX: 760, mapY: 420,
  ),
  ExpeditionLocation(
    id: 'dungeon', name: 'Shadow Dungeon', emoji: '💀',
    difficulty: 'Hard', coins: 200, materials: 6, xpPerCompanion: 100,
    color: Color(0xFF37474F), mapX: 180, mapY: 470,
  ),
];

// ---------------------------------------------------------------------------
// Companion progress (level + XP) — stored locally
// ---------------------------------------------------------------------------

class CompanionProgress {
  int level;
  int xp;

  CompanionProgress({this.level = 1, this.xp = 0});

  int get xpToNext => level * 100;
  double get xpFraction => xp / xpToNext;

  void addXp(int amount) {
    xp += amount;
    while (xp >= xpToNext) {
      xp -= xpToNext;
      level++;
    }
  }

  Map<String, dynamic> toJson() => {'level': level, 'xp': xp};
  factory CompanionProgress.fromJson(Map<String, dynamic> j) =>
      CompanionProgress(level: j['level'] ?? 1, xp: j['xp'] ?? 0);
}

// ---------------------------------------------------------------------------
// Active expedition
// ---------------------------------------------------------------------------

class ActiveExpedition {
  final String id;
  final ExpeditionLocation location;
  final List<Map<String, dynamic>> companions;
  final DateTime startTime;
  DateTime endTime;
  bool completed;
  bool claimed;

  ActiveExpedition({
    required this.id,
    required this.location,
    required this.companions,
    required this.startTime,
    required this.endTime,
    this.completed = false,
    this.claimed = false,
  });

  Duration get remaining {
    final r = endTime.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  bool get isFinished => DateTime.now().isAfter(endTime);

  double get progress {
    final total = endTime.difference(startTime).inSeconds;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get remainingLabel {
    final r = remaining;
    if (r == Duration.zero) return 'Done!';
    final m = r.inMinutes;
    final s = r.inSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'locationId': location.id,
        'companions': companions,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'completed': completed,
        'claimed': claimed,
      };

  factory ActiveExpedition.fromJson(Map<String, dynamic> j) {
    final loc = expeditionLocations.firstWhere((l) => l.id == j['locationId'],
        orElse: () => expeditionLocations.first);
    return ActiveExpedition(
      id: j['id'],
      location: loc,
      companions: List<Map<String, dynamic>>.from(j['companions']),
      startTime: DateTime.parse(j['startTime']),
      endTime: DateTime.parse(j['endTime']),
      completed: j['completed'] ?? false,
      claimed: j['claimed'] ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

const _expeditionDuration = Duration(minutes: 30);

class ExpeditionProvider extends ChangeNotifier {
  List<ActiveExpedition> _expeditions = [];
  Map<int, CompanionProgress> _companionProgress = {};
  int _materials = 0;
  Map<String, int> _buildingLevels = {};
  Timer? _ticker;

  List<ActiveExpedition> get expeditions => _expeditions;
  List<ActiveExpedition> get active =>
      _expeditions.where((e) => !e.claimed).toList();
  Map<int, CompanionProgress> get companionProgress => _companionProgress;
  int get materials => _materials;

  CompanionProgress progressFor(int characterId) =>
      _companionProgress[characterId] ?? CompanionProgress();

  int buildingLevel(String buildingId) => _buildingLevels[buildingId] ?? 1;

  /// Spends [amount] materials. Returns false if not enough.
  bool spendMaterials(int amount) {
    if (_materials < amount) return false;
    _materials -= amount;
    _save();
    notifyListeners();
    return true;
  }

  void addMaterials(int amount) {
    _materials += amount;
    _save();
    notifyListeners();
  }

  /// Upgrades a building by one level. Returns false if already max or not enough materials.
  bool upgradeBuilding(String buildingId, int cost, int maxLevel) {
    final current = buildingLevel(buildingId);
    if (current >= maxLevel) return false;
    if (!spendMaterials(cost)) return false;
    _buildingLevels[buildingId] = current + 1;
    _save();
    notifyListeners();
    return true;
  }

  /// Adds XP directly to a companion (used by Hospital).
  void addXpToCompanion(int companionId, int amount) {
    final progress = _companionProgress[companionId] ?? CompanionProgress();
    progress.addXp(amount);
    _companionProgress[companionId] = progress;
    _save();
    notifyListeners();
  }

  Future<void> init() async {
    await _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkCompletions();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> startExpedition(
    ExpeditionLocation location,
    List<Map<String, dynamic>> companions,
  ) async {
    final now = DateTime.now();
    _expeditions.add(ActiveExpedition(
      id: now.millisecondsSinceEpoch.toString(),
      location: location,
      companions: companions,
      startTime: now,
      endTime: now.add(_expeditionDuration),
    ));
    await _save();
    notifyListeners();
  }

  Future<void> failExpedition(String expeditionId) async {
    final exp = _expeditions.firstWhere((e) => e.id == expeditionId);
    exp.claimed = true;
    await _save();
    notifyListeners();
  }

  Future<Map<String, int>> claimRewards(String expeditionId) async {
    final exp = _expeditions.firstWhere((e) => e.id == expeditionId);
    exp.claimed = true;

    for (final char in exp.companions) {
      final id = char['id'] as int;
      final progress = _companionProgress[id] ?? CompanionProgress();
      progress.addXp(exp.location.xpPerCompanion);
      _companionProgress[id] = progress;
    }

    _materials += exp.location.materials;
    await _save();
    notifyListeners();
    return {
      'coins': exp.location.coins,
      'materials': exp.location.materials,
      'xp': exp.location.xpPerCompanion,
    };
  }

  Future<void> instantComplete(String expeditionId) async {
    final exp = _expeditions.firstWhere((e) => e.id == expeditionId);
    exp.endTime = DateTime.now().subtract(const Duration(seconds: 1));
    exp.completed = true;
    await _save();
    notifyListeners();
  }

  void _checkCompletions() {
    bool changed = false;
    for (final exp in _expeditions) {
      if (!exp.completed && exp.isFinished) {
        exp.completed = true;
        changed = true;
      }
    }
    if (changed) _save();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
        'expeditions', jsonEncode(_expeditions.map((e) => e.toJson()).toList()));
    prefs.setString(
        'companion_progress',
        jsonEncode(_companionProgress
            .map((k, v) => MapEntry(k.toString(), v.toJson()))));
    prefs.setInt('materials', _materials);
    prefs.setString('building_levels',
        jsonEncode(_buildingLevels.map((k, v) => MapEntry(k, v))));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final expJson = prefs.getString('expeditions');
    if (expJson != null) {
      final list = jsonDecode(expJson) as List;
      _expeditions = list
          .map((j) => ActiveExpedition.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    final progJson = prefs.getString('companion_progress');
    if (progJson != null) {
      final map = jsonDecode(progJson) as Map<String, dynamic>;
      _companionProgress = map.map((k, v) =>
          MapEntry(int.parse(k), CompanionProgress.fromJson(v as Map<String, dynamic>)));
    }
    _materials = prefs.getInt('materials') ?? 0;
    final buildJson = prefs.getString('building_levels');
    if (buildJson != null) {
      final map = jsonDecode(buildJson) as Map<String, dynamic>;
      _buildingLevels = map.map((k, v) => MapEntry(k, v as int));
    }
  }
}
