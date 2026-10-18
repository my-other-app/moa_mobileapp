import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/pages/settings/blocked_users_page.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../threads/moderation_fakes.dart';

Future<FakeModerationRepository> _pump(
  WidgetTester tester, {
  FakeModerationRepository? repository,
}) async {
  final repo = repository ?? FakeModerationRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      moderationRepositoryProvider.overrideWithValue(repo),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: const MaterialApp(home: BlockedUsersPage()),
  ));
  // One frame for the post-frame load to start, one for it to land.
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('lists the people blocked, fetched on opening', (tester) async {
    final repo = FakeModerationRepository()
      ..listResult = Either.right(const [
        BlockedUser(userId: 7, name: 'Rahul'),
        BlockedUser(userId: 8, name: 'Asha'),
      ]);
    await _pump(tester, repository: repo);

    expect(repo.calls, ['list']);
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Unblock'), findsNWidgets(2));
  });

  testWidgets('unblock takes them off the list', (tester) async {
    final repo = FakeModerationRepository()
      ..listResult = Either.right(const [
        BlockedUser(userId: 7, name: 'Rahul'),
        BlockedUser(userId: 8, name: 'Asha'),
      ]);
    await _pump(tester, repository: repo);

    await tester.tap(find.byKey(const ValueKey('unblock-7')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['list', 'unblock:7']);
    expect(find.byKey(const ValueKey('blocked-7')), findsNothing);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Rahul is unblocked.'), findsOneWidget);
  });

  testWidgets('a failed unblock keeps them and says why', (tester) async {
    final repo = FakeModerationRepository()
      ..listResult = Either.right(const [BlockedUser(userId: 7, name: 'Rahul')])
      ..unblockResult = Either.left(
        const UnknownFailure(message: 'Rate limit exceeded', code: '429'),
      );
    await _pump(tester, repository: repo);

    await tester.tap(find.byKey(const ValueKey('unblock-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blocked-7')), findsOneWidget);
    expect(
      find.text(
          "You're doing that a lot. Please wait a few minutes and try again."),
      findsOneWidget,
    );
  });

  testWidgets('nobody blocked says so', (tester) async {
    await _pump(tester);

    expect(find.text("You haven't blocked anyone"), findsOneWidget);
  });

  testWidgets('a list that will not load offers a retry', (tester) async {
    final repo = FakeModerationRepository()
      ..listResult = Either.left(const NetworkFailure());
    await _pump(tester, repository: repo);

    final retry = find.text('Try Again');
    expect(retry, findsOneWidget);

    repo.listResult = Either.right(const [BlockedUser(userId: 7, name: 'Rahul')]);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();

    expect(find.text('Rahul'), findsOneWidget);
  });
}
