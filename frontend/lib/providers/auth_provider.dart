import 'package:flutter/material.dart';
import '../api/api_client.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  int get tokens => _user?['tokens'] ?? 0;

  Future<void> tryAutoLogin() async {
    await ApiClient.loadToken();
    if (ApiClient.isLoggedIn) {
      try {
        _user = await ApiClient.getMe();
        notifyListeners();
      } catch (_) {
        await ApiClient.clearToken();
      }
    }
  }

  Future<void> register(String username, String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      await ApiClient.register(username, email, password);
      await login(username, password);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    notifyListeners();
    try {
      await ApiClient.login(username, password);
      _user = await ApiClient.getMe();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    _user = await ApiClient.getMe();
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    _user = null;
    notifyListeners();
  }
}
