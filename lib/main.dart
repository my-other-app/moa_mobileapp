import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/themes/app_theme.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/presentation/home/bloc/bottom_nav_bloc.dart';

void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<BottomNavigatorBloc>(
          create: (_) => BottomNavigatorBloc(index: 0),
        ),
        // You can add other global providers here
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.white,
      title: 'My Other App',
      theme: AppTheme.themeData(),
      home: OnboardingInitialPage(),
    );
  }
}
