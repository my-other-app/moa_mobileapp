import 'package:flutter/material.dart';

/// Extension methods for responsive design on BuildContext.
extension ResponsiveExtension on BuildContext {
  /// Screen width in logical pixels.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Screen height in logical pixels.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Device pixel ratio.
  double get devicePixelRatio => MediaQuery.of(this).devicePixelRatio;

  /// Safe area padding.
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;

  /// Whether the device is in mobile size range (< 600px).
  bool get isMobile => screenWidth < 600;

  /// Whether the device is in tablet size range (600px - 1200px).
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;

  /// Whether the device is in desktop size range (>= 1200px).
  bool get isDesktop => screenWidth >= 1200;

  /// Whether the device is in portrait orientation.
  bool get isPortrait => screenHeight > screenWidth;

  /// Whether the device is in landscape orientation.
  bool get isLandscape => screenWidth > screenHeight;

  /// Get a responsive value based on screen size.
  ///
  /// Example:
  /// ```dart
  /// final padding = context.responsiveValue(
  ///   mobile: 16.0,
  ///   tablet: 24.0,
  ///   desktop: 32.0,
  /// );
  /// ```
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }

  /// Get responsive horizontal padding.
  double get responsiveHorizontalPadding => responsiveValue(
        mobile: 16.0,
        tablet: 24.0,
        desktop: 32.0,
      );

  /// Get responsive vertical padding.
  double get responsiveVerticalPadding => responsiveValue(
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      );

  /// Get the number of columns for a grid based on screen size.
  int get gridColumns => responsiveValue(
        mobile: 1,
        tablet: 2,
        desktop: 3,
      );
}

/// Widget for building responsive layouts.
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) return desktop ?? tablet ?? mobile;
    if (context.isTablet) return tablet ?? mobile;
    return mobile;
  }
}

/// Builder widget for responsive layouts with access to size category.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, SizeCategory category) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, SizeCategory.fromContext(context));
  }
}

/// Size category enum for responsive breakpoints.
enum SizeCategory {
  mobile,
  tablet,
  desktop;

  factory SizeCategory.fromContext(BuildContext context) {
    if (context.isDesktop) return SizeCategory.desktop;
    if (context.isTablet) return SizeCategory.tablet;
    return SizeCategory.mobile;
  }

  bool get isMobile => this == SizeCategory.mobile;
  bool get isTablet => this == SizeCategory.tablet;
  bool get isDesktop => this == SizeCategory.desktop;
}

/// Responsive size utilities for common UI dimensions.
class ResponsiveSizes {
  ResponsiveSizes._();

  /// Get responsive spacing based on a base value.
  static double spacing(BuildContext context, {double base = 8.0}) {
    return base *
        context.responsiveValue(mobile: 1.0, tablet: 1.25, desktop: 1.5);
  }

  /// Get responsive font size based on a base value.
  static double fontSize(BuildContext context, {double base = 14.0}) {
    return base *
        context.responsiveValue(mobile: 1.0, tablet: 1.1, desktop: 1.2);
  }

  /// Get responsive icon size based on a base value.
  static double iconSize(BuildContext context, {double base = 24.0}) {
    return base *
        context.responsiveValue(mobile: 1.0, tablet: 1.15, desktop: 1.25);
  }

  /// Get responsive border radius based on a base value.
  static double borderRadius(BuildContext context, {double base = 8.0}) {
    return base *
        context.responsiveValue(mobile: 1.0, tablet: 1.25, desktop: 1.5);
  }
}
