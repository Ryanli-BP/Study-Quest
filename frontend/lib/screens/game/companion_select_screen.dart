import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../providers/expedition_provider.dart';

class CompanionSelectScreen extends StatefulWidget {
  final ExpeditionLocation location;

  const CompanionSelectScreen({super.key, required this.location});

  @override
  State<CompanionSelectScreen> createState() => _CompanionSelectScreenState();
}

class _CompanionSelectScreenState extends State<CompanionSelectScreen> {
  List<Map<String, dynamic>> _collection = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  bool _sending = false;

  static const int maxCompanions = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await ApiClient.getCollection();
      // Deduplicate by character id
      final Map<int, Map<String, dynamic>> unique = {};
      for (final uc in raw) {
        final char = uc['character'] as Map<String, dynamic>;
        unique[char['id'] as int] = char;
      }
      setState(() => _collection = unique.values.toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startExpedition() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _sending = true);

    final selected = _collection
        .where((c) => _selectedIds.contains(c['id'] as int))
        .toList();

    try {
      await context
          .read<ExpeditionProvider>()
          .startExpedition(widget.location, selected);

      if (mounted) {
        // Pop back to island (pop map + select screens)
        Navigator.of(context)
          ..pop()
          ..pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚔️ Expedition started! ${selected.length} companions sent to ${widget.location.name}'),
            backgroundColor: widget.location.color,
          ),
        );
      }
    } finally {
      setState(() => _sending = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.location.name,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text('Select up to $maxCompanions companions',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Location info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.location.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.location.color.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Text(widget.location.emoji,
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.location.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _RewardChip('🪙 ${widget.location.coins}'),
                          const SizedBox(width: 6),
                          _RewardChip('🪨 ${widget.location.materials}'),
                          const SizedBox(width: 6),
                          _RewardChip('⭐ ${widget.location.xpPerCompanion} XP'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text('⏱', style: TextStyle(fontSize: 18)),
                    const Text('30m',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // Selected counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Selected: ${_selectedIds.length}/$maxCompanions',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    child: const Text('Clear',
                        style: TextStyle(color: Colors.white54)),
                  ),
              ],
            ),
          ),

          // Companion grid
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7B61FF)))
                : _collection.isEmpty
                    ? const Center(
                        child: Text('No companions yet — pull from Gacha!',
                            style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _collection.length,
                        itemBuilder: (context, i) {
                          final char = _collection[i];
                          final id = char['id'] as int;
                          final selected = _selectedIds.contains(id);
                          final rarity = char['rarity'] as String;
                          final color = _rarityColor(rarity);
                          final progress = context
                              .watch<ExpeditionProvider>()
                              .progressFor(id);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(id);
                                } else if (_selectedIds.length <
                                    maxCompanions) {
                                  _selectedIds.add(id);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withOpacity(0.25)
                                    : const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? color : Colors.white12,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            color.withOpacity(0.7),
                                        child: Text(
                                          _rarityEmoji(rarity),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                      if (selected)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.check,
                                                size: 10, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(char['name'] ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text('Lv.${progress.level}',
                                      style: TextStyle(
                                          color: color, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Start button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_selectedIds.isEmpty || _sending)
                    ? null
                    : _startExpedition,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(widget.location.emoji,
                        style: const TextStyle(fontSize: 20)),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'Select companions first'
                      : 'Send ${_selectedIds.length} companion${_selectedIds.length > 1 ? 's' : ''} on expedition',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedIds.isEmpty
                      ? Colors.white12
                      : widget.location.color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rarityEmoji(String rarity) {
    switch (rarity) {
      case 'legendary': return '🌟';
      case 'epic':      return '💜';
      case 'rare':      return '💙';
      default:          return '⚪';
    }
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  const _RewardChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }
}
