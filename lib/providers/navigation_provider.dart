import 'package:flutter/material.dart';

/// Holds the current bottom-nav tab index.
/// Using a ChangeNotifier avoids circular imports between
/// HomeScreen and child screens that want to switch tabs.
class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void switchTab(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }
}
