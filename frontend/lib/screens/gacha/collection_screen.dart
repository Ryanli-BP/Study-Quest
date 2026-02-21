import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../models/combat.dart';
import '../../providers/expedition_provider.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<dynamic> _collection = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _collection = await ApiClient.getCollection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFBF00FF);
      case 'rare':      return const Color(0xFF4169E1);
      default:          return const Color(0xFF808080);
    }
  }

  String _rarityEmoji(String rarity) {
    switch (rarity) {
      case 'legendary': return '🌟';
      case 'epic':      return '💜';
      case 'rare':      return '💙';
      default:          return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B61FF)));
    }

    if (_collection.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐾', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('No companions yet',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            SizedBox(height: 8),
            Text('Pull from the gacha to get companions!',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // Deduplicate by character id
    final Map<int, Map<String, dynamic>> unique = {};
    final Map<int, int> counts = {};
    for (final uc in _collection) {
      final char = uc['character'] as Map<String, dynamic>;
      final id = char['id'] as int;
      unique[id] = char;
      counts[id] = (counts[id] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${unique.length} Companions Collected',
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                itemCount: unique.length,
                itemBuilder: (context, i) {
                  final char = unique.values.elementAt(i);
                  final rarity = char['rarity'] as String;
                  final color = _rarityColor(rarity);
                  final count = counts[char['id']] ?? 1;

                  return GestureDetector(
                    onTap: () => _showDetail(context, char),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.6)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: Image.asset(
                              'assets/images/${char['name']}.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text(
                                _rarityEmoji(rarity),
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              char['name'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(rarity.toUpperCase(),
                              style: TextStyle(color: color, fontSize: 9)),
                          const SizedBox(height: 4),
                          Builder(builder: (ctx) {
                            final prog = ctx
                                .watch<ExpeditionProvider>()
                                .progressFor(char['id'] as int);
                            return Column(
                              children: [
                                Text('Lv.${prog.level}',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 44,
                                  child: LinearProgressIndicator(
                                    value: prog.xpFraction,
                                    backgroundColor: Colors.white12,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                    borderRadius: BorderRadius.circular(3),
                                    minHeight: 3,
                                  ),
                                ),
                              ],
                            );
                          }),
                          if (count > 1) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('x$count',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> char) {
    final rarity = char['rarity'] as String;
    final color = _rarityColor(rarity);
    final ability = abilityFor(char['name'] as String);

    final level = context
        .read<ExpeditionProvider>()
        .progressFor(char['id'] as int)
        .level;

    final (maxHp, baseAtk, maxMana) = companionStats(rarity, level);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: avatar + name + level badge
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(
                    'assets/images/${char['name']}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      _rarityEmoji(rarity),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(char['name'] ?? '',
                        style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text(rarity.toUpperCase(),
                        style: TextStyle(
                            color: color.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text('Lv.$level',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stat boxes
            Row(
              children: [
                _StatBox(icon: '❤️', label: 'HP', value: '$maxHp'),
                const SizedBox(width: 8),
                _StatBox(icon: '⚔️', label: 'ATK', value: '$baseAtk'),
                const SizedBox(width: 8),
                _StatBox(
                  icon: '💧',
                  label: 'Mana',
                  value: '$maxMana',
                  color: const Color(0xFF29B6F6),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Ability card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF7B61FF).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Text(ability.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ability.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(ability.description,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF29B6F6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF29B6F6).withOpacity(0.5)),
                    ),
                    child: Text('${ability.manaCost} MP',
                        style: const TextStyle(
                            color: Color(0xFF29B6F6),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Description / personality
            Text(char['description'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54, height: 1.5, fontSize: 13)),

            if (char['subject_affinity'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('📚 ${char['subject_affinity']}',
                    style: TextStyle(color: color, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat box widget
// ---------------------------------------------------------------------------

class _StatBox extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
