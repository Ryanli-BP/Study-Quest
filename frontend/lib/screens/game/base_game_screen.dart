import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../providers/expedition_provider.dart';
import 'expedition_map_screen.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _Building {
  final String name;
  final String emoji;
  final Color color;
  final double x, y, w, h;

  const _Building({
    required this.name,
    required this.emoji,
    required this.color,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class _CompanionState {
  final Map<String, dynamic> character;
  double x;
  double y;

  _CompanionState({required this.character, required this.x, required this.y});
}

// ---------------------------------------------------------------------------
// Fixed building layout on a 900x680 canvas
// ---------------------------------------------------------------------------

const List<_Building> _buildings = [
  _Building(
    name: 'Town Hall', emoji: '🏰', color: Color(0xFF8B5E3C),
    x: 365, y: 250, w: 160, h: 130,
  ),
  _Building(
    name: 'Barracks', emoji: '⚔️', color: Color(0xFF7B2D2D),
    x: 60, y: 70, w: 130, h: 100,
  ),
  _Building(
    name: 'Library', emoji: '📚', color: Color(0xFF2D4A7B),
    x: 700, y: 70, w: 130, h: 100,
  ),
  _Building(
    name: 'Storage', emoji: '🪙', color: Color(0xFF7B6B2D),
    x: 60, y: 510, w: 120, h: 90,
  ),
  _Building(
    name: 'Workshop', emoji: '🔧', color: Color(0xFF4A4A4A),
    x: 715, y: 510, w: 120, h: 90,
  ),
  _Building(
    name: 'Garden', emoji: '🌿', color: Color(0xFF2D6B3A),
    x: 390, y: 60, w: 110, h: 80,
  ),
  _Building(
    name: 'Fountain', emoji: '⛲', color: Color(0xFF2D5A7B),
    x: 390, y: 440, w: 110, h: 90,
  ),
];

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
    // Move companions every 3 seconds
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
      // No companions yet, or offline
    } finally {
      setState(() => _loading = false);
    }
  }

  Offset _randomOpenPos() {
    // Keep companions in the open grassy areas, away from edge
    return Offset(
      80 + _rng.nextDouble() * (_canvasW - 160),
      80 + _rng.nextDouble() * (_canvasH - 160),
    );
  }

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
    final expeditions = context.watch<ExpeditionProvider>().active;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExpeditionMapScreen())),
        backgroundColor: const Color(0xFF7B61FF),
        icon: const Text('⚔️', style: TextStyle(fontSize: 18)),
        label: const Text('New Expedition',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                if (_companions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF7B61FF).withOpacity(0.5)),
                    ),
                    child: Text('🐾 ${_companions.length} companions',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ),
              ],
            ),
          ),

          // Hint
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Pinch to zoom • Drag to pan',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(height: 10),

          // Canvas
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7B61FF)))
                : InteractiveViewer(
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
                                border:
                                    Border.all(color: Colors.white12, width: 2),
                              ),
                            ),

                            // Subtle grid
                            CustomPaint(
                              size: const Size(_canvasW, _canvasH),
                              painter: _GridPainter(),
                            ),

                            // Path between buildings (decorative)
                            CustomPaint(
                              size: const Size(_canvasW, _canvasH),
                              painter: _PathPainter(),
                            ),

                            // Buildings
                            for (final b in _buildings)
                              Positioned(
                                left: b.x,
                                top: b.y,
                                child: _BuildingWidget(building: b),
                              ),

                            // Companions
                            for (final c in _companions)
                              AnimatedPositioned(
                                duration: const Duration(
                                    milliseconds: 2500),
                                curve: Curves.easeInOut,
                                left: c.x - 18,
                                top: c.y - 18,
                                child: _CompanionDot(
                                  name: c.character['name'] ?? '?',
                                  color: _rarityColor(
                                      c.character['rarity'] ?? 'common'),
                                ),
                              ),

                            // Empty state overlay
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
                                            style:
                                                TextStyle(fontSize: 36)),
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
                                                fontSize: 13)),
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
          ),
          const SizedBox(height: 8),

          // Active expeditions
          if (expeditions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Active Expeditions',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: expeditions.length,
                itemBuilder: (context, i) =>
                    _ExpeditionCard(expedition: expeditions[i]),
              ),
            ),
            const SizedBox(height: 80), // FAB clearance
          ] else
            const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building widget
// ---------------------------------------------------------------------------

class _BuildingWidget extends StatelessWidget {
  final _Building building;
  const _BuildingWidget({required this.building});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInfo(context),
      child: Container(
        width: building.w,
        height: building.h,
        decoration: BoxDecoration(
          color: building.color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: building.color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: building.color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(building.emoji,
                style:
                    TextStyle(fontSize: building.w > 140 ? 36 : 28)),
            const SizedBox(height: 4),
            Text(building.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4)
                    ])),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${building.emoji} ${building.name}'),
        duration: const Duration(seconds: 1),
        backgroundColor: building.color,
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
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
      ..moveTo(125, 120)   // from Barracks
      ..quadraticBezierTo(250, 200, 365, 315)  // to Town Hall
      ..moveTo(765, 120)   // from Library
      ..quadraticBezierTo(630, 200, 525, 315)  // to Town Hall
      ..moveTo(120, 555)   // from Storage
      ..quadraticBezierTo(240, 480, 365, 380)  // to Town Hall bottom
      ..moveTo(775, 555)   // from Workshop
      ..quadraticBezierTo(650, 480, 530, 380); // to Town Hall bottom

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---------------------------------------------------------------------------
// Expedition card (shown below island canvas)
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
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
                      border:
                          Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: const Text('⚡ Instant',
                        style: TextStyle(color: Colors.orange, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _claim(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Claim Rewards! 🎉',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claim(BuildContext context) async {
    final rewards = await context
        .read<ExpeditionProvider>()
        .claimRewards(expedition.id);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${expedition.location.emoji} Expedition Complete!',
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RewardRow('🪙 Coins', '${rewards['coins']}'),
              _RewardRow('🪨 Materials', '${rewards['materials']}'),
              _RewardRow('⭐ XP per companion', '${rewards['xp']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nice!',
                  style: TextStyle(color: Color(0xFF7B61FF))),
            ),
          ],
        ),
      );
    }
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
