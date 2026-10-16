import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/pages/club_threads_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements ThreadRepository {
  Result<ThreadPage> page = Either.right(const ThreadPage());
  int calls = 0;

  @override
  Future<Result<ThreadPage>> getClubThreads(int clubId,
      {int offset = 0, int limit = 20}) async {
    calls++;
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

Future<void> _pump(WidgetTester tester, _FakeRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [threadRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      home: Scaffold(
        body: ClubThreadsPage(clubId: 5, clubName: 'Tinkerhub CET'),
      ),
    ),
  ));
  // Not pumpAndSettle: the loading skeleton shimmers forever.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a club with no posts says so', (tester) async {
    await _pump(tester, _FakeRepository());

    expect(find.text('No posts yet'), findsOneWidget);
  });

  testWidgets('a failed load is an error with a retry, not "no posts"',
      (tester) async {
    final repo = _FakeRepository()
      ..page = Either.left(const NetworkFailure(message: 'No internet'));
    await _pump(tester, repo);

    expect(find.text('No posts yet'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);

    repo.page = Either.right(ThreadPage(
      items: [
        Thread(
          id: 't1',
          club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
          body: 'Back online',
          createdAt: DateTime.now(),
        ),
      ],
      total: 1,
    ));
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    expect(find.text('Back online'), findsOneWidget);
  });

  testWidgets('posts are listed, pinned first as the server sends them',
      (tester) async {
    final repo = _FakeRepository()
      ..page = Either.right(ThreadPage(
        items: [
          Thread(
            id: 'p',
            club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
            body: 'Pinned rules',
            pinned: true,
            createdAt: DateTime.now().subtract(const Duration(days: 9)),
          ),
          Thread(
            id: 'n',
            club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
            body: 'Newest news',
            createdAt: DateTime.now(),
          ),
        ],
        total: 2,
      ));
    await _pump(tester, repo);

    final pinned = tester.getTopLeft(find.text('Pinned rules'));
    final newest = tester.getTopLeft(find.text('Newest news'));
    expect(pinned.dy, lessThan(newest.dy));
    expect(find.text('PINNED'), findsOneWidget);
  });
}
