import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/pages/thread_detail_page.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _post = Thread(
  id: 't1',
  club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
  body: 'Build sprint this Friday.',
  comments: 2,
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
);

class _FakeRepository implements ThreadRepository {
  Result<Thread> thread = Either.right(_post);
  Result<List<ThreadComment>> comments = Either.right([
    ThreadComment(
      id: 'mine',
      body: 'Count me in',
      authorId: 42,
      authorName: 'Aarav',
      createdAt: DateTime.now(),
    ),
    ThreadComment(
      id: 'club',
      body: 'See you there',
      authorId: 9,
      authorName: 'Tinkerhub CET',
      isClub: true,
      createdAt: DateTime.now(),
    ),
  ]);
  final List<String> sent = [];

  @override
  Future<Result<Thread>> getThread(String threadId) async => thread;

  @override
  Future<Result<List<ThreadComment>>> getComments(String threadId) async =>
      comments;

  @override
  Future<Result<ThreadComment>> addComment(String threadId, String body) async {
    sent.add(body);
    return Either.right(ThreadComment(
      id: 'new',
      body: body,
      authorId: 42,
      authorName: 'Aarav',
      createdAt: DateTime.now(),
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

Future<_FakeRepository> _pump(
  WidgetTester tester, {
  _FakeRepository? repository,
  bool signedIn = true,
}) async {
  final repo = repository ?? _FakeRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      threadRepositoryProvider.overrideWithValue(repo),
      // Pinned rather than built: the real ones read secure storage and
      // fetch the profile, neither of which a widget test can do.
      isAuthenticatedProvider.overrideWithValue(signedIn),
      threadViewerIdProvider.overrideWithValue(signedIn ? 42 : null),
    ],
    child: const MaterialApp(home: ThreadDetailPage(threadId: 't1')),
  ));
  // Two frames: one for the self-started load to finish, one to draw it.
  // Not pumpAndSettle -- the loading skeleton shimmers forever.
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('shows the post, then its comments', (tester) async {
    await _pump(tester);

    expect(find.text('Build sprint this Friday.'), findsOneWidget);
    expect(find.text('COMMENTS (2)'), findsOneWidget);
    expect(find.text('Count me in'), findsOneWidget);
    expect(find.text('See you there'), findsOneWidget);
  });

  testWidgets("the club's own reply wears a Club badge", (tester) async {
    await _pump(tester);

    expect(find.text('Club'), findsOneWidget);
  });

  testWidgets('only your own comment offers delete', (tester) async {
    await _pump(tester);

    expect(find.byTooltip('Delete comment'), findsOneWidget);
    final mine = find.byKey(const ValueKey('comment-mine'));
    expect(
      find.descendant(of: mine, matching: find.byTooltip('Delete comment')),
      findsOneWidget,
    );
  });

  testWidgets('a removed post says so instead of erroring', (tester) async {
    final repo = _FakeRepository()
      ..thread = Either.left(
          const ServerFailure(message: 'Post not found', code: '404'))
      ..comments = Either.left(
          const ServerFailure(message: 'Post not found', code: '404'));
    await _pump(tester, repository: repo);

    expect(find.text('This post was removed'), findsOneWidget);
    expect(find.byKey(const ValueKey('comment-field')), findsNothing);
  });

  testWidgets('no comments yet invites the first one', (tester) async {
    final repo = _FakeRepository()..comments = Either.right(const []);
    await _pump(tester, repository: repo);

    expect(find.text('No comments yet. Start the conversation.'),
        findsOneWidget);
  });

  testWidgets('a comment is sent trimmed and appears', (tester) async {
    final repo = await _pump(tester);

    final send = find.byKey(const ValueKey('comment-send'));
    // Nothing to send yet.
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    await tester.enterText(
        find.byKey(const ValueKey('comment-field')), '  Me too!  ');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    await tester.pump();

    expect(repo.sent, ['Me too!']);
    expect(find.text('Me too!'), findsOneWidget);
    expect(find.text('COMMENTS (3)'), findsOneWidget);
  });

  testWidgets('signed out, the composer is a way to sign in', (tester) async {
    await _pump(tester, signedIn: false);

    expect(find.text('SIGN IN TO COMMENT'), findsOneWidget);
    expect(find.byKey(const ValueKey('comment-field')), findsNothing);
    expect(find.byTooltip('Delete comment'), findsNothing);
  });
}
