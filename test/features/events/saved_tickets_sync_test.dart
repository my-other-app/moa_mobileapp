import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/widgets/saved_tickets_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  void set(AuthState next) => state = next;

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

/// Counts the refreshes it is asked for, and asks the server nothing.
class _CountingTickets extends SavedTicketsNotifier {
  _CountingTickets() : super(_NoTickets());

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

void main() {
  late _FakeAuth auth;
  late _CountingTickets tickets;

  Future<void> pump(WidgetTester tester, AuthState start) async {
    auth = _FakeAuth(start);
    tickets = _CountingTickets();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => auth),
        savedTicketsProvider.overrideWith((ref) => tickets),
      ],
      child: MaterialApp(
        home: SavedTicketsSync(
          status: NetworkStatus(),
          child: const Text('the app'),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('signed in, the tickets are brought up to date at once',
      (tester) async {
    await pump(tester, _signedIn);
    expect(tickets.refreshes, 1);
  });

  testWidgets('signed out, it asks nothing; signing in asks at once',
      (tester) async {
    await pump(tester, _signedOut);
    expect(tickets.refreshes, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tickets.refreshes, 0, reason: 'back to the front, still signed out');

    auth.set(_signedIn);
    await tester.pump();
    expect(tickets.refreshes, 1);
  });
}
