import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../providers/auth_provider.dart';

class QuizScreen extends StatefulWidget {
  final int syllabusId;
  final String quizType; // 'assessment' or 'lesson'
  final int? topicNumber;
  final String? topicTitle;

  const QuizScreen({
    super.key,
    required this.syllabusId,
    required this.quizType,
    this.topicNumber,
    this.topicTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Map<String, dynamic>? _quiz;
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _result;
  final Map<int, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  Future<void> _generateQuiz() async {
    try {
      if (widget.quizType == 'assessment') {
        _quiz = await ApiClient.generateAssessmentQuiz(widget.syllabusId, 5);
      } else {
        _quiz = await ApiClient.generateLessonQuiz(
            widget.syllabusId, widget.topicNumber!, 5);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.of(context).pop();
      }
      return;
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final questions = _quiz!['questions'] as List<dynamic>;
    if (_answers.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions first')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final answerList = List.generate(
          questions.length, (i) => _answers[i] ?? 0);
      _result = await ApiClient.submitQuiz(_quiz!['id'], answerList);
      // Refresh token balance
      await context.read<AuthProvider>().refreshUser();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          widget.quizType == 'assessment'
              ? 'Knowledge Assessment'
              : widget.topicTitle ?? 'Lesson Quiz',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7B61FF)),
                  SizedBox(height: 16),
                  Text('Generating quiz with AI...',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _result != null
              ? _ResultView(result: _result!)
              : _QuizView(
                  quiz: _quiz!,
                  answers: _answers,
                  onAnswerSelected: (qIdx, aIdx) =>
                      setState(() => _answers[qIdx] = aIdx),
                  onSubmit: _submitting ? null : _submit,
                  submitting: _submitting,
                ),
    );
  }
}

class _QuizView extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final Map<int, int> answers;
  final Function(int, int) onAnswerSelected;
  final VoidCallback? onSubmit;
  final bool submitting;

  const _QuizView({
    required this.quiz,
    required this.answers,
    required this.onAnswerSelected,
    required this.onSubmit,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    final questions = quiz['questions'] as List<dynamic>;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('${questions.length} Questions',
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 16),
        ...questions.asMap().entries.map((e) {
          final i = e.key;
          final q = e.value as Map<String, dynamic>;
          final options = q['options'] as List<dynamic>;
          return _QuestionCard(
            index: i,
            question: q['question'],
            options: options.cast<String>(),
            selectedIndex: answers[i],
            onSelect: (aIdx) => onAnswerSelected(i, aIdx),
          );
        }),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Submit (${answers.length}/${questions.length} answered)',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final String question;
  final List<String> options;
  final int? selectedIndex;
  final Function(int) onSelect;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q${index + 1}',
              style: const TextStyle(
                  color: Color(0xFF7B61FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(height: 6),
          Text(question,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.4)),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((e) {
            final i = e.key;
            final opt = e.value;
            final selected = selectedIndex == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF7B61FF).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFF7B61FF)
                          : Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: selected
                          ? const Color(0xFF7B61FF)
                          : Colors.white12,
                      child: Text(letters[i],
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(opt,
                            style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white70))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = (result['score'] as num).toDouble();
    final correct = result['correct_count'] as int;
    final total = result['total_questions'] as int;
    final tokensEarned = result['tokens_earned'] as int;
    final feedback = result['feedback'] as List<dynamic>;
    final levelAssessment = result['level_assessment'] as String?;
    final pct = (score * 100).round();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Score card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: pct >= 80
                  ? [const Color(0xFF1E7D34), const Color(0xFF2ECC71)]
                  : pct >= 50
                      ? [const Color(0xFF7B5000), const Color(0xFFE67E22)]
                      : [const Color(0xFF7B0000), const Color(0xFFE74C3C)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold)),
              Text('$correct / $total correct',
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('💎 +$tokensEarned tokens earned!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ],
          ),
        ),
        if (levelAssessment != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧠 Knowledge Assessment',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 8),
                Text(levelAssessment,
                    style: const TextStyle(color: Colors.white70, height: 1.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Question Breakdown',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...feedback.map((f) => _FeedbackCard(feedback: f as Map<String, dynamic>)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B61FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Back to Study', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedback;
  const _FeedbackCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final isCorrect = feedback['is_correct'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isCorrect
                ? Colors.green.withOpacity(0.4)
                : Colors.red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Q${(feedback['question_index'] as int) + 1}: ${feedback['question']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isCorrect) ...[
            Text('Your answer: ${feedback['your_answer']}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            Text('Correct: ${feedback['correct_answer']}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ] else ...[
            Text('✓ ${feedback['correct_answer']}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ],
          const SizedBox(height: 6),
          Text(feedback['explanation'] ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}
