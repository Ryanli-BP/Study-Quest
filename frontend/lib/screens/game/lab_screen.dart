import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../providers/expedition_provider.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  List<Map<String, dynamic>> _companions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await ApiClient.getCollection();
      final Map<int, Map<String, dynamic>> unique = {};
      for (final uc in raw) {
        final char = uc['character'] as Map<String, dynamic>;
        unique[char['id'] as int] = char;
      }
      setState(() => _companions = unique.values.toList());
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  int _evolutionCost(int labLevel) {
    const costs = [15, 12, 10, 8, 8];
    return costs[(labLevel - 1).clamp(0, 4)];
  }

  int _minLevel(int labLevel) {
    const mins = [5, 3, 2, 2, 1];
    return mins[(labLevel - 1).clamp(0, 4)];
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFBF00FF);
      case 'rare':      return const Color(0xFF4169E1);
      default:          return const Color(0xFF9E9E9E);
    }
  }

  String _nextRarity(String rarity) {
    switch (rarity) {
      case 'common':    return 'rare';
      case 'rare':      return 'epic';
      case 'epic':      return 'legendary';
      default:          return rarity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpeditionProvider>();
    final labLevel = provider.buildingLevel('lab');
    final materials = provider.materials;
    final evolveCost = _evolutionCost(labLevel);
    final minLevel = _minLevel(labLevel);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('🔬 Lab',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF6A1B9A).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lab Lv.$labLevel',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              'Evolve companions (Lv.$minLevel+) for $evolveCost 🪨 · Boosts XP and upgrades rarity',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_companions.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No companions to evolve.',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _companions.length,
                      itemBuilder: (context, i) {
                        final char = _companions[i];
                        final id = char['id'] as int;
                        final prog = provider.progressFor(id);
                        final rarity = char['rarity'] as String;
                        final color = _rarityColor(rarity);
                        final isMaxRarity = rarity == 'legendary';
                        final meetsLevel = prog.level >= minLevel;
                        final canAfford = materials >= evolveCost;
                        final canEvolve =
                            meetsLevel && canAfford && !isMaxRarity;
                        final next = _nextRarity(rarity);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: canEvolve
                                    ? color.withOpacity(0.6)
                                    : Colors.white12),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: Image.asset(
                                  'assets/images/${char['name']}.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Text(
                                      '🐾',
                                      style: TextStyle(fontSize: 32)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(char['name'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                color.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            rarity.toUpperCase(),
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                            'Lv.${prog.level}  •  ${prog.xp}/${prog.xpToNext} XP',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11)),
                                      ],
                                    ),
                                    if (!meetsLevel && !isMaxRarity) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Needs Lv.$minLevel to evolve',
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (isMaxRarity)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFFFD700).withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFFFD700)
                                            .withOpacity(0.4)),
                                  ),
                                  child: const Text('MAX\n🌟',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Color(0xFFFFD700),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                )
                              else
                                ElevatedButton(
                                  onPressed: canEvolve
                                      ? () => _evolve(
                                          context,
                                          provider,
                                          char,
                                          id,
                                          evolveCost,
                                          next,
                                          color)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canEvolve
                                        ? const Color(0xFF6A1B9A)
                                        : Colors.white12,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                  child: Text(
                                    'Evolve\n$evolveCost 🪨',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  void _evolve(
    BuildContext context,
    ExpeditionProvider provider,
    Map<String, dynamic> char,
    int id,
    int cost,
    String nextRarity,
    Color color,
  ) {
    if (!provider.spendMaterials(cost)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ Not enough materials!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Grant large XP boost as the evolution reward
    provider.addXpToCompanion(id, 150);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('✨ ${char['name']} Evolved!',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(
                'assets/images/${char['name']}.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Text('✨', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14),
                children: [
                  TextSpan(text: '${char['name']} '),
                  TextSpan(
                    text: '+150 XP',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text: ' boost from the evolution process!'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!',
                style: TextStyle(color: Color(0xFF7B61FF))),
          ),
        ],
      ),
    );
  }
}
