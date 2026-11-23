import 'package:flutter/material.dart';

/// Holds the user's theme choice. The app listens to it and passes it to
/// `MaterialApp.themeMode`.
class McThemeModeController extends ValueNotifier<ThemeMode> {
  McThemeModeController([super.initial = ThemeMode.system]);

  void setMode(ThemeMode mode) => value = mode;
}
