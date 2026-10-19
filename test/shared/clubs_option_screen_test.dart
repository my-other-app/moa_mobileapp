import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/shared/widgets/clubs_option_screen.dart';
import 'package:finnet/shared/widgets/app_toggle.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's mutes: [muted] null is a server that keeps none.
class _FakeMutes implements PushSettingsRepository {
  _FakeMutes(this.muted, {this.refuse = false});

  bool? muted;
  final bool refuse;
  final calls = <bool>[];

  @override
  Future<Result<bool?>> isClubMuted(int clubId) async => Either.right(muted);

  @override
  Future<Result<void>> setClubMuted(int clubId, {required bool muted}) async {
    calls.add(muted);
    if (refuse) {
      return Either.left(
          const ServerFailure(message: 'You do not follow this club'));
    }
    this.muted = muted;
    return Either.right(null);
  }

  @override
  Future<Result<PushSwitches?>> switches() async => Either.right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

Future<List<Object?>> _open(WidgetTester tester, _FakeMutes mutes) async {
  // A phone: 360 x 800.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final results = <Object?>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [pushSettingsRepositoryProvider.overrideWithValue(mutes)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await showModalBottomSheet<Object?>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const ClubsOptionScreen(
                clubName: 'Circuit Society',
                imageUrl: '',
                clubId: 12,
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

const _mute = ValueKey('club-option-mute');

/// The club's notifications switch: on until the club is muted.
bool _notificationsOn(WidgetTester tester) =>
    tester.widget<SettingsRow>(find.byKey(_mute)).value!;

void main() {
  testWidgets('a club that is not muted can be muted', (tester) async {
    final mutes = _FakeMutes(false);
    final results = await _open(tester, mutes);

    // A switch of the Settings design, on while the club is not muted.
    expect(find.text('Notifications'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(_mute), matching: find.byType(AppToggle)),
        findsOneWidget);
    expect(_notificationsOn(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('club-option-mute')));
    await tester.pumpAndSettle();

    expect(mutes.calls, [true]);
    expect(
        results.single, {'action': 'mute', 'success': true, 'isMuted': true});
  });

  testWidgets('a muted club can be unmuted', (tester) async {
    final mutes = _FakeMutes(true);
    final results = await _open(tester, mutes);

    expect(find.text('Notifications'), findsOneWidget);
    expect(_notificationsOn(tester), isFalse);
    await tester.tap(find.byKey(const ValueKey('club-option-mute')));
    await tester.pumpAndSettle();

    expect(mutes.calls, [false]);
    expect(
        results.single, {'action': 'mute', 'success': true, 'isMuted': false});
  });

  testWidgets('a server that keeps no mutes shows no option', (tester) async {
    await _open(tester, _FakeMutes(null));

    expect(find.byKey(const ValueKey('club-option-mute')), findsNothing);
    expect(find.text('Unfollow'), findsOneWidget);
  });

  testWidgets('a refused mute says so and stays open', (tester) async {
    final mutes = _FakeMutes(false, refuse: true);
    final results = await _open(tester, mutes);

    await tester.tap(find.byKey(const ValueKey('club-option-mute')));
    await tester.pump();

    expect(find.textContaining('You do not follow this club'), findsOneWidget);
    expect(results, isEmpty);
    expect(_notificationsOn(tester), isTrue);
  });
}
