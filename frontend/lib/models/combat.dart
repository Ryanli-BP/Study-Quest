import 'package:flutter/material.dart';
import '../providers/expedition_provider.dart';

// ---------------------------------------------------------------------------
// Ability
// ---------------------------------------------------------------------------

class Ability {
  final String name;
  final String emoji;
  final String description;
  final int manaCost;
  final double damageMultiplier;   // ATK * multiplier dealt to boss (0 = no dmg)
  final int healAllAmount;          // HP restored to all living companions (0 = none)
  final int dotDamage;              // damage per boss turn (0 = none)
  final int dotDuration;
  final double atkBuffMultiplier;   // fraction buff to all companions ATK (0 = none)
  final int buffDuration;
  final double bossAtkDebuff;       // fraction reduction to boss ATK (0 = none)
  final int debuffDuration;

  const Ability({
    required this.name,
    required this.emoji,
    required this.description,
    this.manaCost = 50,
    this.damageMultiplier = 0,
    this.healAllAmount = 0,
    this.dotDamage = 0,
    this.dotDuration = 0,
    this.atkBuffMultiplier = 0,
    this.buffDuration = 0,
    this.bossAtkDebuff = 0,
    this.debuffDuration = 0,
  });
}

// One ability per companion keyed by name
const Map<String, Ability> companionAbilities = {
  'Sparky': Ability(
    name: 'Spark Overload', emoji: '⚡',
    description: '1.8× ATK electric burst',
    manaCost: 50,
    damageMultiplier: 1.8,
  ),
  'Leafy': Ability(
    name: 'Nature Mend', emoji: '🌿',
    description: 'Restore 25 HP to all companions',
    manaCost: 40,
    healAllAmount: 25,
  ),
  'Chisel': Ability(
    name: 'Stone Shatter', emoji: '🪨',
    description: '1.4× ATK + reduce boss ATK 25% for 2 turns',
    manaCost: 50,
    damageMultiplier: 1.4,
    bossAtkDebuff: 0.25,
    debuffDuration: 2,
  ),
  'Bubbles': Ability(
    name: 'Acid Splash', emoji: '🧪',
    description: '1.2× ATK + 10 DoT for 3 turns',
    manaCost: 45,
    damageMultiplier: 1.2,
    dotDamage: 10,
    dotDuration: 3,
  ),
  'Nova': Ability(
    name: 'Supernova', emoji: '💫',
    description: '2.2× ATK cosmic blast',
    manaCost: 60,
    damageMultiplier: 2.2,
  ),
  'Cipher': Ability(
    name: 'System Hack', emoji: '💻',
    description: '1.5× ATK + reduce boss ATK 40% for 2 turns',
    manaCost: 60,
    damageMultiplier: 1.5,
    bossAtkDebuff: 0.40,
    debuffDuration: 2,
  ),
  'Lyra': Ability(
    name: 'Battle Hymn', emoji: '🎵',
    description: 'Buff all companions ATK +30% for 3 turns',
    manaCost: 50,
    atkBuffMultiplier: 0.30,
    buffDuration: 3,
  ),
  'Arcanum': Ability(
    name: 'Arcane Blast', emoji: '🔮',
    description: '2.8× ATK arcane explosion',
    manaCost: 70,
    damageMultiplier: 2.8,
  ),
  'Solaris': Ability(
    name: 'Solar Flare', emoji: '☀️',
    description: '2.0× ATK + 15 DoT for 2 turns',
    manaCost: 65,
    damageMultiplier: 2.0,
    dotDamage: 15,
    dotDuration: 2,
  ),
  'Omnisage': Ability(
    name: 'Omnistrike', emoji: '🌟',
    description: '3.5× ATK + heal all companions 20 HP',
    manaCost: 80,
    damageMultiplier: 3.5,
    healAllAmount: 20,
  ),
};

const Ability _defaultAbility = Ability(
  name: 'Power Strike', emoji: '⚔️',
  description: '1.5× ATK strike',
  manaCost: 50,
  damageMultiplier: 1.5,
);

Ability abilityFor(String companionName) =>
    companionAbilities[companionName] ?? _defaultAbility;

// Amount of mana gained per normal attack
const int manaPerAttack = 25;

// ---------------------------------------------------------------------------
// Status effect
// ---------------------------------------------------------------------------

class StatusEffect {
  final String label;
  final Color color;
  final bool isBuffOnCompanions; // true = atk buff, false = boss debuff or dot
  final double atkMultiplierChange; // applied to companion atk if > 0
  final double bossAtkReduction;    // fraction reduction to boss atk
  final int dotDamagePerTurn;       // damage dealt to boss each boss turn
  int turnsLeft;

  StatusEffect({
    required this.label,
    required this.color,
    this.isBuffOnCompanions = false,
    this.atkMultiplierChange = 0,
    this.bossAtkReduction = 0,
    this.dotDamagePerTurn = 0,
    required this.turnsLeft,
  });
}

// ---------------------------------------------------------------------------
// Combat entity
// ---------------------------------------------------------------------------

class CombatEntity {
  final String id;
  final String name;
  final String emoji;
  final bool isCompanion;
  final int baseAtk;
  final int spd;        // internal only — drives ATB, not shown in UI
  final int maxHp;
  final int maxMana;
  final Ability? ability;

  int currentHp;
  int currentMana;
  double gauge = 0;
  List<StatusEffect> statusEffects = [];

