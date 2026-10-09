import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = UserProfile(
  id: '1',
  fullName: 'Aarav Menon',
  email: 'aarav@example.com',
  phone: '9876543210',
  interests: [],
  isProfileComplete: true,
);

class _FakeRepository implements ProfileRepository {
  int getMyProfileCalls = 0;
  Result<UserProfile> result = Either.right(_profile);
  Duration delay = Duration.zero;

  @override
  Future<Result<UserProfile>> getMyProfile() async {
    getMyProfileCalls++;
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

ProviderContainer _containerWith(_FakeRepository repository) {
  final container = ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('the profile loads itself', () {
    test('reading the provider fetches, without anyone calling loadProfile',
        () async {
      // The bug: ProfileNotifier started empty and waited for a screen to
      // call loadProfile(). Only the profile screens, login and onboarding
      // ever did. Opening the app with a stored token skips login, so the
      // event registration form -- one of eight screens that watch this --
      // read a state nobody had filled and showed blank name, email and
      // phone, with no error and nothing to retry.
      final repository = _FakeRepository();
      final container = _containerWith(repository);

      container.read(profileProvider);
      await Future<void>.delayed(Duration.zero);

      expect(repository.getMyProfileCalls, 1);
      expect(container.read(profileProvider).profile?.fullName, 'Aarav Menon');
    });

    test('several readers share one request rather than each making their own',
        () async {
      // Eight screens watch this provider and several can mount together.
      final repository = _FakeRepository()
        ..delay = const Duration(milliseconds: 20);
      final container = _containerWith(repository);

      // Concurrent, not sequential: a later call is a deliberate refresh and
      // should refetch. What must not happen is three screens mounting at
      // once and each firing its own request.
      container.read(profileProvider);
      await Future.wait([
        container.read(profileProvider.notifier).loadProfile(),
        container.read(profileProvider.notifier).loadProfile(),
      ]);

      expect(repository.getMyProfileCalls, 1);
    });

    test('force refetches even while one is in flight', () async {
      // Saving a profile has to see its own write, not a cached read.
      final repository = _FakeRepository();
      final container = _containerWith(repository);

      container.read(profileProvider);
      await Future<void>.delayed(Duration.zero);
      await container.read(profileProvider.notifier).loadProfile(force: true);

      expect(repository.getMyProfileCalls, 2);
    });

    test('a failure surfaces as an error, not a silent blank form', () async {
      // The old behaviour and a failed load were indistinguishable: empty
      // fields either way. A consumer can now tell them apart.
      final repository = _FakeRepository()
        ..result = Either.left(NetworkFailure(message: 'No connection'));
      final container = _containerWith(repository);

      container.read(profileProvider);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(profileProvider);
      expect(state.profile, isNull);
      expect(state.error, 'No connection');
      expect(state.isLoading, isFalse);
    });
  });
}
