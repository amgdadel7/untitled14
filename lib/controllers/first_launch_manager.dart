import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchManager extends ChangeNotifier {
  bool _isFirstLaunch = true;

  bool get isFirstLaunch => _isFirstLaunch;

  FirstLaunchManager() {
    _loadLaunchState();
  }

  Future<void> _loadLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstLaunch = prefs.getBool('first_launch') ?? true;
    notifyListeners();
  }

  Future<void> completeRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
    _isFirstLaunch = false;
    notifyListeners();
  }
}