import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../providers/expedition_provider.dart';
import 'building_screen.dart';
import 'combat_screen.dart';
import 'expedition_map_screen.dart';

// ---------------------------------------------------------------------------
// Building definition
// ---------------------------------------------------------------------------

class BuildingDef {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final double x, y, w, h;
  final bool hasFunction;
  final String functionLabel;
  final List<String> levelPerks; // index 0 = lv1 perk, etc.
  final List<int> upgradeCosts;  // cost to go lv1→2, 2→3, 3→4, 4→5
  final int maxLevel;

  const BuildingDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.hasFunction = false,
    this.functionLabel = 'Open',
    required this.levelPerks,
    required this.upgradeCosts,
    this.maxLevel = 5,
  });
}

const List<BuildingDef> buildings = [
  BuildingDef(
    id: 'town_hall',
    name: 'Town Hall',
    emoji: '🏰',
    color: Color(0xFF8B5E3C),
    x: 365, y: 265, w: 170, h: 135,
    hasFunction: false,
    levelPerks: [
      'Lv1 — 4 companion slots · Level cap 10',
      'Lv2 — 6 companion slots · Level cap 20',
      'Lv3 — 8 companion slots · Level cap 30',
      'Lv4 — 10 companion slots · Level cap 40',
      'Lv5 — 12 companion slots · Level cap 50 (MAX)',
    ],
    upgradeCosts: [5, 12, 25, 50],
  ),
  BuildingDef(
    id: 'hospital',
    name: 'Hospital',
    emoji: '🏥',
    color: Color(0xFF2E7D32),
    x: 70, y: 175, w: 145, h: 115,
    hasFunction: true,
    functionLabel: 'Treat',
    levelPerks: [
      'Lv1 — Treat companions to restore vitality (+50 XP each)',
      'Lv2 — Enhanced recovery (+80 XP per treatment)',
      'Lv3 — Advanced care (+120 XP per treatment)',
      'Lv4 — Expert staff (+160 XP per treatment)',
      'Lv5 — Miraculous care (+200 XP per treatment) (MAX)',
    ],
    upgradeCosts: [5, 12, 25, 50],
  ),
  BuildingDef(
    id: 'blacksmith',
    name: 'Blacksmith',
    emoji: '⚒️',
    color: Color(0xFF546E7A),
    x: 685, y: 175, w: 145, h: 115,
    hasFunction: true,
    functionLabel: 'Forge',
    levelPerks: [
      'Lv1 — Basic forge · Craft common equipment',
      'Lv2 — Improved furnace · Craft rare equipment',
      'Lv3 — Master forge · Craft epic equipment',
      'Lv4 — Legendary crucible · Craft legendary gear',
      'Lv5 — Divine anvil · Forge mythic weapons (MAX)',
    ],
    upgradeCosts: [5, 12, 25, 50],
  ),
  BuildingDef(
    id: 'lab',
    name: 'Lab',
    emoji: '🔬',
    color: Color(0xFF6A1B9A),
    x: 375, y: 475, w: 145, h: 110,
    hasFunction: true,
    functionLabel: 'Evolve',
    levelPerks: [
      'Lv1 — Basic experiments · Evolve companions at Lv5+ (15 materials)',
      'Lv2 — Advanced research · Evolve companions at Lv3+ (12 materials)',
      'Lv3 — Breakthrough · Evolve companions at Lv2+ (10 materials)',
      'Lv4 — Master lab · Reduced cost: 8 materials',
      'Lv5 — Quantum lab · Unlock special evolutions (MAX)',
    ],
    upgradeCosts: [5, 12, 25, 50],
  ),
];

// ---------------------------------------------------------------------------
// Companion roaming state
// ---------------------------------------------------------------------------

class _CompanionState {
  final Map<String, dynamic> character;
  double x;
  double y;
  _CompanionState({required this.character, required this.x, required this.y});
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class BaseGameScreen extends StatefulWidget {
  const BaseGameScreen({super.key});

  @override
  State<BaseGameScreen> createState() => _BaseGameScreenState();
}

class _BaseGameScreenState extends State<BaseGameScreen> {
  static const double _canvasW = 900;
  static const double _canvasH = 680;

