import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../providers/expedition_provider.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
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

  int _treatCost(int buildingLevel) {
    // Cost decreases slightly as hospital levels up
    return 3;
  }

  int _treatXp(int buildingLevel) {
    const xpByLevel = [50, 80, 120, 160, 200];
    return xpByLevel[(buildingLevel - 1).clamp(0, 4)];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpeditionProvider>();
    final hospitalLevel = provider.buildingLevel('hospital');
    final materials = provider.materials;
    final cost = _treatCost(hospitalLevel);
    final xpGain = _treatXp(hospitalLevel);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('🏥 Hospital',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.brown.shade300.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Text('🪨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text('$materials',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : Column(
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2E7D32).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Text('💊', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hospital Lv.$hospitalLevel',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              'Treating restores vitality (+$xpGain XP) · Cost: $cost 🪨 per companion',
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
                      child: Text('No companions to treat.',
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
                        final canAfford = materials >= cost;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
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
                                    Text(
                                      'Lv.${prog.level}  •  ${prog.xp}/${prog.xpToNext} XP',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: 5),
                                    LinearProgressIndicator(
                                      value: prog.xpFraction,
                                      backgroundColor: Colors.white12,
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              Color(0xFF2E7D32)),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      minHeight: 5,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: canAfford
                                    ? () {
                                        provider.spendMaterials(cost);
                                        provider.addXpToCompanion(
                                            id, xpGain);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              '💊 ${char['name']} treated! +$xpGain XP'),
                                          backgroundColor:
                                              const Color(0xFF2E7D32),
                                          duration: const Duration(
                                              seconds: 2),
                                        ));
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford
                                      ? const Color(0xFF2E7D32)
                                      : Colors.white12,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: Text('Treat\n$cost 🪨',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
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
