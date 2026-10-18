import 'package:finnet/app/session_scope.dart';
import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/auth_fakes.dart';

/// Stands in for every provider holding one person's data.
final _somebodysData = StateProvider<String>((ref) => 'nothing');

class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return Text(
      [
        'data=${ref.watch(_somebodysData)}',
        'tab=${ref.watch(navigationIndexProvider)}',
        'signedIn=${auth.isAuthenticated}',
        'ended=${auth.endedBecause?.name}',
      ].join(' '),
      textDirection: TextDirection.ltr,
    );
  }
}

void main() {
  late MemoryStorage storage;

  Future<WidgetRef> start(WidgetTester tester) async {
    storage = MemoryStorage();
    await tester.pumpWidget(SessionScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
        sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
      ],
      child: const _Probe(),
    ));
    await tester.pump();
    return tester.element(find.byType(_Probe)) as WidgetRef;
  }

  Future<void> signIn(WidgetTester tester, WidgetRef ref) async {
    await ref
        .read(authStateProvider.notifier)
        .setAuthenticated(accessToken: 'a', refreshToken: 'r');
    ref.read(_somebodysData.notifier).state = "the last person's tickets";
    ref.read(navigationIndexProvider.notifier).state = 3;
    await tester.pump();
  }

  testWidgets('signing out leaves nothing of the last person behind',
      (tester) async {
    final ref = await start(tester);
    await signIn(tester, ref);
    expect(find.textContaining("data=the last person's tickets tab=3"),
        findsOneWidget);

    await tester.runAsync(() => ref.read(authStateProvider.notifier).logout());
    await tester.pump();
    await tester.pump();

    expect(
      find.text('data=nothing tab=0 signedIn=false ended=signedOut'),
      findsOneWidget,
    );
  });

  testWidgets('a session the server ended starts over, saying why',
      (tester) async {
    final ref = await start(tester);
    await signIn(tester, ref);

    // What AuthInterceptor reports after a refused refresh.
    SessionEvents.reportRevoked(SessionEndReason.expired);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(
      find.text('data=nothing tab=0 signedIn=false ended=expired'),
      findsOneWidget,
    );
  });

  testWidgets('changes within a session keep its providers', (tester) async {
    final ref = await start(tester);
    await signIn(tester, ref);

    ref.read(authStateProvider.notifier).setLoading(true);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining("data=the last person's tickets"),
        findsOneWidget);
  });
}
