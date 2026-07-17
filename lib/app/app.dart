import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/core/themes/app_theme.dart';

/// Root application widget.
///
/// This widget sets up the MaterialApp with:
/// - GoRouter for navigation
/// - Theme configuration
/// - Debug banner settings
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'My Other App',
      theme: AppTheme.themeData(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
