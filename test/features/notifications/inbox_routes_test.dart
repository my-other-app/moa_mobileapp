import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:finnet/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:finnet/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_page.dart';
import 'package:finnet/features/profile/presentation/pages/notifications/notifications_page.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The inbox, with the lines a test gives it; what was marked read.
class _Inbox implements NotificationRepository {
  _Inbox(this.lines);

  final List<NotificationModel> lines;
  final read = <String>[];

  @override
  Future<NotificationPage?> savedFirstPage({required int limit}) async => null;

  @override
  Future<Result<NotificationPage>> fetchList({
    required int limit,
    required int offset,
    String? cursor,
  }) async =>
      Either.right(NotificationPage(items: lines, total: lines.length));

  @override
  Future<Result<int>> unreadCount() async =>
      Either.right(lines.where((n) => n.isUnread).length);

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    read.add(notificationId);
    return Either.right(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async => Either.right(null);
}

/// A line as `/notifications/fetch-list` sends it.
NotificationModel _line(
  String id,
  String type,
  String title, {
  String status = 'unread',
  Map<String, dynamic>? event,
  Map<String, dynamic>? club,
}) =>
    NotificationModel.fromJson({
      'id': id,
      'user_id': 1,
      'title': title,
      'description': '',
      'type': type,
      'status': status,
      'event': event,
      'from_club': club,
      'created_at': DateTime.now().toIso8601String(),
    });

final _volunteer = _line(
  'n-1',
  'volunteer_added',
  'You were added as a volunteer for Hack Night 04',
  event: {'id': 7, 'name': 'Hack Night 04'},
  club: {'id': 3, 'name': 'Makers'},
);

final _certificate = _line(
  'n-2',
  'certificate_generated',
  'Your certificate for Hack Night 04 is ready',
  status: 'read',
  event: {'id': 7, 'name': 'Hack Night 04'},
);

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  group('tapping a line in the inbox', () {
    late List<(String, Object?)> opened;

    Future<_Inbox> pump(WidgetTester tester, List<NotificationModel> lines) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      opened = [];
      final inbox = _Inbox(lines);
      Widget record(GoRouterState state, String name) {
        opened.add((state.uri.toString(), state.extra));
        return Scaffold(body: Text(name));
      }

      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const NotificationsNewPage()),
        GoRoute(
          path: '/volunteer/scanner/:eventId',
          builder: (_, state) => record(state, 'the scanner'),
        ),
        GoRoute(
          path: '/profile/certificates',
          builder: (_, state) => record(state, 'my certificates'),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(inbox)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      await tester.pump();
      return inbox;
    }

    testWidgets("'added as a volunteer' opens the scanner for its event",
        (tester) async {
      final inbox = await pump(tester, [_volunteer, _certificate]);

      expect(find.text('🎖️'), findsOneWidget);
      await tester.tap(find.text(_volunteer.title));
      await tester.pumpAndSettle();

      expect(find.text('the scanner'), findsOneWidget);
      expect(opened.single.$1, '/volunteer/scanner/7');
      expect(opened.single.$2, {'eventName': 'Hack Night 04', 'clubName': 'Makers'});
      // An unread line is read once opened.
      expect(inbox.read, ['n-1']);
    });

    testWidgets("'certificate ready' opens My Certificates", (tester) async {
      final inbox = await pump(tester, [_volunteer, _certificate]);

      expect(find.text('🏆'), findsOneWidget);
      await tester.tap(find.text(_certificate.title));
      await tester.pumpAndSettle();

      expect(find.text('my certificates'), findsOneWidget);
      expect(opened.single.$1, '/profile/certificates');
      // Read already: nothing to mark.
      expect(inbox.read, isEmpty);
    });

    testWidgets('a volunteer line without its event opens nothing',
        (tester) async {
      final line = _line('n-3', 'volunteer_added', 'You were added');
      final inbox = await pump(tester, [line]);

      await tester.tap(find.text('You were added'));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.text('You were added'), findsOneWidget);
      expect(inbox.read, ['n-3']);
    });
  });

  group("the app's router has the screens those lines open", () {
    late GoRouter router;

    setUp(() {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(
            const AuthState(accessToken: 'token', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      router = container.read(routerProvider);
    });

    /// The screen the router builds for [location], with [extra].
    Widget screenAt(WidgetTester tester, String location, {Object? extra}) {
      final matches =
          router.configuration.findMatch(Uri.parse(location), extra: extra);
      expect(matches.isError, isFalse, reason: location);
      final last = matches.last;
      final state = last.buildState(router.configuration, matches);
      return (last.route as GoRoute)
          .builder!(tester.element(find.byType(SizedBox)), state);
    }

    testWidgets('the scanner, for the event and with its names',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final page = screenAt(tester, '/volunteer/scanner/7',
          extra: {'eventName': 'Hack Night 04', 'clubName': 'Makers'});

      expect(page, isA<VolunteerScannerPage>());
      page as VolunteerScannerPage;
      expect(page.eventId, 7);
      expect(page.eventName, 'Hack Night 04');
      expect(page.clubName, 'Makers');
    });

    testWidgets('My Certificates', (tester) async {
      await tester.pumpWidget(const SizedBox());
      expect(screenAt(tester, '/profile/certificates'), isA<CertificatePage>());
    });
  });
}
