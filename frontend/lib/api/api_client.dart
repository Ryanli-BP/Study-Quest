import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'http://localhost:8000';

class ApiClient {
  static String? _token;

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static bool get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Auth
  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return _handle(res);
  }

  static Future<String> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=$username&password=$password',
    );
    final data = _handle(res);
    await saveToken(data['access_token']);
    return data['access_token'];
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers,
    );
    return _handle(res);
  }

  // Materials
  static Future<Map<String, dynamic>> uploadMaterial(
    List<int> bytes,
    String filename,
    String mimeType,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/materials/upload'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: http.MediaType.parse(mimeType),
      ),
    );
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<List<dynamic>> getMaterials() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/materials/'),
      headers: _headers,
    );
    return _handleList(res);
  }

  static Future<Map<String, dynamic>> getSyllabus(int materialId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/materials/$materialId/syllabus'),
      headers: _headers,
    );
    return _handle(res);
  }

  // Quiz
  static Future<Map<String, dynamic>> generateAssessmentQuiz(
    int syllabusId,
    int numQuestions,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/quiz/assessment/generate'),
      headers: _headers,
      body: jsonEncode({
        'syllabus_id': syllabusId,
        'num_questions': numQuestions,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> generateLessonQuiz(
    int syllabusId,
    int topicNumber,
    int numQuestions,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/quiz/lesson/generate'),
      headers: _headers,
      body: jsonEncode({
        'syllabus_id': syllabusId,
        'topic_number': topicNumber,
        'num_questions': numQuestions,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitQuiz(
    int quizId,
    List<int> answers,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/quiz/$quizId/submit'),
      headers: _headers,
      body: jsonEncode({'answers': answers}),
    );
    return _handle(res);
  }

  // Tokens
  static Future<Map<String, dynamic>> getTokenBalance() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/tokens/balance'),
      headers: _headers,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> completeLesson(
    int syllabusId,
    int topicNumber,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/tokens/lesson/complete'),
      headers: _headers,
      body: jsonEncode({
        'syllabus_id': syllabusId,
        'topic_number': topicNumber,
      }),
    );
    return _handle(res);
  }

  // Lessons
  static Future<Map<String, dynamic>> getLesson(
    int syllabusId,
    int topicNumber,
  ) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/lessons/$syllabusId/$topicNumber'),
      headers: _headers,
    );
    return _handle(res);
  }

  static Future<String> askQuestion(
    int syllabusId,
    int topicNumber,
    String question,
    List<Map<String, String>> history,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/lessons/$syllabusId/$topicNumber/ask'),
      headers: _headers,
      body: jsonEncode({'question': question, 'history': history}),
    );
    final data = _handle(res);
    return data['answer'] as String;
  }

  // Gacha
  static Future<Map<String, dynamic>> singlePull() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/gacha/pull/single'),
      headers: _headers,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> tenPull() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/gacha/pull/ten'),
      headers: _headers,
    );
    return _handle(res);
  }

  static Future<List<dynamic>> getCollection() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/gacha/collection'),
      headers: _headers,
    );
    return _handleList(res);
  }

  static Future<List<dynamic>> getAllCharacters() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/gacha/characters'),
      headers: _headers,
    );
    return _handleList(res);
  }

  // Helpers
  static Map<String, dynamic> _handle(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(data['detail'] ?? 'Unknown error', res.statusCode);
    }
    return data as Map<String, dynamic>;
  }

  static List<dynamic> _handleList(http.Response res) {
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body);
      throw ApiException(data['detail'] ?? 'Unknown error', res.statusCode);
    }
    return jsonDecode(res.body) as List<dynamic>;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
