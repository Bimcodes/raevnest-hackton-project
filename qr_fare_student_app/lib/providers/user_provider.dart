import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String? _avatarUrl;
  String _name = '';
  String _studentId = '';

  String? get avatarUrl => _avatarUrl;
  String get name => _name;
  String get studentId => _studentId;

  UserProvider() {
    loadUser();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _avatarUrl = prefs.getString('avatar_url');
    _name = prefs.getString('student_name') ?? '';
    _studentId = prefs.getString('student_id') ?? '';
    notifyListeners();
  }

  void updateAvatar(String? newUrl) {
    _avatarUrl = newUrl;
    notifyListeners();
  }

  void updateName(String newName) {
    _name = newName;
    notifyListeners();
  }
}
