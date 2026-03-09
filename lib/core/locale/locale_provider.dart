import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:al_sakr/core/services/settings_service.dart'; // Will be moved later

part 'locale_provider.g.dart';

@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  late final SettingsService _settingsService;

  @override
  Locale build() {
    _settingsService = SettingsService();
    _loadLocale();
    return const Locale('ar'); // Default to Arabic based on app strings
  }

  Future<void> _loadLocale() async {
    final locale = await _settingsService.getLocale();
    state = locale;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _settingsService.saveLocale(locale.languageCode);
  }

  void toggleLocale() {
    final newLocale = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    setLocale(newLocale);
  }
}
