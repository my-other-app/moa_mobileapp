import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/themes/color_resources.dart';

class AppTheme {
  static final _textTheme = TextTheme(
    headlineSmall: TextStyle(fontFamily: "BebasNeue", fontSize: 24),
    bodyLarge: TextStyle(fontFamily: "DMSans", fontSize: 16),
    bodyMedium: TextStyle(fontFamily: "DMSans", fontSize: 14),
    bodySmall:
        TextStyle(fontFamily: "DMSans", fontSize: 12, letterSpacing: 0.1),
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ColorResources.buttonColor,
            side: BorderSide(color: ColorResources.buttonColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            textStyle: _textTheme.headlineSmall?.copyWith(
              color: ColorResources.buttonColor,
            ),
          ),
        ),
        // Every snack bar and toast: a small floating bar in the app's ink
        // that slides up into place and leaves by itself.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ColorResources.buttonColor,
          contentTextStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: Colors.white,
          ),
          actionTextColor: AppColors.paleYellow,
          insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        dividerTheme:
            DividerThemeData(color: Color(0xff979797), thickness: 0.5),
        switchTheme: SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.paleYellow;
              }
              return Colors.transparent;
            },
          ),
          thumbColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.grey.shade800;
              }
              return Colors.grey;
            },
          ),
          trackOutlineWidth: WidgetStateProperty.resolveWith<double>(
            (Set<WidgetState> states) => 1,
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) => Colors.grey.shade800,
          ),
        ),
      );
}
