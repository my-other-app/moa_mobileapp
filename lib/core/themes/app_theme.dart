import 'package:flutter/material.dart';
import 'package:myotherapp/core/themes/color_resources.dart';

class AppTheme {
  static final _textTheme = TextTheme(
    headlineSmall: TextStyle(fontFamily: "BebasNeue", fontSize: 24),
    bodyLarge: TextStyle(fontFamily: "DMSans", fontSize: 16),
    bodyMedium: TextStyle(fontFamily: "DMSans", fontSize: 14),
  );

  static ThemeData themeData() => ThemeData(
        fontFamily: "DMSans",
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: _textTheme,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ColorResources.buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            textStyle: _textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
        dividerTheme:
            DividerThemeData(color: Color(0xff979797), thickness: 0.5),
      );
}
