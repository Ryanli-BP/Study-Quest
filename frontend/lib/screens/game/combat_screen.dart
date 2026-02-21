import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/combat.dart';
import '../../providers/expedition_provider.dart';

enum CombatPhase { playerTurn, bossAction, won, lost }

class CombatScreen extends StatefulWidget {
  final String expeditionId;
  final ExpeditionLocation location;
  final List<Map<String, dynamic>> companions;

  const CombatScreen({
    super.key,
    required this.expeditionId,
    required this.location,
    required this.companions,
  });

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen>
    with TickerProviderStateMixin {
  late CombatEntity _boss;
  late List<CombatEntity> _companions;
  late List<CombatEntity> _allEntities;

  CombatPhase _phase = CombatPhase.playerTurn;
  late CombatEntity _currentTurn;
  final List<String> _log = [];
  final Random _rng = Random();

  // Boss shake + flash
  late AnimationController _bossShakeCtrl;
  late Animation<double> _bossShakeAnim;
  late AnimationController _bossFlashCtrl;

  // Companion shake + flash (one at a time)
  late AnimationController _companionShakeCtrl;
  late Animation<double> _companionShakeAnim;
  late AnimationController _companionFlashCtrl;
  String? _shakingCompanionId;

  @override
  void initState() {
    super.initState();
    _bossShakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _bossShakeAnim = _shakeSequence(_bossShakeCtrl);

    _bossFlashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _companionShakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _companionShakeAnim = _shakeSequence(_companionShakeCtrl);

    _companionFlashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _initCombat();
  }

  Animation<double> _shakeSequence(AnimationController ctrl) =>
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _bossShakeCtrl.dispose();
    _bossFlashCtrl.dispose();
    _companionShakeCtrl.dispose();
    _companionFlashCtrl.dispose();
    super.dispose();
  }

  void _initCombat() {
    final expProvider = context.read<ExpeditionProvider>();
    _boss = bossToEntity(widget.location);
    _companions = widget.companions.map((char) {
      final level = expProvider.progressFor(char['id'] as int).level;
      return companionToEntity(char, level);
    }).toList();
    _allEntities = [_boss, ..._companions];
    _log.add('⚔️ Battle begins! Defeat ${_boss.name}!');
    _advanceToNextTurn();
  }

  // ---------------------------------------------------------------------------
  // ATB turn engine
  // ---------------------------------------------------------------------------

