/// Persisted theme preference. Kept as its own small enum (rather than
/// storing Flutter's `ThemeMode` directly) so the storage layer doesn't need
/// to depend on `package:flutter/material.dart`. [system] follows the OS
/// setting until the user manually picks [light] or [dark] via the home
/// screen's theme toggle.
enum AppThemeMode { system, light, dark }

extension AppThemeModeJson on AppThemeMode {
  static AppThemeMode fromJson(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }

  String toJson() {
    switch (this) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }
}
