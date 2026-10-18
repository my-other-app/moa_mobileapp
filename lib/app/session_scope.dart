import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// Holds the app's providers for one signed-in session, and replaces all of
/// them when that session ends.
///
/// Signing out used to clear the tokens and the profile and nothing else:
/// every other provider -- registered events, followed clubs, tickets,
/// notifications, the selected tab -- kept the last person's data, and the
/// next person to sign in on the phone saw it until each screen happened to
/// reload. Listing those providers to reset them by hand would go stale the
/// day someone adds one; a fresh [ProviderContainer] cannot.
///
/// The new container starts signed out, with the reason the old session
/// ended, so the router opens on the sign-in screen and that screen can say
/// "Please sign in again" when the server ended it.
class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.child, this.overrides = const []});

  final Widget child;

  /// Applied to every container this scope creates. For tests.
  final List<Override> overrides;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late ProviderContainer _container;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _container = _create(seed: null);
  }

  ProviderContainer _create({required AuthState? seed}) {
    final container = ProviderContainer(overrides: [
      ...widget.overrides,
      if (seed != null) authSeedProvider.overrideWithValue(seed),
    ]);
    container.listen<AuthState>(authStateProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) && !next.isAuthenticated) {
        _restart(next);
      }
    });
    return container;
  }

  /// Swap in a fresh container on the next frame.
  ///
  /// The old one is disposed a frame later still: whoever signed out may go
  /// on using it for the rest of the call that did it (Settings resets the
  /// tab and pushes the sign-in page after `logout()` returns), and the
  /// widgets reading it must be gone from the tree first.
  void _restart(AuthState ended) {
    final seed = AuthState(
      isInitialized: true,
      endedBecause: ended.endedBecause,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final old = _container;
      setState(() {
        _container = _create(seed: seed);
        _generation++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      key: ValueKey(_generation),
      container: _container,
      child: widget.child,
    );
  }
}
