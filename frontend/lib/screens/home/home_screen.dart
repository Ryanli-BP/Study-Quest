import 'package:flutter/material.dart';
import 'package:frontend/components/companion.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../gacha/collection_screen.dart';
import '../gacha/gacha_screen.dart';
import '../game/base_game_screen.dart';
import '../study/study_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _screens = const [
    _BaseTab(),
    StudyScreen(),
    GachaScreen(),
    CollectionScreen(),
    BaseGameScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text(
          'StudyQuest',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Token display
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7B61FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7B61FF), width: 1),
            ),
            child: Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '${auth.tokens}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _screens[_tab],
          Companion(imagePath: "brown_dog", text: _tabMessages[_tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1A1A2E),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: const Color(0xFF7B61FF).withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.home, color: Color(0xFF7B61FF)),
            label: 'Base',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.book, color: Color(0xFF7B61FF)),
            label: 'Study',
          ),
          NavigationDestination(
            icon: Icon(Icons.casino_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.casino, color: Color(0xFF7B61FF)),
            label: 'Gacha',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.pets, color: Color(0xFF7B61FF)),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: Icon(Icons.landscape_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.landscape, color: Color(0xFF7B61FF)),
            label: 'Island',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating companion widget
// ---------------------------------------------------------------------------

const _tabMessages = [
  "Welcome back! 🏠",
  "Let's get studying! 📖",
  "Ready to pull? ✨",
  "Check out your crew! 🐾",
  "Adventure awaits! 🗺️",
];

// ---------------------------------------------------------------------------
// Base tab — shows companions + mock expedition
// ---------------------------------------------------------------------------
class _BaseTab extends StatelessWidget {
  const _BaseTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromARGB(255, 53, 39, 122),
                  Color.fromARGB(255, 43, 28, 208),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFFFFF).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                Text(
                  auth.user?['username'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '${auth.tokens} tokens',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Expedition section (mocked)
          _SectionHeader(title: 'Active Expeditions'),
          const SizedBox(height: 12),
          _ExpeditionCard(
            name: 'Forest of Knowledge',
            companions: ['Sparky', 'Leafy'],
            timeLeft: '2h 14m',
            progress: 0.65,
          ),
          const SizedBox(height: 10),
          _ExpeditionCard(
            name: 'Ancient Library',
            companions: ['Nova'],
            timeLeft: '45m',
            progress: 0.88,
          ),
          const SizedBox(height: 24),

          // Quick stats
          _SectionHeader(title: 'Your Progress'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Lessons\nCompleted',
                  value: '7',
                  icon: '📖',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Quizzes\nTaken',
                  value: '3',
                  icon: '✅',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Companions\nOwned',
                  value: '4',
                  icon: '🐾',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ExpeditionCard extends StatelessWidget {
  final String name;
  final List<String> companions;
  final String timeLeft;
  final double progress;

  const _ExpeditionCard({
    required this.name,
    required this.companions,
    required this.timeLeft,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '⏱ $timeLeft',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '👥 ${companions.join(', ')}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B61FF)),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
