import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
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
      case 'epic': return const Color(0xFFBF00FF);
      case 'rare': return const Color(0xFF4169E1);
      default: return const Color(0xFF808080);
    }
  }

  String _rarityEmoji(String rarity) {
    switch (rarity) {
      case 'legendary': return '🌟';
      case 'epic': return '💜';
      case 'rare': return '💙';
      default: return '⚪';
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

    // Deduplicate by character id (show unique companions only, with count)
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
                style: const TextStyle(
                    color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.6)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_rarityEmoji(rarity),
                              style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(char['name'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(rarity.toUpperCase(),
                              style: TextStyle(color: color, fontSize: 10)),
                          const SizedBox(height: 4),
                          // Level + XP bar
                          Builder(builder: (ctx) {
                            final prog = ctx
                                .watch<ExpeditionProvider>()
                                .progressFor(char['id'] as int);
                            return Column(
                              children: [
                                Text('Lv.${prog.level}',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 60,
                                  child: LinearProgressIndicator(
                                    value: prog.xpFraction,
                                    backgroundColor: Colors.white12,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                    borderRadius: BorderRadius.circular(3),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            );
                          }),
                          if (count > 1) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('x$count',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 11,
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
    Color color;
    switch (rarity) {
      case 'legendary': color = const Color(0xFFFFD700); break;
      case 'epic': color = const Color(0xFFBF00FF); break;
      case 'rare': color = const Color(0xFF4169E1); break;
      default: color = const Color(0xFF808080);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_rarityEmoji(rarity), style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(char['name'] ?? '',
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(rarity.toUpperCase(),
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 16),
            Text(char['description'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5)),
            if (char['subject_affinity'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('📚 Subject: ${char['subject_affinity']}',
                    style: TextStyle(color: color)),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