  final Random _rng = Random();
  List<_CompanionState> _companions = [];
  Timer? _moveTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanions();
    _moveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _scatter());
    });
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCompanions() async {
    try {
      final collection = await ApiClient.getCollection();
      final Map<int, Map<String, dynamic>> unique = {};
      for (final uc in collection) {
        final char = uc['character'] as Map<String, dynamic>;
        unique[char['id'] as int] = char;
      }
      setState(() {
        _companions = unique.values.map((char) {
          final pos = _randomOpenPos();
          return _CompanionState(character: char, x: pos.dx, y: pos.dy);
        }).toList();
      });
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  Offset _randomOpenPos() => Offset(
        80 + _rng.nextDouble() * (_canvasW - 160),
        80 + _rng.nextDouble() * (_canvasH - 160),
      );

  void _scatter() {
    for (final c in _companions) {
      final pos = _randomOpenPos();
      c.x = pos.dx;
      c.y = pos.dy;
    }
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFBF00FF);
      case 'rare':      return const Color(0xFF4169E1);
      default:          return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpeditionProvider>();
    final expeditions = provider.active;
    final materials = provider.materials;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExpeditionMapScreen()),
        ),
        backgroundColor: const Color(0xFF7B61FF),
        icon: const Text('⚔️', style: TextStyle(fontSize: 18)),
        label: const Text('New Expedition',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('🏝️ Your Island',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                // Materials counter
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.brown.shade300.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      const Text('🪨', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 5),
                      Text('$materials',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Tap a building to manage it',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(height: 10),

          // Canvas + expedition overlay
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7B61FF)))
                : Stack(
                    children: [
                      // Island canvas
                      InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(100),
                        minScale: 0.4,
                        maxScale: 2.5,
                        child: Center(
                          child: SizedBox(
                            width: _canvasW,
                            height: _canvasH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Ground
                                Container(
                                  width: _canvasW,
                                  height: _canvasH,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B3A1B),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white12, width: 2),
                                  ),
                                ),
                                CustomPaint(
                                  size: const Size(_canvasW, _canvasH),
                                  painter: _GridPainter(),
                                ),
                                CustomPaint(
                                  size: const Size(_canvasW, _canvasH),
                                  painter: _PathPainter(),
                                ),
                                // Buildings
                                for (final b in buildings)
                                  Positioned(
                                    left: b.x,
                                    top: b.y,
                                    child: _BuildingWidget(
                                      def: b,
                                      level: provider.buildingLevel(b.id),
                                      onTap: () => _openBuilding(b),
                                    ),
                                  ),
                                // Companions
                                for (final c in _companions)
                                  AnimatedPositioned(
                                    duration:
                                        const Duration(milliseconds: 2500),
                                    curve: Curves.easeInOut,
                                    left: c.x - 18,
                                    top: c.y - 18,
                                    child: _CompanionDot(
                                      name: c.character['name'] ?? '?',
                                      color: _rarityColor(
                                          c.character['rarity'] ?? 'common'),
                                    ),
                                  ),
                                if (_companions.isEmpty)
                                  Positioned.fill(
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('🐾',
                                                style: TextStyle(
                                                    fontSize: 36)),
                                            SizedBox(height: 8),
                                            Text('No companions yet',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            SizedBox(height: 4),
                                            Text(
                                              'Pull from Gacha to populate\nyour island!',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Expedition overlay
                      if (expeditions.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF0D0D1A).withOpacity(0.92),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                                  child: Text('Active Expeditions',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ),
                                SizedBox(
                                  height: 140,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 12),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: expeditions.length,
                                    itemBuilder: (context, i) =>
                                        _ExpeditionCard(
                                            expedition: expeditions[i]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }

  void _openBuilding(BuildingDef def) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuildingScreen(def: def),
    );
  }
}

// ---------------------------------------------------------------------------
// Building widget
// ---------------------------------------------------------------------------

class _BuildingWidget extends StatelessWidget {
  final BuildingDef def;
  final int level;
  final VoidCallback onTap;

  const _BuildingWidget(
      {required this.def, required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: def.w,
        height: def.h,
        decoration: BoxDecoration(
          color: def.color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: def.color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
                color: def.color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(def.emoji,
                style:
                    TextStyle(fontSize: def.w > 155 ? 36 : 28)),
            const SizedBox(height: 4),
            Text(def.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4)
                  ],
                )),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Lv.$level',
                  style: TextStyle(
                      color: def.color == const Color(0xFF8B5E3C)
                          ? Colors.orange.shade200
                          : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Companion dot
// ---------------------------------------------------------------------------

class _CompanionDot extends StatelessWidget {
  final String name;
  final Color color;
  const _CompanionDot({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            width: 48,
            height: 48,
            image: AssetImage('assets/images/$name.png'),
          ),
          const SizedBox(height: 2),
          Text(name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.withOpacity(0.25)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(142, 232)  // Hospital → Town Hall
      ..quadraticBezierTo(260, 260, 365, 330)
      ..moveTo(758, 232)  // Blacksmith → Town Hall
      ..quadraticBezierTo(640, 260, 535, 330)
      ..moveTo(447, 475)  // Lab → Town Hall
      ..quadraticBezierTo(447, 420, 447, 395);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---------------------------------------------------------------------------
// Expedition card
// ---------------------------------------------------------------------------

class _ExpeditionCard extends StatelessWidget {
  final ActiveExpedition expedition;
  const _ExpeditionCard({required this.expedition});

  @override
  Widget build(BuildContext context) {
    final loc = expedition.location;
    final finished = expedition.completed;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: finished
              ? Colors.greenAccent.withOpacity(0.6)
              : loc.color.withOpacity(0.5),
          width: finished ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(loc.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(loc.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '🐾 ${expedition.companions.map((c) => c['name']).join(', ')}',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (!finished) ...[
            LinearProgressIndicator(
              value: expedition.progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(loc.color),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('⏱ ${expedition.remainingLabel}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
                GestureDetector(
                  onTap: () => context
                      .read<ExpeditionProvider>()
                      .instantComplete(expedition.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: const Text('⚡ Instant',
                        style: TextStyle(
                            color: Colors.orange, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CombatScreen(
                      expeditionId: expedition.id,
                      location: expedition.location,
                      companions: expedition.companions,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('⚔️ Enter Battle!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
