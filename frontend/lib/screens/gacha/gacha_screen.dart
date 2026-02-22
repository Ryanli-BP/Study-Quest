import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../providers/auth_provider.dart';

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  bool _pulling = false;
  List<dynamic>? _pullResults;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotationAnim;
  late AnimationController _cardsController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _rotationAnim = Tween<double>(
      begin: 1.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _pull(bool isTen) async {
    setState(() {
      _pulling = true;
      _pullResults = null;
    });
    try {
      final result =
          isTen ? await ApiClient.tenPull() : await ApiClient.singlePull();
      await context.read<AuthProvider>().refreshUser();
      setState(() => _pullResults = result['pulls']);
      _controller.forward(from: 0);
      // start staggered card animations
      _cardsController.forward(from: 0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _pulling = false);
    }
  }

  Future<void> _closeResults() async {
    try {
      await Future.wait([_controller.reverse(), _cardsController.reverse()]);
    } catch (_) {}
    setState(() => _pullResults = null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0050), Color(0xFF7B61FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('🌟', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    const Text(
                      'Companion Gacha',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Earn tokens by studying to pull companions!',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(
                          '${auth.tokens} tokens',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pull buttons
              Row(
                children: [
                  Expanded(
                    child: _PullButton(
                      label: 'Single Pull',
                      cost: 50,
                      icon: '🎲',
                      tokens: auth.tokens,
                      loading: _pulling,
                      onTap: () => _pull(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PullButton(
                      label: '10x Pull',
                      cost: 450,
                      icon: '🎰',
                      tokens: auth.tokens,
                      loading: _pulling,
                      onTap: () => _pull(true),
                      highlight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '10x pull = 10 pulls for the price of 9',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Rarity info
              const _RarityInfo(),
              const SizedBox(height: 24),

              // Pull results
            ],
          ),
        ),

        // Overlay popup for pull results
        if (_pullResults != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeResults,
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: RotationTransition(
                      turns: _rotationAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 720,
                            maxHeight: 520,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: GestureDetector(
                              onTap: () {},
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E0F1A),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child:
                                        _pullResults!.length == 1
                                            ? _SinglePullResult(
                                              pull: _pullResults![0],
                                            )
                                            : SizedBox(
                                              width: 680,
                                              height: 420,
                                              child: _TenPullGrid(
                                                pulls: _pullResults!,
                                                cardsAnim: _cardsController,
                                              ),
                                            ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: GestureDetector(
                                      onTap: _closeResults,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
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
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PullButton extends StatelessWidget {
  final String label;
  final int cost;
  final String icon;
  final int tokens;
  final bool loading;
  final VoidCallback onTap;
  final bool highlight;

  const _PullButton({
    required this.label,
    required this.cost,
    required this.icon,
    required this.tokens,
    required this.loading,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = tokens >= cost;
    return GestureDetector(
      onTap: (loading || !canAfford) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient:
              highlight
                  ? const LinearGradient(
                    colors: [Color(0xFF4A3AFF), Color(0xFF7B61FF)],
                  )
                  : null,
          color: highlight ? null : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canAfford ? const Color(0xFF7B61FF) : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: canAfford ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '💎 $cost',
              style: TextStyle(
                color: canAfford ? const Color(0xFFFFD700) : Colors.white38,
                fontSize: 13,
              ),
            ),
            if (!canAfford)
              const Text(
                'Not enough tokens',
                style: TextStyle(color: Colors.red, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

class _RarityInfo extends StatelessWidget {
  const _RarityInfo();

  @override
  Widget build(BuildContext context) {
    const rarities = [
      ('Legendary', Color(0xFFFFD700), '2%'),
      ('Epic', Color(0xFFBF00FF), '10%'),
      ('Rare', Color(0xFF4169E1), '28%'),
      ('Common', Color(0xFF808080), '60%'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drop Rates',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...rarities.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: r.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.$1,
                      style: TextStyle(
                        color: r.$2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    r.$3,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinglePullResult extends StatelessWidget {
  final dynamic pull;
  const _SinglePullResult({required this.pull});

  @override
  Widget build(BuildContext context) {
    final char = pull['character'] as Map<String, dynamic>;
    return _CharacterCard(
      character: char,
      isNew: pull['is_new'] == true,
      large: true,
    );
  }
}

class _TenPullGrid extends StatelessWidget {
  final List<dynamic> pulls;
  final Animation<double> cardsAnim;

  const _TenPullGrid({required this.pulls, required this.cardsAnim});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: pulls.length,
      itemBuilder: (context, i) {
        final pull = pulls[i];
        final char = pull['character'] as Map<String, dynamic>;

        return AnimatedBuilder(
          animation: cardsAnim,
          builder: (context, child) {
            final stagger = 0.08;
            final start = i * stagger;
            final span = max(0.001, 1.0 - (pulls.length - 1) * stagger);
            double prog = ((cardsAnim.value - start) / span).clamp(0.0, 1.0);
            prog = Curves.easeOut.transform(prog);

            final angle = (1 - prog) * pi * 1.5;
            final translateY = (1 - prog) * 40.0;
            final scale = 0.6 + 0.4 * prog;
            final opacity = prog;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () => _showCardDetail(context, pull),
                      child: _CharacterCard(
                        character: char,
                        isNew: pull['is_new'] == true,
                        large: false,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCardDetail(BuildContext context, dynamic pull) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: _SinglePullResult(pull: pull),
          ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final Map<String, dynamic> character;
  final bool isNew;
  final bool large;

  const _CharacterCard({
    required this.character,
    required this.isNew,
    required this.large,
  });

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'epic':
        return const Color(0xFFBF00FF);
      case 'rare':
        return const Color(0xFF4169E1);
      default:
        return const Color(0xFF808080);
    }
  }

  String _rarityEmoji(String rarity) {
    switch (rarity) {
      case 'legendary':
        return '🌟';
      case 'epic':
        return '💜';
      case 'rare':
        return '💙';
      default:
        return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarity = character['rarity'] as String;
    final color = _rarityColor(rarity);

    return Container(
      padding: EdgeInsets.all(large ? 20 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: large ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 12,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final imgW = large ? min(200.0, w * 0.9) : max(40.0, w * 0.6);
          final nameSize = large ? 20.0 : max(10.0, w * 0.12);
          final raritySize = large ? 13.0 : max(8.0, w * 0.08);
          final spacerSmall = large ? 12.0 : 4.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(
                image: AssetImage("assets/images/${character['name']}.png"),
                width: imgW,
                height: imgW,
                fit: BoxFit.contain,
              ),
              SizedBox(height: spacerSmall),
              Text(
                character['name'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: nameSize,
                ),
              ),
              SizedBox(height: large ? 6 : 2),
              Text(
                rarity.toUpperCase(),
                style: TextStyle(color: color, fontSize: raritySize),
              ),
              if (large) ...[
                const SizedBox(height: 12),
                Text(
                  character['description'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (character['subject_affinity'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '📚 ${character['subject_affinity']}',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (!isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Duplicate — Shard obtained',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✨ New Companion!',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
