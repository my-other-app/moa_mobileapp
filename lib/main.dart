import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/themes/app_theme.dart';
import 'package:myotherapp/presentation/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/presentation/home/screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.white,
      title: 'My Other App',
      theme: AppTheme.themeData(),
      home: BlocProvider<BottomNavigatorBloc>(
        create: (_) => BottomNavigatorBloc(index: 0),
        child: LandingPage(),
      ),
    );
  }
}
