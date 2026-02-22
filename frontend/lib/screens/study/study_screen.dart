import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/components/companion.dart';

import '../../api/api_client.dart';
import '../quiz/quiz_screen.dart';
import 'lesson_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<dynamic> _materials = [];
  bool _loading = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _loading = true);
    try {
      _materials = await ApiClient.getMaterials();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    final mimeType = file.extension == 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

    setState(() => _uploading = true);
    try {
      await ApiClient.uploadMaterial(file.bytes!, file.name, mimeType);
      await _loadMaterials();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Material processed! Syllabus generated.'),
            backgroundColor: Color(0xFF7B61FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
            )
          : RefreshIndicator(
              onRefresh: _loadMaterials,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Study Materials',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Upload PDFs or slides to generate your study plan',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Upload button
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _uploading ? null : _uploadFile,
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.upload_file,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                _uploading
                                    ? 'Processing with AI...'
                                    : 'Upload PDF / PPTX',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B61FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_materials.isEmpty)
                            _EmptyState()
                          else
                            const Text(
                              'Your Materials',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final m = _materials[i];
                      return _MaterialCard(material: m);
                    }, childCount: _materials.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('📂', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'No materials yet',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a PDF or PPTX to get started',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final processed = material['processed'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: InkWell(
        onTap: processed
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SyllabusScreen(material: material),
                ),
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B61FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    material['file_type'] == 'pdf' ? '📄' : '📊',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['original_filename'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: processed
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            processed ? '✓ Ready' : '⏳ Processing',
                            style: TextStyle(
                              color: processed ? Colors.green : Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (processed)
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white38,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Syllabus detail screen
// ---------------------------------------------------------------------------
class SyllabusScreen extends StatefulWidget {
  final Map<String, dynamic> material;
  const SyllabusScreen({super.key, required this.material});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  Map<String, dynamic>? _syllabus;
  bool _loading = true;
  final Set<int> _completedTopics = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _syllabus = await ApiClient.getSyllabus(widget.material['id']);
      _completedTopics.addAll(
        await ApiClient.getCompletedTopics(_syllabus!['id']),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _completeTopic(int topicNumber) async {
    try {
      await ApiClient.completeLesson(
        widget.material['syllabus']['id'] ?? _syllabus!['id'],
        topicNumber,
      );
      setState(() => _completedTopics.add(topicNumber));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 +10 tokens earned!'),
            backgroundColor: Color(0xFF7B61FF),
          ),
        );
      }
    } catch (e) {
      // Already completed — that's fine
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
        ),
      );
    }

    if (_syllabus == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(
          child: Text(
            'Failed to load syllabus',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final summary = _syllabus!['summary'] as Map<String, dynamic>;
    final topics = _syllabus!['topics'] as List<dynamic>;
    print(topics);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          summary['subject'] ?? 'Syllabus',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  syllabusId: _syllabus!['id'],
                  quizType: 'assessment',
                ),
              ),
            ),
            icon: const Icon(Icons.quiz, color: Color(0xFF7B61FF)),
            label: const Text(
              'Assessment Quiz',
              style: TextStyle(color: Color(0xFF7B61FF)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Overview card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7B61FF).withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary['overview'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Chip('${summary['total_topics']} topics'),
                        const SizedBox(width: 8),
                        _Chip('${summary['estimated_total_hours']}h estimated'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Topics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...topics.asMap().entries.map((e) {
                final topic = e.value as Map<String, dynamic>;
                final topicNum = topic['topic_number'] as int;
                final isDone = _completedTopics.contains(topicNum);
                return _TopicCard(
                  topic: topic,
                  isDone: isDone,
                  onComplete: isDone ? null : () => _completeTopic(topicNum),
                  onLearn: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(
                        syllabusId: _syllabus!['id'],
                        topic: topic,
                      ),
                    ),
                  ),
                  onQuiz: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        syllabusId: _syllabus!['id'],
                        quizType: 'lesson',
                        topicNumber: topicNum,
                        topicTitle: topic['title'],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          Companion(
            imagePath: "brown_dog",
            text: "Ready to learn? Let's go!",
            textSize: 18,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7B61FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF7B61FF), fontSize: 12),
      ),
    );
  }
}

class _TopicCard extends StatefulWidget {
  final Map<String, dynamic> topic;
  final bool isDone;
  final VoidCallback? onComplete;
  final VoidCallback onQuiz;
  final VoidCallback onLearn;

  const _TopicCard({
    required this.topic,
    required this.isDone,
    required this.onComplete,
    required this.onQuiz,
    required this.onLearn,
  });

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final concepts = (topic['key_concepts'] as List<dynamic>? ?? []);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDone
                ? Colors.green.withOpacity(0.5)
                : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              onTap: () => setState(() => _expanded = !_expanded),
              leading: CircleAvatar(
                backgroundColor: widget.isDone
                    ? Colors.green.withOpacity(0.2)
                    : const Color(0xFF7B61FF).withOpacity(0.2),
                child: Text(
                  widget.isDone ? '✓' : '${topic['topic_number']}',
                  style: TextStyle(
                    color: widget.isDone
                        ? Colors.green
                        : const Color(0xFF7B61FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                topic['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '⏱ ${topic['estimated_minutes']} min',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white38,
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic['summary'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Key Concepts:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...concepts.map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(color: Color(0xFF7B61FF)),
                            ),
                            Expanded(
                              child: Text(
                                c.toString(),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Learn button (full-width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onLearn,
                        icon: const Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Learn this Topic',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.onComplete != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onComplete,
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 18,
                              ),
                              label: const Text(
                                'Mark Complete (+10 💎)',
                                style: TextStyle(color: Colors.green),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.green),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        if (widget.onComplete != null) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onQuiz,
                            icon: const Icon(
                              Icons.quiz_outlined,
                              color: Color(0xFF7B61FF),
                              size: 18,
                            ),
                            label: const Text(
                              'Take Quiz',
                              style: TextStyle(color: Color(0xFF7B61FF)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF7B61FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
