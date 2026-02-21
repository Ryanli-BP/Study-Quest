import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../api/api_client.dart';

class LessonScreen extends StatefulWidget {
  final int syllabusId;
  final Map<String, dynamic> topic;

  const LessonScreen({
    super.key,
    required this.syllabusId,
    required this.topic,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  List<dynamic> _sections = [];
  bool _loading = true;
  String? _error;

  // Chat state
  final List<Map<String, String>> _chatHistory = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _askingQuestion = false;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() async {
    try {
      final data = await ApiClient.getLesson(
        widget.syllabusId,
        widget.topic['topic_number'] as int,
      );
      setState(() {
        _sections = data['sections'] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendQuestion() async {
    final question = _chatController.text.trim();
    if (question.isEmpty || _askingQuestion) return;

    _chatController.clear();
    setState(() {
      _chatHistory.add({'role': 'user', 'content': question});
      _askingQuestion = true;
    });
    _scrollChatToBottom();

    try {
      // Build history to send (exclude last user message, we send it as `question`)
      final historyToSend = _chatHistory.length > 1
          ? _chatHistory.sublist(0, _chatHistory.length - 1)
          : <Map<String, String>>[];

      final answer = await ApiClient.askQuestion(
        widget.syllabusId,
        widget.topic['topic_number'] as int,
        question,
        historyToSend,
      );

      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': answer});
        _askingQuestion = false;
      });
      _scrollChatToBottom();
    } catch (e) {
      setState(() {
        _chatHistory.add({
          'role': 'assistant',
          'content': 'Sorry, I couldn\'t answer that right now. Try again!',
        });
        _askingQuestion = false;
      });
      _scrollChatToBottom();
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topicTitle = widget.topic['title'] ?? 'Lesson';
    final topicNum = widget.topic['topic_number'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Topic $topicNum',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(topicTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF7B61FF)),
          SizedBox(height: 16),
          Text('Generating lesson with AI...',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadLesson();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF)),
            child:
                const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Scrollable lesson sections
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._sections.map((s) => _SectionCard(section: s as Map<String, dynamic>)),
              const SizedBox(height: 12),
              // Chat history (displayed inline above input)
              if (_chatHistory.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('AI Tutor',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                ),
                ..._chatHistory.map((msg) => _ChatBubble(message: msg)),
              ],
              if (_askingQuestion)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7B61FF),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('AI is thinking...',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              // Extra space so content doesn't hide behind input bar
              const SizedBox(height: 80),
            ],
          ),
        ),

        // Pinned Q&A input bar
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask a question about this topic...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendQuestion(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _askingQuestion ? null : _sendQuestion,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _askingQuestion
                    ? Colors.white12
                    : const Color(0xFF7B61FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card widget
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final Map<String, dynamic> section;
  const _SectionCard({required this.section});

  Color get _accentColor {
    switch (section['type'] as String? ?? '') {
      case 'intro':
        return const Color(0xFF7B61FF);
      case 'explanation':
        return const Color(0xFF1565C0);
      case 'example':
        return const Color(0xFF2E7D32);
      case 'tips':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF7B61FF);
    }
  }

  String get _icon {
    switch (section['type'] as String? ?? '') {
      case 'intro':
        return '🚀';
      case 'explanation':
        return '📖';
      case 'example':
        return '💡';
      case 'tips':
        return '✅';
      default:
        return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = (section['content'] as String? ?? '').trim();
    final isTips = section['type'] == 'tips';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: _accentColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section['title'] ?? '',
                      style: TextStyle(
                        color: _accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isTips)
                _buildBullets(content)
              else
                MarkdownBody(
                  data: content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        color: Colors.white70, height: 1.6, fontSize: 14),
                    strong: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    em: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullets(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final text = line.startsWith('•') ? line.substring(1).trim() : line;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ',
                  style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white70, height: 1.5, fontSize: 14)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble widget
// ---------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  final Map<String, String> message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF7B61FF)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white12),
        ),
        child: MarkdownBody(
          data: message['content'] ?? '',
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
                color: isUser ? Colors.white : Colors.white70,
                fontSize: 14,
                height: 1.5),
            strong: TextStyle(
                color: isUser ? Colors.white : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14),
            em: TextStyle(
                color: isUser ? Colors.white : Colors.white70,
                fontStyle: FontStyle.italic,
                fontSize: 14),
          ),
        ),
      ),
    );
  }
}
