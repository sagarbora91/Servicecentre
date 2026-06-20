import 'package:flutter/material.dart';

/// Centralized Material 3 theming. Colors are placeholders until brand assets
/// are confirmed; structure is what matters here.
abstract final class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF00695C); // teal placeholder

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
