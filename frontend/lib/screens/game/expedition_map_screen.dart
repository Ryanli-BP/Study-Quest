import 'package:flutter/material.dart';
import '../../providers/expedition_provider.dart';
import 'companion_select_screen.dart';

class ExpeditionMapScreen extends StatelessWidget {
  const ExpeditionMapScreen({super.key});

  static const double _canvasW = 900;
  static const double _canvasH = 580;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Choose Expedition',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text('Select a destination',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Tap a location to send companions there',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(80),
              minScale: 0.5,
              maxScale: 2.0,
              child: Center(
                child: SizedBox(
                  width: _canvasW,
                  height: _canvasH,
                  child: Stack(
                    children: [
                      // Background terrain
                      CustomPaint(
                        size: const Size(_canvasW, _canvasH),
                        painter: _WorldMapPainter(),
                      ),

                      // Paths between home and locations
                      CustomPaint(
                        size: const Size(_canvasW, _canvasH),
                        painter: _PathsPainter(),
                      ),

                      // Home base marker
                      const Positioned(
                        left: 420,
                        top: 360,
                        child: _HomeMarker(),
                      ),

                      // Location nodes
                      for (final loc in expeditionLocations)
                        Positioned(
                          left: loc.mapX - 40,
                          top: loc.mapY - 40,
                          child: _LocationNode(
                            location: loc,
                            onTap: () => _onLocationTap(context, loc),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _onLocationTap(BuildContext context, ExpeditionLocation location) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CompanionSelectScreen(location: location),
    ));
  }
}

// ---------------------------------------------------------------------------
// Location node widget
// ---------------------------------------------------------------------------

class _LocationNode extends StatelessWidget {
  final ExpeditionLocation location;
  final VoidCallback onTap;

  const _LocationNode({required this.location, required this.onTap});

  Color get _difficultyColor {
    switch (location.difficulty) {
      case 'Easy':   return Colors.green;
      case 'Medium': return Colors.orange;
      case 'Hard':   return Colors.red;
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: location.color.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: location.color.withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(location.emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 4),
            Text(location.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _difficultyColor.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _difficultyColor.withOpacity(0.6), width: 1),
              ),
              child: Text(location.difficulty,
                  style: TextStyle(color: _difficultyColor, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF7B61FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7B61FF).withOpacity(0.5),
                  blurRadius: 12)
            ],
          ),
          child: const Center(
              child: Text('🏠', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(height: 2),
        const Text('Home',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ocean background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D2137),
    );

    // Main landmass
    final landPaint = Paint()..color = const Color(0xFF1B3A1B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(60, 40, size.width - 120, size.height - 80),
        const Radius.circular(30),
      ),
      landPaint,
    );

    // Forest biome (top-left)
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(180, 220), width: 200, height: 160),
      Paint()..color = const Color(0xFF1B4A1B),
    );

    // Library biome (top-center)
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(400, 130), width: 180, height: 120),
      Paint()..color = const Color(0xFF1A2E4A),
    );

    // Crystal biome (right)
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(700, 220), width: 200, height: 180),
      Paint()..color = const Color(0xFF2A1A4A),
    );

    // Temple biome (bottom-right)
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(760, 430), width: 180, height: 150),
      Paint()..color = const Color(0xFF3A1A0A),
    );

    // Dungeon biome (bottom-left)
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(200, 480), width: 200, height: 150),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // Subtle grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PathsPainter extends CustomPainter {
  static const home = Offset(446, 386);

  static const destinations = [
    Offset(180, 200), // forest
    Offset(420, 90),  // library
    Offset(720, 180), // caves
    Offset(800, 420), // temple
    Offset(220, 470), // dungeon
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final dest in destinations) {
      // Dashed line
      _drawDashed(canvas, home, dest, paint);
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 8.0;
    const gapLen = 6.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = (b - a).distance;
    double drawn = 0;
    while (drawn < dist) {
      final t1 = drawn / dist;
      final t2 = ((drawn + dashLen) / dist).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(a.dx + dx * t1, a.dy + dy * t1),
        Offset(a.dx + dx * t2, a.dy + dy * t2),
        paint,
      );
      drawn += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
