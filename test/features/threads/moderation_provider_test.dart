import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/providers/moderation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'moderation_fakes.dart';

void main() {
  late FakeModerationRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeModerationRepository();
    container = ProviderContainer(overrides: [
      moderationRepositoryProvider.overrideWithValue(repository),
      isAuthenticatedProvider.overrideWithValue(true),
    ]);
    addTearDown(container.dispose);
  });

  ModerationNotifier notifier() => container.read(moderationProvider.notifier);
  ModerationState state() => container.read(moderationProvider);

  group('block', () {
    test("hides the person's comments before the server answers", () async {
      repository.blockGate = Completer<void>();

      final pending = notifier().block(7, name: 'Rahul');
      expect(state().hiddenUserIds, {7});

      repository.blockGate!.complete();
      expect(await pending, isNull);
      expect(state().hiddenUserIds, {7});
      expect(state().blocked, const [BlockedUser(userId: 7, name: 'Rahul')]);
    });

    test('a refused block brings the comments back', () async {
      repository.blockResult = Either.left(
        const ServerFailure(message: 'Server error', code: '500'),
      );

      final failure = await notifier().block(7, name: 'Rahul');

      expect(failure, isNotNull);
      expect(state().hiddenUserIds, isEmpty);
      expect(state().blocked, isEmpty);
    });

    test('"already blocked" (409) counts as blocked', () async {
      repository.blockResult = Either.left(
        const UnknownFailure(message: 'Already blocked', code: '409'),
      );

      expect(await notifier().block(7, name: 'Rahul'), isNull);
      expect(state().hiddenUserIds, {7});
    });

    test('a second block of the same person asks nothing', () async {
      await notifier().block(7, name: 'Rahul');
      await notifier().block(7, name: 'Rahul');

      expect(repository.calls, ['block:7']);
    });

    test('no id, no block', () async {
      final failure = await notifier().block(0, name: 'Ghost');

      expect(failure, isA<ValidationFailure>());
      expect(repository.calls, isEmpty);
    });
  });

  group('unblock', () {
    setUp(() {
      repository.listResult = Either.right(const [
        BlockedUser(userId: 7, name: 'Rahul'),
        BlockedUser(userId: 8, name: 'Asha'),
      ]);
    });

    test('takes them off the list and stops hiding them', () async {
      await notifier().loadBlocked();
      expect(state().hiddenUserIds, {7, 8});

      expect(await notifier().unblock(7), isNull);

      expect(state().blocked.map((u) => u.userId), [8]);
      expect(state().hiddenUserIds, {8});
      expect(state().unblocking, isEmpty);
    });

    test('"not blocked" (404) counts as unblocked', () async {
      await notifier().loadBlocked();
      repository.unblockResult = Either.left(
        const ServerFailure(message: 'Not found', code: '404'),
      );

      expect(await notifier().unblock(7), isNull);
      expect(state().blocked.map((u) => u.userId), [8]);
    });

    test('a failure keeps them blocked and answers it', () async {
      await notifier().loadBlocked();
      repository.unblockResult = Either.left(const NetworkFailure());

      expect(await notifier().unblock(7), isA<NetworkFailure>());
      expect(state().blocked.map((u) => u.userId), [7, 8]);
      expect(state().unblocking, isEmpty);
    });
  });

  group('loadBlocked', () {
    test('a failure is said in plain words', () async {
      repository.listResult = Either.left(const NetworkFailure());

      await notifier().loadBlocked();

      expect(state().hasLoaded, isFalse);
      expect(state().error, 'No connection. Check your internet and try again.');
    });
  });

  group('report', () {
    test('sends the target, reason and trimmed note', () async {
      final failure = await notifier().report(
        const ReportTarget.comment('c1'),
        ReportReason.harassment,
        note: '  keeps posting this  ',
      );

      expect(failure, isNull);
      expect(repository.lastTarget, const ReportTarget.comment('c1'));
      expect(repository.lastReason, ReportReason.harassment);
      expect(repository.lastNote, 'keeps posting this');
    });

    test('a blank note is no note', () async {
      await notifier().report(
        const ReportTarget.thread('t1'),
        ReportReason.spam,
        note: '   ',
      );
      expect(repository.lastNote, isNull);
    });

    test('an over-long note never leaves', () async {
      final failure = await notifier().report(
        const ReportTarget.thread('t1'),
        ReportReason.spam,
        note: 'x' * (maxReportNoteLength + 1),
      );

      expect(failure, isA<ValidationFailure>());
      expect(repository.calls, isEmpty);
    });

    test('a rate limit comes back as the failure', () async {
      repository.reportResult = Either.left(
        const UnknownFailure(message: 'Rate limit exceeded', code: '429'),
      );

      final failure = await notifier().report(
        const ReportTarget.thread('t1'),
        ReportReason.spam,
      );

      expect(failure?.code, '429');
    });
  });

  group('moderationFailureMessage', () {
    const fallback = 'Something went wrong.';

    test('a rate limit gets its own words, not the server text', () {
      expect(
        moderationFailureMessage(
          const UnknownFailure(message: 'Rate limit exceeded: 5/1m', code: '429'),
          fallback: fallback,
        ),
        "You're doing that a lot. Please wait a few minutes and try again.",
      );
    });

    test('no connection says so', () {
      expect(
        moderationFailureMessage(const NetworkFailure(), fallback: fallback),
        'No connection. Check your internet and try again.',
      );
    });

    test("a 400 keeps the server's words", () {
      expect(
        moderationFailureMessage(
          const ValidationFailure(message: "You can't block yourself"),
          fallback: fallback,
        ),
        "You can't block yourself",
      );
    });

    test('anything else gets the fallback, not a status', () {
      expect(
        moderationFailureMessage(
          const ServerFailure(message: 'Server error. Please try again later.'),
          fallback: fallback,
        ),
        fallback,
      );
    });
  });

  test('signing out starts a fresh set of blocks', () async {
    final auth = StateProvider<bool>((ref) => true);
    final c = ProviderContainer(overrides: [
      moderationRepositoryProvider.overrideWithValue(repository),
      isAuthenticatedProvider.overrideWith((ref) => ref.watch(auth)),
    ]);
    addTearDown(c.dispose);
    // Kept alive the way a watching page keeps it.
    c.listen(moderationProvider, (_, __) {});

    await c.read(moderationProvider.notifier).block(7, name: 'Rahul');
    expect(c.read(moderationProvider).hiddenUserIds, {7});

    c.read(auth.notifier).state = false;
    expect(c.read(moderationProvider).hiddenUserIds, isEmpty);
  });
}
