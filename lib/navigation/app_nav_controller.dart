import 'package:flutter/foundation.dart';
import 'app_tab.dart';

class AppNavController extends ChangeNotifier {
  AppTab _currentTab = AppTab.home;

  AppTab get currentTab => _currentTab;

  void goToTab(AppTab tab) {
    if (_currentTab == tab) return;
    _currentTab = tab;
    notifyListeners();
  }
}
