import 'package:flutter/material.dart';

/// One selectable app colour theme. The [key] is what gets persisted
/// (settings_kv `app_theme`, mirrored to `shops.theme`); [seed] drives the
/// Material 3 colour scheme.
class AppThemeOption {
  const AppThemeOption(this.key, this.seed, this.labelEn, this.labelMm);

  final String key;
  final Color seed;
  final String labelEn;
  final String labelMm;

  String label(String lang) => lang == 'mm' ? labelMm : labelEn;
}

/// The shop themes (same idea as the prototype's theme picker).
const List<AppThemeOption> kAppThemes = [
  AppThemeOption('maroon', Color(0xFF800000), 'Maroon', 'နီညို'),
  AppThemeOption('red', Colors.red, 'Red', 'အနီ'),
  AppThemeOption('yellow', Colors.amber, 'Yellow', 'အဝါ'),
  AppThemeOption('teal', Colors.teal, 'Teal', 'စိမ်းပြာ'),
  AppThemeOption('blue', Colors.blue, 'Blue', 'အပြာ'),
  AppThemeOption('indigo', Colors.indigo, 'Indigo', 'မဲနယ်'),
  AppThemeOption('purple', Colors.purple, 'Purple', 'ခရမ်း'),
  AppThemeOption('pink', Colors.pink, 'Pink', 'ပန်းရောင်'),
  AppThemeOption('orange', Colors.orange, 'Orange', 'လိမ္မော်'),
  AppThemeOption('green', Colors.green, 'Green', 'အစိမ်း'),
  AppThemeOption(
      'neon_cyan', Color(0xFF00E5FF), 'Neon Cyan', 'နီယွန် စိမ်းပြာ'),
];

const String kDefaultThemeKey = 'teal';

AppThemeOption themeOption(String key) => kAppThemes.firstWhere(
      (t) => t.key == key,
      orElse: () => kAppThemes.first,
    );

Color themeSeedColor(String key) => themeOption(key).seed;
