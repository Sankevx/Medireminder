import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();

  static final instance = AccessibilitySettings._();

  static const _textScaleKey = 'accessibility.textScale';
  static const _highContrastKey = 'accessibility.highContrast';
  static const _reduceMotionKey = 'accessibility.reduceMotion';

  SharedPreferences? _preferences;

  double textScale = 1;
  bool highContrast = false;
  bool reduceMotion = false;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    textScale = _preferences!.getDouble(_textScaleKey) ?? 1;
    highContrast = _preferences!.getBool(_highContrastKey) ?? false;
    reduceMotion = _preferences!.getBool(_reduceMotionKey) ?? false;
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    final preferences = await _getPreferences();
    await preferences.setDouble(_textScaleKey, value);
    textScale = value;
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    final preferences = await _getPreferences();
    await preferences.setBool(_highContrastKey, value);
    highContrast = value;
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    final preferences = await _getPreferences();
    await preferences.setBool(_reduceMotionKey, value);
    reduceMotion = value;
    notifyListeners();
  }

  Future<SharedPreferences> _getPreferences() async =>
      _preferences ??= await SharedPreferences.getInstance();
}
