import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/pages/thread_detail_page.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'moderation_fakes.dart';

const _postId = '3f2b8c1e-5d4a-4f6b-9a7c-2e1d0b9c8a7f';

final _post = Thread(
  id: _postId,
  club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
  body: 'Build sprint this Friday.',
  comments: 3,
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
);

ThreadComment _comment(String id, int? authorId, String name,
        {bool isClub = false}) =>
    ThreadComment(
      id: id,
      body: 'Comment by $name',
      authorId: authorId,
      authorName: name,
      isClub: isClub,
      createdAt: DateTime.now(),
    );

class _FakeThreads implements ThreadRepository {
  Result<List<ThreadComment>> comments = Either.right([
    _comment('mine', 42, 'Aarav'),
    _comment('theirs', 7, 'Rahul'),
    _comment('club', 9, 'Tinkerhub CET', isClub: true),
  ]);
  int commentLoads = 0;

  @override
  Future<Result<Thread>> getThread(String threadId) async => Either.right(_post);

  @override
  Future<Result<List<ThreadComment>>> getComments(String threadId) async {
    commentLoads++;
    return comments;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Harness {
  final _FakeThreads threads = _FakeThreads();
  final FakeModerationRepository moderation = FakeModerationRepository();
}

Future<_Harness> _pump(WidgetTester tester, {bool signedIn = true}) async {
  final h = _Harness();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      threadRepositoryProvider.overrideWithValue(h.threads),
      moderationRepositoryProvider.overrideWithValue(h.moderation),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      threadViewerIdProvider.overrideWithValue(signedIn ? 42 : null),
    ],
    child: const MaterialApp(home: ThreadDetailPage(threadId: _postId)),
  ));
  await tester.pump();
  await tester.pump();
  return h;
}

Finder _menuIn(String commentId) => find.descendant(
      of: find.byKey(ValueKey('comment-$commentId')),
      matching: find.byKey(const ValueKey('comment-more')),
    );

Future<void> _openMenu(WidgetTester tester, Finder menu) async {
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

void main() {
  group('the comment menu', () {
    testWidgets("is on others' comments, never on your own", (tester) async {
      await _pump(tester);

      expect(_menuIn('theirs'), findsOneWidget);
      expect(_menuIn('club'), findsOneWidget);
      expect(_menuIn('mine'), findsNothing);
      // Your own keeps its delete button instead.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('comment-mine')),
          matching: find.byTooltip('Delete comment'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers report and block for a person', (tester) async {
      await _pump(tester);
      await _openMenu(tester, _menuIn('theirs'));

      expect(find.text('Report comment'), findsOneWidget);
      expect(find.text('Block Rahul'), findsOneWidget);
    });

    testWidgets("offers only report on the club's own reply", (tester) async {
      await _pump(tester);
      await _openMenu(tester, _menuIn('club'));

      expect(find.text('Report comment'), findsOneWidget);
      expect(find.textContaining('Block'), findsNothing);
    });
  });

  group('reporting', () {
    testWidgets('a comment: pick a reason, add a note, and get thanked',
        (tester) async {
      final h = await _pump(tester);
      await _openMenu(tester, _menuIn('theirs'));
      await tester.tap(find.text('Report comment'));
      await tester.pumpAndSettle();

      expect(find.text('REPORT COMMENT'), findsOneWidget);
      // Nothing to send until a reason is picked.
      final send = find.byKey(const ValueKey('report-send'));
      expect(tester.widget<ElevatedButton>(send).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('report-reason-harassment')));
      await tester.enterText(
          find.byKey(const ValueKey('report-note')), 'Keeps doing this');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(h.moderation.lastTarget, const ReportTarget.comment('theirs'));
      expect(h.moderation.lastReason, ReportReason.harassment);
      expect(h.moderation.lastNote, 'Keeps doing this');
      expect(find.text('REPORT COMMENT'), findsNothing);
      expect(find.text(reportThanksMessage), findsOneWidget);
    });

    testWidgets('the post, from the menu on its card', (tester) async {
      final h = await _pump(tester);
      await _openMenu(tester, find.byKey(const ValueKey('thread-more')));
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();

      expect(find.text('REPORT POST'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-reason-spam')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();

      expect(h.moderation.lastTarget, const ReportTarget.thread(_postId));
      expect(h.moderation.lastReason, ReportReason.spam);
      expect(find.text(reportThanksMessage), findsOneWidget);
    });

    testWidgets('a rate limit is said in the sheet, which stays open',
        (tester) async {
      final h = await _pump(tester);
      h.moderation.reportResult = Either.left(
        const UnknownFailure(message: 'Rate limit exceeded', code: '429'),
      );
      await _openMenu(tester, find.byKey(const ValueKey('thread-more')));
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-reason-other')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();

      expect(find.text('REPORT POST'), findsOneWidget);
      expect(
        find.text(
            "You're doing that a lot. Please wait a few minutes and try again."),
        findsOneWidget,
      );
      expect(find.text(reportThanksMessage), findsNothing);
    });

    testWidgets('signed out, it asks you to sign in first', (tester) async {
      final h = await _pump(tester, signedIn: false);
      await _openMenu(tester, find.byKey(const ValueKey('thread-more')));
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();

      expect(find.text('REPORT POST'), findsNothing);
      expect(find.text('Sign in to report a post.'), findsOneWidget);
      expect(h.moderation.calls, isEmpty);
    });
  });

  group('blocking', () {
    testWidgets('confirmed, it hides their comments at once and refetches',
        (tester) async {
      final h = await _pump(tester);
      expect(h.threads.commentLoads, 1);

      await _openMenu(tester, _menuIn('theirs'));
      await tester.tap(find.text('Block Rahul'));
      await tester.pumpAndSettle();

      expect(find.text('BLOCK RAHUL?'), findsOneWidget);
      await tester.tap(find.text('BLOCK'));
      await tester.pumpAndSettle();

      expect(h.moderation.calls, ['block:7']);
      expect(find.text('Comment by Rahul'), findsNothing);
      expect(find.text('Comment by Aarav'), findsOneWidget);
      expect(find.text('Rahul is blocked.'), findsOneWidget);
      expect(h.threads.commentLoads, 2);
    });

    testWidgets('cancelled, nothing happens', (tester) async {
      final h = await _pump(tester);
      await _openMenu(tester, _menuIn('theirs'));
      await tester.tap(find.text('Block Rahul'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(h.moderation.calls, isEmpty);
      expect(find.text('Comment by Rahul'), findsOneWidget);
    });

    testWidgets('refused, their comments come back with a reason',
        (tester) async {
      final h = await _pump(tester);
      h.moderation.blockResult = Either.left(const NetworkFailure());

      await _openMenu(tester, _menuIn('theirs'));
      await tester.tap(find.text('Block Rahul'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BLOCK'));
      await tester.pumpAndSettle();

      expect(find.text('Comment by Rahul'), findsOneWidget);
      expect(find.text('No connection. Check your internet and try again.'),
          findsOneWidget);
      expect(h.threads.commentLoads, 1);
    });
  });
}
