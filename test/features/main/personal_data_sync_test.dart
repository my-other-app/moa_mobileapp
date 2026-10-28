import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/services/app_badge.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/registration_requests_api.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/main/presentation/widgets/personal_data_sync.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:finnet/features/notifications/presentation/providers/push_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/services/app_badge_fakes.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  void set(AuthState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// Counts the server's reads of the switches.
class _Switches implements PushSettingsRepository {
  int checks = 0;

  @override
  Future<PushSwitches?> savedSwitches() async => null;

  @override
  Future<Result<PushSwitches?>> switches() async {
    checks++;
    return Either.right(
        const PushSwitches(clubs: false, topics: true, platform: true));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

NotificationModel _line(String id, String title) => NotificationModel(
      id: id,
      userId: 1,
      title: title,
      description: '',
      type: 'club_thread',
      status: 'unread',
      createdAt: DateTime(2026, 10, 22, 9),
      updatedAt: DateTime(2026, 10, 22, 9),
    );

/// The inbox: a saved first page, and the server's, which a test may hold.
class _Inbox implements NotificationRepository {
  NotificationPage? saved;
  List<NotificationModel> fresh = const [];
  int reads = 0;
  Completer<void>? hold;

  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => saved;

  @override
  Future<Result<NotificationPage>> fetchList({
    required int limit,
    required int offset,
    String? cursor,
  }) async {
    reads++;
    if (hold != null) await hold!.future;
    return Either.right(NotificationPage(items: fresh, total: fresh.length));
  }

  int counts = 0;

  @override
  Future<Result<int>> unreadCount() async {
    counts++;
    return Either.right(fresh.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The person's requests for a place: counts the server's reads; a 404
/// (an older server) when [missing].
class _Requests extends RegistrationRequestsApi {
  int reads = 0;
  bool missing = false;

  @override
  Future<List<RegistrationRequest>?> savedMine() async => null;

  @override
  Future<List<RegistrationRequest>?> mine() async {
    reads++;
    return missing ? null : const [];
  }
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

void main() {
  late _FakeAuth auth;
  late _Switches switches;
  late _Inbox inbox;
  late _Requests requests;
  late ValueNotifier<int> arrivals;
  late DateTime now;
  late ProviderContainer container;
  late FakeBadgeChannel icon;

  Future<void> pump(WidgetTester tester, AuthState start) async {
    auth = _FakeAuth(start);
    switches = _Switches();
    inbox = _Inbox();
    requests = _Requests();
    arrivals = ValueNotifier(0);
    now = DateTime(2026, 10, 22, 9);
    icon = FakeBadgeChannel.install();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appBadgeProvider.overrideWithValue(icon.badge()),
        authStateProvider.overrideWith((ref) => auth),
        pushSettingsRepositoryProvider.overrideWithValue(switches),
        notificationRepositoryProvider.overrideWithValue(inbox),
        registrationRequestsApiProvider.overrideWithValue(requests),
      ],
      child: MaterialApp(
        home: PersonalDataSync(
          arrivals: arrivals,
          now: () => now,
          child: Consumer(builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const Text('the app');
          }),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'signed in, the switches and the inbox are read before anyone opens '
      'Settings or the inbox', (tester) async {
    await pump(tester, _signedIn);

    expect(switches.checks, 1);
    expect(inbox.reads, 1);
    expect(container.read(pushSwitchesProvider).switches?.clubs, isFalse);
    expect(container.read(pushSwitchesProvider).checked, isTrue);
  });

  testWidgets(
      'a push while the app is open reads the requests again -- once they '
      'have been read, and the server has them', (tester) async {
    await pump(tester, _signedIn);
    expect(requests.reads, 0, reason: 'nobody has looked at them yet');

    arrivals.value++;
    await tester.pump();
    expect(requests.reads, 0);

    await container.read(myRegistrationRequestsProvider.notifier).refresh();
    expect(requests.reads, 1);
    arrivals.value++;
    await tester.pump();
    expect(requests.reads, 2);

    // An older server: never again.
    requests.missing = true;
    arrivals.value++;
    await tester.pump();
    expect(requests.reads, 3);
    arrivals.value++;
    await tester.pump();
    expect(requests.reads, 3);
  });

  testWidgets('signed out, nothing is asked; signing in asks at once',
      (tester) async {
    await pump(tester, _signedOut);
    expect(switches.checks, 0);
    expect(inbox.reads, 0);

    auth.set(_signedIn);
    await tester.pump();
    await tester.pump();
    expect(switches.checks, 1);
    expect(inbox.reads, 1);
  });

  testWidgets('a push while the app is open: the inbox reads itself again',
      (tester) async {
    await pump(tester, _signedIn);
    inbox.fresh = [_line('n-1', 'Code Club posted an update')];

    arrivals.value++;
    await tester.pump();
    await tester.pump();

    expect(inbox.reads, 2);
    expect(container.read(notificationsProvider).notifications.single.title,
        'Code Club posted an update');
  });

  testWidgets('back to the front: read again, but not more than every 5 min',
      (tester) async {
    await pump(tester, _signedIn);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(switches.checks, 1, reason: 'a moment ago');

    now = now.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(switches.checks, 2);
    expect(inbox.reads, 2);
  });

  group('the number on the app\'s icon', () {
    testWidgets('start-up reads the unread count and puts it on the icon',
        (tester) async {
      await pump(tester, _signedIn);
      await tester.pump();

      expect(inbox.counts, 1);
      expect(icon.counts, [0],
          reason: 'nothing unread: 0, not what a push left');
    });

    testWidgets(
        'back to the front -- a tap on a push, say -- reads the count every '
        'time, however recently the inbox was read', (tester) async {
      await pump(tester, _signedIn);
      await tester.pump();
      inbox.fresh = [_line('n-1', 'Code Club posted an update')];

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(inbox.reads, 1, reason: 'the list itself waits its 5 minutes');
      expect(inbox.counts, 2);
      expect(icon.shown, 1);

      inbox.fresh = const [];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(inbox.counts, 3);
      expect(icon.counts, [0, 1, 0]);
    });

    testWidgets('a push while the app is open sets it from the new count',
        (tester) async {
      await pump(tester, _signedIn);
      await tester.pump();
      inbox.fresh = [_line('n-1', 'Code Club posted an update')];

      arrivals.value++;
      await tester.pump();
      await tester.pump();

      expect(icon.shown, 1);
    });

    testWidgets('signed out, coming back to the front asks nothing',
        (tester) async {
      await pump(tester, _signedOut);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(inbox.counts, 0);
      expect(icon.calls, isEmpty);
    });
  });

  group('the inbox read ahead', () {
    test('opening the inbox while the read ahead is out sends no second read',
        () async {
      final inbox = _Inbox()..hold = Completer<void>();
      final container = ProviderContainer(overrides: [
        notificationRepositoryProvider.overrideWithValue(inbox),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(notificationsProvider.notifier);

      final ahead = notifier.prefetch();
      final opened = notifier.loadNotifications();
      await Future<void>.delayed(Duration.zero);
      inbox.hold!.complete();
      await Future.wait([ahead, opened]);

      expect(inbox.reads, 1);
    });

    test('the saved page first, then the server\'s, newest on top', () async {
      final inbox = _Inbox()
        ..saved = NotificationPage(items: [_line('old', 'Older')], total: 1)
        ..fresh = [_line('new', 'Newer'), _line('old', 'Older')]
        ..hold = Completer<void>();
      final container = ProviderContainer(overrides: [
        notificationRepositoryProvider.overrideWithValue(inbox),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(notificationsProvider.notifier);

      final reading = notifier.prefetch();
      await Future<void>.delayed(Duration.zero);
      expect(
          container.read(notificationsProvider).notifications.map((n) => n.id),
          ['old']);
      inbox.hold!.complete();
      await reading;
      expect(
          container.read(notificationsProvider).notifications.map((n) => n.id),
          ['new', 'old']);
    });
  });
}
