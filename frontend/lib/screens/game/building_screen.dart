import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expedition_provider.dart';
import 'base_game_screen.dart';
import 'hospital_screen.dart';
import 'blacksmith_screen.dart';
import 'lab_screen.dart';

class BuildingScreen extends StatefulWidget {
  final BuildingDef def;
  const BuildingScreen({super.key, required this.def});

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  // 0 = Info, 1 = Upgrade, 2 = Function
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpeditionProvider>();
    final level = provider.buildingLevel(widget.def.id);
    final materials = provider.materials;
    final def = widget.def;
    final isMax = level >= def.maxLevel;
    final upgradeCost = isMax ? 0 : def.upgradeCosts[level - 1];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Text(def.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name,
                      style: TextStyle(
                          color: def.color,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Level $level${isMax ? ' (MAX)' : ''}',
                      style: TextStyle(
                          color: def.color.withOpacity(0.7), fontSize: 13)),
                ],
              ),
              const Spacer(),
              // Materials display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.brown.shade300.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Text('🪨', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text('$materials',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab buttons
          Row(
            children: [
              _TabBtn(label: '📋 Info', selected: _tab == 0,
                  color: def.color, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _TabBtn(label: '⬆️ Upgrade', selected: _tab == 1,
                  color: def.color, onTap: () => setState(() => _tab = 1)),
              if (def.hasFunction) ...[
                const SizedBox(width: 8),
                _TabBtn(
                  label: '⚙️ ${def.functionLabel}',
                  selected: _tab == 2,
                  color: def.color,
                  onTap: () => _openFunctionScreen(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Tab content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _tab == 0
                ? _InfoContent(def: def, level: level)
                : _UpgradeContent(
                    def: def,
                    level: level,
                    isMax: isMax,
                    upgradeCost: upgradeCost,
                    materials: materials,
                    onUpgrade: () => _upgrade(context, provider, upgradeCost),
                  ),
          ),
        ],
      ),
    );
  }

  void _upgrade(BuildContext context, ExpeditionProvider provider, int cost) {
    final success = provider.upgradeBuilding(
        widget.def.id, cost, widget.def.maxLevel);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? '✅ ${widget.def.name} upgraded to Lv.${provider.buildingLevel(widget.def.id)}!'
          : '❌ Not enough materials!'),
      backgroundColor:
          success ? const Color(0xFF7B61FF) : Colors.red.shade800,
      duration: const Duration(seconds: 2),
    ));
  }

  void _openFunctionScreen(BuildContext context) {
    Navigator.of(context).pop(); // close sheet first
    Widget screen;
    switch (widget.def.id) {
      case 'hospital':
        screen = const HospitalScreen();
      case 'blacksmith':
        screen = const BlacksmithScreen();
      case 'lab':
        screen = const LabScreen();
      default:
        return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ---------------------------------------------------------------------------
// Tab button
// ---------------------------------------------------------------------------

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : Colors.white54,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info content
// ---------------------------------------------------------------------------

class _InfoContent extends StatelessWidget {
  final BuildingDef def;
  final int level;
  const _InfoContent({required this.def, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('info'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current: ${def.levelPerks[level - 1]}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.5)),
          if (level < def.maxLevel) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            Text('Next level: ${def.levelPerks[level]}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upgrade content
// ---------------------------------------------------------------------------

class _UpgradeContent extends StatelessWidget {
  final BuildingDef def;
  final int level;
  final bool isMax;
  final int upgradeCost;
  final int materials;
  final VoidCallback onUpgrade;

  const _UpgradeContent({
    required this.def,
    required this.level,
    required this.isMax,
    required this.upgradeCost,
    required this.materials,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    if (isMax) {
      return Container(
        key: const ValueKey('upgrade'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          children: [
            Text('🏆', style: TextStyle(fontSize: 36)),
            SizedBox(height: 8),
            Text('Maximum level reached!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
      );
    }

    final canAfford = materials >= upgradeCost;

    return Container(
      key: const ValueKey('upgrade'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Lv.$level', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, color: Colors.white38, size: 18),
              ),
              Text('Lv.${level + 1}',
                  style: TextStyle(
                      color: def.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(def.levelPerks[level],
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('🪨 Cost: ', style: TextStyle(color: Colors.white54)),
              Text('$upgradeCost materials',
                  style: TextStyle(
                      color: canAfford ? Colors.white : Colors.red,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('You have: $materials',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canAfford ? onUpgrade : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford ? def.color : Colors.white12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                canAfford ? '⬆️ Upgrade for $upgradeCost 🪨' : '❌ Not enough materials',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
