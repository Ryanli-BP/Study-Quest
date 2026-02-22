import 'package:flutter/material.dart';

class Companion extends StatefulWidget {
  final String imagePath;
  final String text;
  final double textSize;
  const Companion({
    super.key,
    required this.imagePath,
    required this.text,
    this.textSize = 20,
  });

  @override
  State<Companion> createState() => _CompanionState();
}

class _CompanionState extends State<Companion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: const Offset(0, -0.05),
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return // Bottom animated image that slides up/down
    Positioned(
      left: 170,
      bottom: -50,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Stack(
          children: [
            Container(
              width: 240,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: widget.textSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 120.0),
              child: SizedBox(
                width: 150,
                height: 150,
                child: Image.asset(
                  "assets/images/${widget.imagePath}.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
}
