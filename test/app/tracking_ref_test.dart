import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/tracking_ref.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/clubs/data/club_follow_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/events/events_fakes.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// A club's tracking link opens the app with `?ref=` (the `/l/{code}`
/// redirect lands on the page with it too); the code is kept and sent with
/// the registration and the follow it leads to, as the website does
/// (moa_events src/utils/ref.js).
void main() {
  tearDown(() => TrackingRef.instance = TrackingRef());

  group('TrackingRef', () {
    test("keeps a link's code, lower-cased", () {
      final ref = TrackingRef()
        ..remember(Uri.parse('https://myotherapp.in/clubs/robotics?ref=AB12cd'));
      expect(ref.current, 'ab12cd');
    });

    test('the /l/ redirect\'s landing page is read the same way', () {
      // api.myotherapp.in/l/{code} -> the page, ?utm_...&ref={code}&via=l
      final ref = TrackingRef()
        ..remember(Uri.parse('/events/hack-night-04?utm_source=insta'
            '&utm_medium=story&ref=k3x9p2&via=l'));
      expect(ref.current, 'k3x9p2');
    });

    test('a newer link replaces the code held', () {
      final ref = TrackingRef()
        ..remember(Uri.parse('/clubs/a?ref=first1'))
        ..remember(Uri.parse('/clubs/b?ref=second2'));
      expect(ref.current, 'second2');
    });

    test("a page without one keeps the code held", () {
      final ref = TrackingRef()
        ..remember(Uri.parse('/clubs/a?ref=first1'))
        ..remember(Uri.parse('/events/12'));
      expect(ref.current, 'first1');
    });

    test("the club site's own code (sref) is the weaker claim", () {
      final held = TrackingRef()
        ..remember(Uri.parse('/clubs/a?ref=poster1'))
        ..remember(Uri.parse('/events/12?sref=site99'));
      expect(held.current, 'poster1');

      final fresh = TrackingRef()..remember(Uri.parse('/events/12?sref=site99'));
      expect(fresh.current, 'site99');
    });

    test('a code not shaped like one is ignored', () {
      final ref = TrackingRef();
      for (final bad in ['qr-poster', 'abc', 'x' * 17, 'a b c d', '']) {
        ref.remember(Uri(path: '/clubs/a', queryParameters: {'ref': bad}));
      }
      expect(ref.current, isNull);
    });

    test('is sent for a day after the link, then dropped', () {
      var now = DateTime(2026, 10, 25, 9);
      final ref = TrackingRef(now: () => now)
        ..remember(Uri.parse('/clubs/a?ref=poster1'));
      now = now.add(const Duration(hours: 23));
      expect(ref.current, 'poster1');
      now = now.add(const Duration(hours: 2));
      expect(ref.current, isNull);
    });
  });

  group('the router keeps the code of a link that opens the app', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(
            const AuthState(accessToken: 'token', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
    });

    for (final link in [
      'https://myotherapp.in/clubs/circuit-society?ref=qr7poster',
      'https://myotherapp.in/events/hack-night-04?ref=qr7poster&via=l',
      '/clubs/circuit-society?ref=qr7poster',
    ]) {
      testWidgets(link, (tester) async {
        final router = container.read(routerProvider);
        await tester.pumpWidget(const SizedBox());
        final context = tester.element(find.byType(SizedBox));
        await router.configuration.redirect(
          context,
          router.configuration.findMatch(Uri.parse(link)),
          redirectHistory: [],
        );
        expect(TrackingRef.instance.current, 'qr7poster');
      });
    }
  });

  group('a follow', () {
    test("carries the link's code as ?ref=", () async {
      final api = useFakeApi()..on('POST', '/clubs/follow/5', {'id': 1});
      TrackingRef.instance.remember(Uri.parse('/clubs/5?ref=qr7poster'));

      await const ApiClubFollowService().follow(5);

      final sent = api.sent('POST', '/clubs/follow/5').single;
      expect(sent.queryParameters, {'ref': 'qr7poster'});
      expect(sent.data, isNull);
    });

    test('with "updates on WhatsApp" ticked, carries both', () async {
      final api = useFakeApi()..on('POST', '/clubs/follow/5', {'id': 1});
      TrackingRef.instance.remember(Uri.parse('/clubs/5?ref=qr7poster'));

      await const ApiClubFollowService().follow(5, clubUpdates: true);

      final sent = api.sent('POST', '/clubs/follow/5').single;
      expect(sent.queryParameters, {'ref': 'qr7poster'});
      expect(sent.data, {'club_updates_whatsapp': true});
    });

    test('without a link, is sent as it always was', () async {
      final api = useFakeApi()..on('POST', '/clubs/follow/5', {'id': 1});

      await const ApiClubFollowService().follow(5);

      expect(api.sent('POST', '/clubs/follow/5').single.queryParameters,
          isEmpty);
    });

    test('turning the WhatsApp updates on or off credits nothing', () async {
      final api = useFakeApi()..on('POST', '/clubs/follow/5', {'id': 1});
      TrackingRef.instance.remember(Uri.parse('/clubs/5?ref=qr7poster'));

      await const ApiClubFollowService().setClubUpdates(5, true);

      expect(api.sent('POST', '/clubs/follow/5').single.queryParameters,
          isEmpty);
    });
  });
}
