import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/sign_out.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

/// The session, set by hand; signing out ends it.
class _Auth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _Auth(super.state);

  int logouts = 0;

  @override
  Future<void> logout() async {
    logouts++;
    state = _signedOut;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _NoTickets implements SavedTicketsRepository {
  @override
  Future<List<SavedTicket>> saved() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The tickets the shell keeps current, asking the server nothing.
class _Tickets extends SavedTicketsNotifier {
  _Tickets() : super(_NoTickets());

  @override
  Future<void> refresh() async {}
}

class _NoSwitches implements PushSettingsRepository {
  @override
  Future<PushSwitches?> savedSwitches() async => null;

  @override
  Future<Result<PushSwitches?>> switches() async => Either.right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _EmptyInbox implements NotificationRepository {
  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => null;

  @override
  Future<Result<NotificationPage>> fetchList({
    required int limit,
    required int offset,
    String? cursor,
  }) async =>
      Either.right(NotificationPage(items: const [], total: 0));

  @override
  Future<Result<int>> unreadCount() async => Either.right(0);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Profiles implements ProfileRepository {
  @override
  Future<UserProfile?> getSavedProfile() async => null;

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(
      const UserProfile(id: '7', fullName: 'Asha Menon', email: 'a@b.test'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// A tab's page: its name; on Profile, the person (loaded as the real tab
/// loads it) and the way to sign out.
class _Tab extends ConsumerWidget {
  const _Tab(this.name);

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        Text('the $name tab'),
        if (name == 'profile') ...[
          Text('${ref.watch(profileProvider).profile?.fullName}'),
          TextButton(
            onPressed: () => confirmSignOut(context, ref),
            child: const Text('Log out'),
          ),
        ],
      ]);
}

void main() {
  late _Auth auth;
  late GoRouter router;
  late ProviderContainer container;

  /// The four tabs in the shell, as the app's router has them.
  Future<void> pumpShell(WidgetTester tester,
      {AuthState session = _signedOut,
      String start = '/',
      int index = 0}) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    auth = _Auth(session);
    router = GoRouter(initialLocation: start, routes: [
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const _Tab('home')),
          GoRoute(path: '/events', builder: (_, __) => const _Tab('events')),
          GoRoute(path: '/clubs', builder: (_, __) => const _Tab('clubs')),
          GoRoute(path: '/profile', builder: (_, __) => const _Tab('profile')),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => auth),
        navigationIndexProvider.overrideWith((ref) => index),
        savedTicketsProvider.overrideWith((ref) => _Tickets()),
        pushSettingsRepositoryProvider.overrideWithValue(_NoSwitches()),
        notificationRepositoryProvider.overrideWithValue(_EmptyInbox()),
        profileRepositoryProvider.overrideWithValue(_Profiles()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    container = ProviderScope.containerOf(tester.element(find.byType(MainShell)));
  }

  int lit(WidgetTester tester) =>
      tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex;

  String here() => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('four tabs -- Home, Events, Clubs and Profile -- Home lit first',
      (tester) async {
    await pumpShell(tester);

    final bar =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.items.map((i) => i.label), ['Home', 'Events', 'Clubs', 'Profile']);
    expect(lit(tester), 0);
    expect(find.text('the home tab'), findsOneWidget);
  });

  testWidgets('a tap opens its tab and lights it', (tester) async {
    await pumpShell(tester, session: _signedIn);

    for (final (label, path, page, index) in [
      ('Clubs', '/clubs', 'the clubs tab', 2),
      ('Events', '/events', 'the events tab', 1),
      ('Profile', '/profile', 'the profile tab', 3),
      ('Home', '/', 'the home tab', 0),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(here(), path, reason: label);
      expect(find.text(page), findsOneWidget, reason: label);
      expect(lit(tester), index, reason: label);
      expect(container.read(navigationIndexProvider), index, reason: label);
    }
  });

  testWidgets('tapping the tab already open stays on it', (tester) async {
    await pumpShell(tester, start: '/clubs', index: 2);
    await tester.tap(find.text('Clubs'));
    await tester.pumpAndSettle();

    expect(here(), '/clubs');
    expect(lit(tester), 2);
  });

  testWidgets(
      'logging out from Profile asks first, then ends the session with Home '
      'the tab to come back to', (tester) async {
    await pumpShell(tester, session: _signedIn, start: '/profile', index: 3);
    await tester.pump();
    expect(lit(tester), 3);
    expect(find.text('Asha Menon'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('LOG OUT?'), findsOneWidget);
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(auth.logouts, 1);
    expect(container.read(isAuthenticatedProvider), isFalse);
    expect(container.read(profileProvider).profile, isNull);
    expect(container.read(navigationIndexProvider), 0);
    expect(lit(tester), 0);
  });

  testWidgets('cancelling the log-out leaves things as they were',
      (tester) async {
    await pumpShell(tester, session: _signedIn, start: '/profile', index: 3);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(auth.logouts, 0);
    expect(container.read(isAuthenticatedProvider), isTrue);
    expect(lit(tester), 3);
  });
}
