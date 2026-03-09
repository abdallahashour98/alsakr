import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:al_sakr/core/services/settings_service.dart'; // Will be moved later

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  late final SettingsService _settingsService;

  @override
  ThemeMode build() {
    _settingsService = SettingsService();
    // Return a default immediately, then load asynchronously
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final theme = await _settingsService.getThemeMode();
    state = theme;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _settingsService.saveThemeMode(mode);
  }

  void toggleTheme() {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }
}