  void _advanceToNextTurn() {
    while (true) {
      double minTicks = double.infinity;
      for (final e in _allEntities) {
        if (!e.isAlive) continue;
        final t = (100 - e.gauge) / e.spd;
        if (t < minTicks) minTicks = t;
      }
      for (final e in _allEntities) {
        if (e.isAlive) e.gauge += minTicks * e.spd;
      }
      final ready = _allEntities
          .where((e) => e.isAlive && e.gauge >= 100)
          .toList()
        ..sort((a, b) => b.gauge.compareTo(a.gauge));
      if (ready.isNotEmpty) {
        _currentTurn = ready.first;
        ready.first.gauge -= 100;
        break;
      }
    }
    setState(() {
      if (_currentTurn.isCompanion) {
        _phase = CombatPhase.playerTurn;
      } else {
        _phase = CombatPhase.bossAction;
        Future.delayed(const Duration(milliseconds: 900), _resolveBossTurn);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Player actions
  // ---------------------------------------------------------------------------

  void _playerBasicAttack() {
    if (_phase != CombatPhase.playerTurn) return;
    final dmg = _currentTurn.effectiveAtk;
    _boss.takeDamage(dmg);
    _bossShakeCtrl.forward(from: 0);
    _bossFlashCtrl.forward(from: 0);
    _log.add('${_currentTurn.name} attacks for $dmg damage!');
    _checkAndContinue();
  }

  void _playerUseAbility() {
    if (_phase != CombatPhase.playerTurn) return;
    final ability = _currentTurn.ability;
    if (ability == null) return;

    _log.add('${_currentTurn.name} uses ${ability.emoji} ${ability.name}!');

    if (ability.damageMultiplier > 0) {
      final dmg = (_currentTurn.effectiveAtk * ability.damageMultiplier).round();
      _boss.takeDamage(dmg);
      _bossShakeCtrl.forward(from: 0);
      _bossFlashCtrl.forward(from: 0);
      _log.add('  Dealt $dmg damage!');
    }
    if (ability.healAllAmount > 0) {
      for (final c in _companions.where((c) => c.isAlive)) {
        c.heal(ability.healAllAmount);
      }
      _log.add('  Restored ${ability.healAllAmount} HP to all!');
    }
    if (ability.dotDamage > 0) {
      _boss.statusEffects.add(StatusEffect(
        label: '🔥 ${ability.dotDamage}/turn',
        color: Colors.orange,
        dotDamagePerTurn: ability.dotDamage,
        turnsLeft: ability.dotDuration,
      ));
      _log.add('  ${_boss.name} burning ${ability.dotDamage}/turn!');
    }
    if (ability.atkBuffMultiplier > 0) {
      for (final c in _companions.where((c) => c.isAlive)) {
        c.statusEffects.add(StatusEffect(
          label: '+${(ability.atkBuffMultiplier * 100).round()}% ATK',
          color: Colors.greenAccent,
          isBuffOnCompanions: true,
          atkMultiplierChange: ability.atkBuffMultiplier,
          turnsLeft: ability.buffDuration,
        ));
      }
      _log.add('  Party ATK +${(ability.atkBuffMultiplier * 100).round()}%!');
    }
    if (ability.bossAtkDebuff > 0) {
      _boss.statusEffects.add(StatusEffect(
        label: '⬇ -${(ability.bossAtkDebuff * 100).round()}% ATK',
        color: Colors.cyanAccent,
        bossAtkReduction: ability.bossAtkDebuff,
        turnsLeft: ability.debuffDuration,
      ));
      _log.add('  ${_boss.name} ATK -${(ability.bossAtkDebuff * 100).round()}%!');
    }
    _checkAndContinue();
  }

  // ---------------------------------------------------------------------------
  // Boss turn
  // ---------------------------------------------------------------------------

  void _resolveBossTurn() {
    if (!mounted) return;

    for (final s in _boss.statusEffects.where((s) => s.dotDamagePerTurn > 0)) {
      _boss.takeDamage(s.dotDamagePerTurn);
      _log.add('  🔥 DoT: ${s.dotDamagePerTurn} to ${_boss.name}!');
    }

    if (_boss.isAlive) {
      final targets = _companions.where((c) => c.isAlive).toList();
      if (targets.isNotEmpty) {
        final target = targets[_rng.nextInt(targets.length)];
        final dmg = _boss.effectiveAtk;
        target.takeDamage(dmg);
        _shakingCompanionId = target.id;
        _companionShakeCtrl.forward(from: 0);
        _companionFlashCtrl.forward(from: 0);
        _log.add('${_boss.emoji} ${_boss.name} hits ${target.name} for $dmg!');
      }
      _boss.tickStatusEffects();
    }

    _checkAndContinue();
  }

  // ---------------------------------------------------------------------------
  // Win / lose check
  // ---------------------------------------------------------------------------

  void _checkAndContinue() {
    setState(() {
      if (_boss.currentHp <= 0) {
        _phase = CombatPhase.won;
        _log.add('🎉 Victory! ${_boss.name} defeated!');
        return;
      }
      if (_companions.every((c) => !c.isAlive)) {
        _phase = CombatPhase.lost;
        _log.add('💀 All companions fell...');
        // Immediately mark expedition as failed so it can't be re-entered
        context.read<ExpeditionProvider>().failExpedition(widget.expeditionId);
        return;
      }
      _advanceToNextTurn();
    });
  }

  // ---------------------------------------------------------------------------
  // Turn queue preview
  // ---------------------------------------------------------------------------

  List<CombatEntity> _nextTurns(int count) {
    final gauges = {for (final e in _allEntities) e.id: e.gauge};
    final result = <CombatEntity>[];
    while (result.length < count) {
      final alive = _allEntities.where((e) => e.isAlive).toList();
      if (alive.isEmpty) break;
      double minTicks = double.infinity;
      for (final e in alive) {
        final t = (100 - gauges[e.id]!) / e.spd;
        if (t < minTicks) minTicks = t;
      }
      for (final e in alive) {
        gauges[e.id] = gauges[e.id]! + minTicks * e.spd;
      }
      final ready = alive
          .where((e) => gauges[e.id]! >= 100)
          .toList()
        ..sort((a, b) => gauges[b.id]!.compareTo(gauges[a.id]!));
      if (ready.isNotEmpty) {
        gauges[ready.first.id] = gauges[ready.first.id]! - 100;
        result.add(ready.first);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bossData = bossByLocation[widget.location.id];
    final bossColor = bossData?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A15),
      appBar: AppBar(
        backgroundColor: bossColor.withOpacity(0.25),
        title: Text(
          '⚔️ ${widget.location.name}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Boss — large section
          _BossSection(
            boss: _boss,
            color: bossColor,
            shakeAnim: _bossShakeAnim,
            flashCtrl: _bossFlashCtrl,
          ),

          // Turn queue
          _TurnQueue(turns: _nextTurns(6)),

          const Divider(color: Colors.white12, height: 1),

          // Companion row — expanded to fill remaining space
          Expanded(
            child: _CompanionRow(
              companions: _companions,
              currentTurnId: _phase == CombatPhase.playerTurn
                  ? _currentTurn.id
                  : null,
              shakeAnim: _companionShakeAnim,
              flashCtrl: _companionFlashCtrl,
              shakingId: _shakingCompanionId,
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Combat log
          _CombatLog(log: _log),

          // Action panel
          _ActionPanel(
            phase: _phase,
            currentTurn: _phase == CombatPhase.playerTurn ? _currentTurn : null,
            onAttack: _playerBasicAttack,
            onAbility: _playerUseAbility,
            boss: _boss,
            expeditionId: widget.expeditionId,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Boss section — large and imposing
// ---------------------------------------------------------------------------

class _BossSection extends StatelessWidget {
  final CombatEntity boss;
  final Color color;
  final Animation<double> shakeAnim;
  final AnimationController flashCtrl;

  const _BossSection({
    required this.boss,
    required this.color,
    required this.shakeAnim,
    required this.flashCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shakeAnim, flashCtrl]),
      builder: (_, __) {
        final flash = flashCtrl.value > 0.5
            ? Colors.red.withOpacity(0.45)
            : Colors.transparent;
        return Transform.translate(
          offset: Offset(shakeAnim.value, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border(
                  bottom: BorderSide(color: color.withOpacity(0.3), width: 1)),
            ),
            child: Stack(
              children: [
                if (flash != Colors.transparent)
                  Positioned.fill(
                    child: Container(color: flash),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Boss emoji — large
                    Text(boss.emoji,
                        style: const TextStyle(fontSize: 64)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(boss.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          // HP bar
                          Row(
                            children: [
                              Text(
                                '${boss.currentHp} / ${boss.maxHp} HP',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: boss.hpFraction,
                              backgroundColor: Colors.white12,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                              minHeight: 14,
                            ),
                          ),
                          if (boss.statusEffects.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: boss.statusEffects
                                  .map((s) => _StatusChip(s))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Turn queue
// ---------------------------------------------------------------------------

class _TurnQueue extends StatelessWidget {
  final List<CombatEntity> turns;
  const _TurnQueue({required this.turns});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F20),
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: turns.length,
        itemBuilder: (_, i) {
          final e = turns[i];
          final isCurrent = i == 0;
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF7B61FF).withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF7B61FF)
                    : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(e.name,
                    style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white54,
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Companion row — big cards with stats
// ---------------------------------------------------------------------------

class _CompanionRow extends StatelessWidget {
  final List<CombatEntity> companions;
  final String? currentTurnId;
  final Animation<double> shakeAnim;
  final AnimationController flashCtrl;
  final String? shakingId;

  const _CompanionRow({
    required this.companions,
    required this.currentTurnId,
    required this.shakeAnim,
    required this.flashCtrl,
    required this.shakingId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: companions
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _CompanionCard(
                      companion: c,
                      isActive: c.id == currentTurnId,
                      shakeAnim: shakeAnim,
                      flashCtrl: flashCtrl,
                      isShaking: c.id == shakingId,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final CombatEntity companion;
  final bool isActive;
  final Animation<double> shakeAnim;
  final AnimationController flashCtrl;
  final bool isShaking;

  const _CompanionCard({
    required this.companion,
    required this.isActive,
    required this.shakeAnim,
    required this.flashCtrl,
    required this.isShaking,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shakeAnim, flashCtrl]),
      builder: (_, __) {
        final flash = isShaking && flashCtrl.value > 0.5
            ? Colors.red.withOpacity(0.5)
            : Colors.transparent;
        final shakeOffset = isShaking ? shakeAnim.value : 0.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Opacity(
            opacity: companion.isAlive ? 1.0 : 0.35,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: flash != Colors.transparent
                    ? flash
                    : isActive
                        ? const Color(0xFF7B61FF).withOpacity(0.18)
                        : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF7B61FF)
                      : Colors.white12,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color:
                                const Color(0xFF7B61FF).withOpacity(0.35),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji
                  Text(
                    companion.isAlive ? companion.emoji : '💀',
                    style: const TextStyle(fontSize: 30),
                  ),
                  const SizedBox(height: 6),
                  // Name
                  Text(
                    companion.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Stats
                  _StatRow('❤️', '${companion.currentHp}/${companion.maxHp}'),
                  const SizedBox(height: 2),
                  _StatRow('⚔️', '${companion.effectiveAtk} ATK'),
                  const SizedBox(height: 2),
                  _StatRow('💨', '${companion.spd} SPD'),
                  const SizedBox(height: 8),
                  // HP bar
                  _MiniBar(
                    value: companion.hpFraction,
                    color: companion.hpFraction > 0.5
                        ? Colors.green
                        : companion.hpFraction > 0.25
                            ? Colors.orange
                            : Colors.red,
                    label: 'HP',
                  ),
                  const SizedBox(height: 4),
                  // SPD gauge bar
                  _MiniBar(
                    value: (companion.gauge / 100).clamp(0.0, 1.0),
                    color: const Color(0xFF7B61FF),
                    label: 'SPD',
                  ),
                  // Status effects
                  if (companion.statusEffects.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 3,
                      runSpacing: 2,
                      alignment: WrapAlignment.center,
                      children: companion.statusEffects
                          .map((s) => _StatusChip(s))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String icon;
  final String value;
  const _StatRow(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double value;
  final Color color;
  final String label;
  const _MiniBar(
      {required this.value, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Combat log
// ---------------------------------------------------------------------------

class _CombatLog extends StatelessWidget {
  final List<String> log;
  const _CombatLog({required this.log});

  @override
  Widget build(BuildContext context) {
    final recent = log.length > 3 ? log.sublist(log.length - 3) : log;
    return Container(
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      height: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recent
            .asMap()
            .entries
            .map((e) => Text(
                  e.value,
                  style: TextStyle(
                    color: e.key == recent.length - 1
                        ? Colors.white
                        : Colors.white38,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action panel
// ---------------------------------------------------------------------------

class _ActionPanel extends StatelessWidget {
  final CombatPhase phase;
  final CombatEntity? currentTurn;
  final VoidCallback onAttack;
  final VoidCallback onAbility;
  final CombatEntity boss;
  final String expeditionId;

  const _ActionPanel({
    required this.phase,
    required this.currentTurn,
    required this.onAttack,
    required this.onAbility,
    required this.boss,
    required this.expeditionId,
  });

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case CombatPhase.playerTurn:
        return _PlayerActions(
            entity: currentTurn!, onAttack: onAttack, onAbility: onAbility);
      case CombatPhase.bossAction:
        return _BossActionPanel(bossName: boss.name);
      case CombatPhase.won:
        return _WonPanel(expeditionId: expeditionId);
      case CombatPhase.lost:
        return const _LostPanel();
    }
  }
}

class _PlayerActions extends StatelessWidget {
  final CombatEntity entity;
  final VoidCallback onAttack;
  final VoidCallback onAbility;

  const _PlayerActions(
      {required this.entity, required this.onAttack, required this.onAbility});

  @override
  Widget build(BuildContext context) {
    final ability = entity.ability;
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${entity.emoji} ${entity.name}'s turn",
              style: const TextStyle(
                  color: Color(0xFF7B61FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: '⚔️ Attack',
                  subtitle: '${entity.effectiveAtk} dmg',
                  color: Colors.blueGrey,
                  onTap: onAttack,
                ),
              ),
              const SizedBox(width: 10),
              if (ability != null)
                Expanded(
                  child: _ActionBtn(
                    label: '${ability.emoji} ${ability.name}',
                    subtitle: ability.description,
                    color: const Color(0xFF7B61FF),
                    onTap: onAbility,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _BossActionPanel extends StatelessWidget {
  final String bossName;
  const _BossActionPanel({required this.bossName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A0A0A),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('💀', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Text('$bossName is acting...',
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const Spacer(),
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.redAccent)),
        ],
      ),
    );
  }
}

class _WonPanel extends StatefulWidget {
  final String expeditionId;
  const _WonPanel({required this.expeditionId});

  @override
  State<_WonPanel> createState() => _WonPanelState();
}

class _WonPanelState extends State<_WonPanel> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    final rewards = await context
        .read<ExpeditionProvider>()
        .claimRewards(widget.expeditionId);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 Victory!',
            style: TextStyle(color: Colors.white, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rewards collected:',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            _RewardRow('🪙 Coins', '${rewards['coins']}'),
            _RewardRow('🪨 Materials', '${rewards['materials']}'),
            _RewardRow('⭐ XP per companion', '${rewards['xp']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context)
                ..pop()
                ..pop();
            },
            child: const Text('Back to Island',
                style: TextStyle(color: Color(0xFF7B61FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1A0A),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _claiming ? null : _claim,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _claiming
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('🎉 Claim Victory Rewards',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
        ),
      ),
    );
  }
}

class _LostPanel extends StatelessWidget {
  const _LostPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A0A0A),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade900,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('💀 Expedition Failed — Return',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final StatusEffect effect;
  const _StatusChip(this.effect);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: effect.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effect.color.withOpacity(0.5)),
      ),
      child: Text('${effect.label} ${effect.turnsLeft}t',
          style: TextStyle(color: effect.color, fontSize: 10)),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String label;
  final String value;
  const _RewardRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
