import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/features/auth/presentation/cubits/login_cubit.dart';
import 'package:myotherapp/features/auth/data/services/authentication_service.dart';
import 'package:myotherapp/features/auth/data/services/apple_auth_service.dart';
import 'package:myotherapp/features/auth/data/services/profile_service.dart';
import 'package:myotherapp/core/storage/secure_storage_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Onboarding Initial Page with Google and Apple Sign In support.
class OnboardingInitialPage extends StatefulWidget {
  const OnboardingInitialPage({super.key});

  @override
  State<OnboardingInitialPage> createState() => _OnboardingInitialPageState();
}

class _OnboardingInitialPageState extends State<OnboardingInitialPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'openid'],
    serverClientId:
        '497245325238-ceiht9g22u4eh9a3mdkmfbssa0fkevt1.apps.googleusercontent.com',
  );

  late LoginCubit _loginCubit;
  bool _isAppleSignInAvailable = false;

  @override
  void initState() {
    super.initState();
    _loginCubit = LoginCubit(
      authService: AuthenticationService(),
      profileService: ProfileService(),
      secureStorage: SecureStorageService(),
    );
    _loginCubit.onStateChanged = _handleLoginStateChange;
    _checkAppleSignInAvailability();
  }

  Future<void> _checkAppleSignInAvailability() async {
    final isAvailable = await AppleAuthService.isAvailable();
    if (mounted) {
      setState(() {
        _isAppleSignInAvailable = isAvailable;
      });
    }
  }

  void _handleLoginStateChange(LoginState state) {
    if (!mounted) return;

    if (state is LoginLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging in...')),
      );
    } else if (state is LoginSuccess) {
      context.go('/auth/profile-check', extra: {
        'accessToken': state.accessToken,
        'profileUrl': state.photoUrl,
      });
    } else if (state is LoginFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${state.error}')),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('Google Sign In: user cancelled');
        return;
      }
      final auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) {
        debugPrint('Google Sign In: idToken is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Sign in failed: could not get ID token')),
          );
        }
        return;
      }
      if (mounted) {
        final String platform = Platform.isAndroid ? 'android' : 'ios';
        _loginCubit.loginWithGoogle(idToken, platform, account.photoUrl ?? '');
        await _googleSignIn.disconnect();
      }
    } catch (error) {
      debugPrint('Error during Google sign in: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In error: $error')),
        );
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      String? userName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [credential.givenName, credential.familyName]
            .where((part) => part != null && part.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          userName = parts.join(' ');
        }
      }

      if (credential.identityToken != null && mounted) {
        _loginCubit.loginWithApple(
          credential.identityToken!,
          credential.authorizationCode,
          userName,
          credential.email,
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple Sign In failed: ${e.message}')),
        );
      }
    } catch (error) {
      debugPrint('Error during Apple sign in: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      _buildLoginButtons(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        ],
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
    return const Column(
      children: [
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

  Widget _buildLoginButtons() {
    return Column(
      children: [
        // Google Sign In Button
        _buildLoginButton(
          onTap: _handleGoogleSignIn,
          icon: Image.asset('assets/images/google_logo.png',
              width: 32, height: 32),
          text: 'LOGIN WITH GOOGLE',
          backgroundColor: const Color(0xFF2C333D),
        ),
        // Apple Sign In Button (only shown on iOS/macOS)
        if (_isAppleSignInAvailable) ...[
          const SizedBox(height: 16),
          _buildLoginButton(
            onTap: _handleAppleSignIn,
            icon: const Icon(Icons.apple, color: Colors.white, size: 32),
            text: 'LOGIN WITH APPLE',
            backgroundColor: const Color(0xFF2C333D), // Same as Google button
          ),
        ],
        // Email Sign In Button
        const SizedBox(height: 16),
        _buildLoginButton(
          onTap: _showEmailSignInSheet,
          icon: const Icon(Icons.email_outlined, color: Colors.white, size: 32),
          text: 'LOGIN WITH EMAIL',
          backgroundColor: const Color(0xFF17A58F),
        ),
      ],
    );
  }

  void _showEmailSignInSheet() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSignUp = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSignUp ? 'Create Account' : 'Sign In with Email',
                  style: const TextStyle(
                    fontSize: 28,
                    fontFamily: 'Bebas Neue',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2C333D),
                  ),
                ),
                const SizedBox(height: 24),
                // Name field (only for sign-up)
                if (isSignUp) ...[
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (isSignUp && (value == null || value.isEmpty)) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (isSignUp && value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        if (isSignUp) {
                          _handleEmailSignUp(
                            nameController.text.trim(),
                            emailController.text.trim(),
                            passwordController.text,
                          );
                        } else {
                          _handleEmailSignIn(
                            emailController.text.trim(),
                            passwordController.text,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF17A58F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'Bebas Neue',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Toggle between sign-in and sign-up
                Center(
                  child: TextButton(
                    onPressed: () {
                      setSheetState(() {
                        isSignUp = !isSignUp;
                      });
                    },
                    child: Text(
                      isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Create one",
                      style: const TextStyle(
                        color: Color(0xFF17A58F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleEmailSignIn(String email, String password) {
    _loginCubit.loginWithEmail(email, password);
  }

  void _handleEmailSignUp(String name, String email, String password) {
    _loginCubit.signUpWithEmail(name, email, password);
  }

  Widget _buildLoginButton({
    required VoidCallback onTap,
    required Widget icon,
    required String text,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 16),
              Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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
