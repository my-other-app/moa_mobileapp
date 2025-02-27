import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/presentation/home/screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppBlocState>(
      builder: (context, state) {
        debugPrint('Current auth state: ${state.runtimeType}');
        
        if (state is AppLoggedInState) {
          return  LandingPage();
        } else {
          return  OnboardingInitialPage();
        }
      },
    );
  }
}