  CombatEntity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isCompanion,
    required this.baseAtk,
    required this.spd,
    required this.maxHp,
    this.maxMana = 0,
    this.ability,
  })  : currentHp = maxHp,
        currentMana = 0;

  bool get isAlive => currentHp > 0;

  double get hpFraction => (currentHp / maxHp).clamp(0.0, 1.0);
  double get manaFraction =>
      maxMana > 0 ? (currentMana / maxMana).clamp(0.0, 1.0) : 0.0;

  bool get canUseAbility =>
      ability != null && currentMana >= ability!.manaCost;

  // Effective ATK considering buffs/debuffs
  int get effectiveAtk {
    double mult = 1.0;
    for (final s in statusEffects) {
      if (s.atkMultiplierChange != 0) mult += s.atkMultiplierChange;
      if (s.bossAtkReduction != 0) mult -= s.bossAtkReduction;
    }
    return (baseAtk * mult.clamp(0.1, 5.0)).round();
  }

  void takeDamage(int amount) {
    currentHp = (currentHp - amount).clamp(0, maxHp);
  }

  void heal(int amount) {
    currentHp = (currentHp + amount).clamp(0, maxHp);
  }

  void gainMana(int amount) {
    currentMana = (currentMana + amount).clamp(0, maxMana);
  }

  void spendMana(int amount) {
    currentMana = (currentMana - amount).clamp(0, maxMana);
  }

  void tickStatusEffects() {
    statusEffects.removeWhere((s) {
      s.turnsLeft--;
      return s.turnsLeft <= 0;
    });
  }
}

// ---------------------------------------------------------------------------
// Boss definitions per location
// ---------------------------------------------------------------------------

class BossData {
  final String name;
  final String emoji;
  final int hp;
  final int atk;
  final int spd;
  final Color color;

  const BossData({
    required this.name,
    required this.emoji,
    required this.hp,
    required this.atk,
    required this.spd,
    required this.color,
  });
}

const Map<String, BossData> bossByLocation = {
  'forest': BossData(
    name: 'Forest Guardian', emoji: '🌳',
    hp: 150, atk: 10, spd: 5,
    color: Color(0xFF2E7D32),
  ),
  'library': BossData(
    name: 'Librarian Golem', emoji: '📚',
    hp: 200, atk: 14, spd: 6,
    color: Color(0xFF1565C0),
  ),
  'caves': BossData(
    name: 'Crystal Titan', emoji: '💎',
    hp: 300, atk: 22, spd: 8,
    color: Color(0xFF6A1B9A),
  ),
  'temple': BossData(
    name: 'Sky Warden', emoji: '⛩️',
    hp: 420, atk: 32, spd: 11,
    color: Color(0xFFE65100),
  ),
  'dungeon': BossData(
    name: 'Shadow Lord', emoji: '💀',
    hp: 550, atk: 42, spd: 14,
    color: Color(0xFF37474F),
  ),
};

// ---------------------------------------------------------------------------
// Stat calculation
// ---------------------------------------------------------------------------

/// Returns (maxHp, baseAtk, maxMana) for a companion by rarity + level.
(int, int, int) companionStats(String rarity, int level) {
  switch (rarity) {
    case 'legendary':
      return (100 + level * 15, 25 + level * 4, 100);
    case 'epic':
      return (85 + level * 12, 18 + level * 3, 80);
    case 'rare':
      return (70 + level * 10, 14 + level * 2, 70);
    default:
      return (60 + level * 8, 10 + level * 2, 60);
  }
}

CombatEntity companionToEntity(
    Map<String, dynamic> character, int level) {
  final rarity = character['rarity'] as String;
  final name = character['name'] as String;
  final id = character['id'].toString();

  final (maxHp, baseAtk, maxMana) = companionStats(rarity, level);

  // Speed still drives ATB internally but is not exposed in the UI
  int spd;
  switch (rarity) {
    case 'legendary': spd = 13 + level;
    case 'epic':      spd = 10 + level;
    case 'rare':      spd = 8 + level;
    default:          spd = 6 + level;
  }

  return CombatEntity(
    id: id,
    name: name,
    emoji: _rarityEmoji(rarity),
    isCompanion: true,
    baseAtk: baseAtk,
    spd: spd,
    maxHp: maxHp,
    maxMana: maxMana,
    ability: abilityFor(name),
  );
}

CombatEntity bossToEntity(ExpeditionLocation location) {
  final data = bossByLocation[location.id] ??
      const BossData(name: 'Unknown Boss', emoji: '👾',
          hp: 200, atk: 20, spd: 8, color: Colors.grey);
  return CombatEntity(
    id: 'boss',
    name: data.name,
    emoji: data.emoji,
    isCompanion: false,
    baseAtk: data.atk,
    spd: data.spd,
    maxHp: data.hp,
  );
}

String _rarityEmoji(String rarity) {
  switch (rarity) {
    case 'legendary': return '🌟';
    case 'epic':      return '💜';
    case 'rare':      return '💙';
    default:          return '⚪';
  }
}

Color rarityColor(String rarity) {
  switch (rarity) {
    case 'legendary': return const Color(0xFFFFD700);
    case 'epic':      return const Color(0xFFBF00FF);
    case 'rare':      return const Color(0xFF4169E1);
    default:          return const Color(0xFF9E9E9E);
  }
}
