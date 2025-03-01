import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/presentation/home/screen.dart';


///
/// Auth Wrapper
///
/// This widget detects whether a user is logged in or not and shows the appropriate page
///
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppBlocState>(
      builder: (context, state) {
        debugPrint('Current auth state: ${state.runtimeType}');
        
        if (state is! AppBlocInitialState || state is! AppLoggedOutState) {
          return  LandingPage();
        } else {
          return  OnboardingInitialPage();
        }
      },
    );
  }
}
