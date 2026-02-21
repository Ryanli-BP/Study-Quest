import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../providers/expedition_provider.dart';

const _slots = ['⚔️ Weapon', '🛡️ Armor', '💍 Trinket'];

class BlacksmithScreen extends StatefulWidget {
  const BlacksmithScreen({super.key});

  @override
  State<BlacksmithScreen> createState() => _BlacksmithScreenState();
}

class _BlacksmithScreenState extends State<BlacksmithScreen> {
  List<Map<String, dynamic>> _companions = [];
  bool _loading = true;
  int? _expandedId;

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpeditionProvider>();
    final smithLevel = provider.buildingLevel('blacksmith');
    final materials = provider.materials;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('⚒️ Blacksmith',
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
              child: CircularProgressIndicator(color: Color(0xFF546E7A)))
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF546E7A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF546E7A).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Blacksmith Lv.$smithLevel',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            const Text(
                              'Forge equipment for your companions to boost their stats in battle.',
                              style: TextStyle(
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
                      child: Text('No companions to equip.',
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
                        final isExpanded = _expandedId == id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isExpanded
                                  ? const Color(0xFF546E7A)
                                  : Colors.white12,
                            ),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                onTap: () => setState(() =>
                                    _expandedId = isExpanded ? null : id),
                                leading: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Image.asset(
                                    'assets/images/${char['name']}.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Text('🐾',
                                            style:
                                                TextStyle(fontSize: 28)),
                                  ),
                                ),
                                title: Text(char['name'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${(char['rarity'] as String).toUpperCase()} · All slots empty',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11)),
                                trailing: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.white38,
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 14),
                                  child: Column(
                                    children: _slots
                                        .map((slot) => _EquipmentSlot(
                                            slot: slot))
                                        .toList(),
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
}

class _EquipmentSlot extends StatelessWidget {
  final String slot;
  const _EquipmentSlot({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(slot,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text('Empty — Coming Soon',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
