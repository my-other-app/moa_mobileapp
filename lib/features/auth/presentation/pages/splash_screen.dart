import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// Animated splash screen with logo and loading animation.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAndNavigate();
  }

  void _setupAnimations() {
    // Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Pulse animation for loading indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeAndNavigate() async {
    // Wait for animations
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Wait for auth to be initialized (with timeout)
    int attempts = 0;
    const maxAttempts = 20; // 10 seconds max wait
    while (attempts < maxAttempts) {
      final authState = ref.read(authStateProvider);
      if (authState.isInitialized) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
      debugPrint('Splash: Waiting for auth... attempt $attempts');
    }

    if (!mounted) return;

    // Check auth state and navigate
    final authState = ref.read(authStateProvider);
    debugPrint(
        'Splash: Auth initialized=${authState.isInitialized}, authenticated=${authState.isAuthenticated}');

    if (authState.isAuthenticated) {
      // User is logged in, go to home
      context.go('/');
    } else {
      // User not logged in, go to onboarding
      context.go('/auth/onboarding');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0), // Yellow matching native splash
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFFFFA0), // Solid yellow like onboarding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Animated Logo - use actual app icon
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: _buildLogo(),
            ),
            const SizedBox(height: 24),
            // App Name
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacityAnimation.value,
                  child: child,
                );
              },
              child: const Text(
                'My Other App',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C333D), // Dark text on yellow background
                  fontFamily: 'Bebas Neue',
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacityAnimation.value,
                  child: child,
                );
              },
              child: const Text(
                'Discover. Connect. Engage.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5A5A5A), // Gray text
                  fontFamily: 'DM Sans',
                  letterSpacing: 1,
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Loading indicator
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: _buildLoadingIndicator(),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    // Use the actual app icon from assets
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.asset(
          'assets/icons/app_icon.png', // Replace with your actual app icon path
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to styled container if icon not found
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF17A58F), // Teal/green accent
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Bebas Neue',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + (index * 200)),
          builder: (context, value, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color.fromRGBO(
                    44, 51, 61, 0.3 + (value * 0.5)), // Dark dots on yellow
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
