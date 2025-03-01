import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/features/auth/bloc/login_cubit.dart';
import 'package:myotherapp/features/auth/data/services/authentication_service.dart';
import 'package:myotherapp/features/auth/presentation/pages/profile_check_page.dart';
// Make sure this file exists and is properly implemented

class OnboardingInitialPage extends StatelessWidget {
  OnboardingInitialPage({super.key});
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'openid'],
    serverClientId:
        '497245325238-ceiht9g22u4eh9a3mdkmfbssa0fkevt1.apps.googleusercontent.com',
  );

  final SecureStorage secureStorage = SecureStorage.instance;

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        final String? idToken = auth.idToken;
        if (idToken != null) {
          final String platform = Platform.isAndroid ? 'android' : 'ios';

          // Trigger the login process via the cubit.
          context
              .read<LoginCubit>()
              .loginWithGoogle(idToken, platform, account.photoUrl ?? '');
          print("User signed in: ${account.photoUrl}");
        } else {
          print('No idToken received.');
        }
      } else {
        print('Google sign in cancelled.');
      }
    } catch (error) {
      print('Error during Google sign in: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(authService: AuthenticationService()),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFA0),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 80),
                        _buildLogo(),
                        const SizedBox(height: 48),
                        _buildContent(),
                        const Spacer(),
                        // Use Builder to get the correct context for the button.
                        Builder(builder: (innerContext) {
                          return _buildLoginButton(innerContext);
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Background grass image.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/grass.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Listen for login state changes.
            BlocListener<LoginCubit, LoginState>(
              listener: (context, state) {
                if (state is LoginLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logging in...')),
                  );
                } else if (state is LoginSuccess) {
                  // Navigate to the ProfileCheckPage to verify if the profile is complete.
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileCheckPage(
                          accessToken: state.accessToken,
                          profileUrl: state.photoUrl),
                    ),
                  );
                } else if (state is LoginFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${state.error}')),
                  );
                }
              },
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'M',
          style: TextStyle(
            color: Color(0xFF9747FF),
            fontSize: 128,
            fontFamily: 'Jaro',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 8),
        _buildStarLogo(),
        const SizedBox(width: 8),
        const Text(
          'A',
          style: TextStyle(
            color: Color(0xFFFFCC00),
            fontSize: 140,
            fontFamily: 'Jaro',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStarLogo() {
    return SizedBox(
      width: 106.15,
      height: 106.15,
      child: Stack(
        children: [
          const Positioned(
            left: 3.43,
            top: 2.43,
            child: SizedBox(
              width: 100,
              height: 100,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color(0xFF17A58F),
                  shape: OvalBorder(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 22.43,
            top: 0,
            child: Transform(
              transform: Matrix4.identity()..rotateZ(0.26),
              child: const SizedBox(
                width: 86.67,
                height: 86.67,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Color(0xFFB4E5BC),
                    shape: StarBorder(
                      points: 8,
                      innerRadiusRatio: 0.47,
                      pointRounding: 0,
                      valleyRounding: 0,
                      rotation: 0,
                      squash: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 28.43,
            top: 11,
            child: Transform(
              transform: Matrix4.identity()..rotateZ(0.26),
              child: const SizedBox(
                width: 69.64,
                height: 69.64,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Color(0xFFF8FFA0),
                    shape: StarBorder(
                      points: 8,
                      innerRadiusRatio: 0.47,
                      pointRounding: 0,
                      valleyRounding: 0,
                      rotation: 0,
                      squash: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: const [
        Text(
          'Explore Events\nLearn Skills\nEarn Rewards!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 48,
            fontFamily: 'Bebas Neue',
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Find dope talks, workshops, hackathons, and courses made just for you. ✨🔥',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 16,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: ShapeDecoration(
        color: const Color(0xFF2C333D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('Login button tapped');
            _handleGoogleSignIn(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/google_logo.png',
                width: 32,
                height: 32,
              ),
              const SizedBox(width: 16),
              const Text(
                'LOGIN WITH GOOGLE',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Bebas Neue',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
