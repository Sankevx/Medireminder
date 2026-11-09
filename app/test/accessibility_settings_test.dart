import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/accessibility_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('accessibility settings are saved on the device', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AccessibilitySettings.instance;
    await settings.load();

    await settings.setTextScale(1.4);
    await settings.setHighContrast(true);
    await settings.setReduceMotion(true);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('accessibility.textScale'), 1.4);
    expect(preferences.getBool('accessibility.highContrast'), isTrue);
    expect(preferences.getBool('accessibility.reduceMotion'), isTrue);

    await settings.setTextScale(1);
    await settings.setHighContrast(false);
    await settings.setReduceMotion(false);
  });
}
