import 'package:dio/dio.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart' show RouteAdapter, useFakeApi;

const _asha = UserProfile(
  id: '7',
  fullName: 'Asha Menon',
  email: 'asha@example.com',
  whatsapp: '9876543210',
  organization: Organization(id: 2, name: 'GEC Thrissur'),
  interests: [Interest(id: 4, name: 'Robotics')],
);

/// The profile the server has, counting how often it is read.
class _Profiles implements ProfileRepository {
  _Profiles(this.profile);

  UserProfile profile;
  int reads = 0;

  @override
  Future<UserProfile?> getSavedProfile() async => null;

  @override
  Future<Result<UserProfile>> getMyProfile() async {
    reads++;
    return Either.right(profile);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  late RouteAdapter api;
  late _Profiles profiles;
  late List<String> opened;

  setUp(() {
    api = useFakeApi()
      ..on('GET', '/orgs/list', [
        {'id': 1, 'name': 'CET Trivandrum'},
        {'id': 2, 'name': 'GEC Thrissur'},
      ]);
    opened = [];
  });

  /// Edit Profile, opened from a page that has the profile loaded (as the
  /// Profile tab has).
  Future<void> pumpEdit(WidgetTester tester,
      {UserProfile profile = _asha}) async {
    tester.view
      ..physicalSize = const Size(1200, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    profiles = _Profiles(profile);

    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(children: [
              Text(
                  'profile of ${ref.watch(profileProvider).profile?.fullName}'),
              TextButton(
                onPressed: () => context.push('/profile/edit'),
                child: const Text('Edit'),
              ),
            ]),
          ),
        ),
      ),
      GoRoute(
          path: '/profile/edit', builder: (_, __) => const EditProfilePage()),
      GoRoute(
        path: '/profile/interests',
        builder: (_, state) {
          opened.add(state.uri.path);
          return const Scaffold(body: Text('the interests picker'));
        },
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  String textOf(WidgetTester tester, String hint) =>
      tester.widget<TextFormField>(field(hint)).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'opens filled in: the name, the college, the WhatsApp number and the '
      'interests', (tester) async {
    await pumpEdit(tester);

    expect(find.text('EDIT PROFILE'), findsOneWidget);
    expect(textOf(tester, 'Enter your name'), 'Asha Menon');
    expect(textOf(tester, 'Enter your WhatsApp number'), '9876543210');
    expect(find.text('GEC Thrissur'), findsOneWidget);
    expect(find.text('Edit Interests'), findsOneWidget);
    expect(find.text('Robotics'), findsOneWidget);
    expect(api.sent('GET', '/orgs/list'), hasLength(1));
  });

  testWidgets(
      'SAVE sends the changes, reads the profile back, says so and closes',
      (tester) async {
    api.on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester);
    final readsBefore = profiles.reads;

    await tester.enterText(field('Enter your name'), 'Asha M');
    await tester.enterText(field('Enter your WhatsApp number'), '9123456780');
    await tester.tap(find.text('GEC Thrissur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CET Trivandrum').last);
    await tester.pumpAndSettle();
    profiles.profile = const UserProfile(
      id: '7',
      fullName: 'Asha M',
      email: 'asha@example.com',
    );
    await save(tester);

    final sent = api.sent('POST', '/user/profile/update').single;
    expect(sent.data,
        {'full_name': 'Asha M', 'whatsapp': '9123456780', 'org_id': 1});
    expect(sent.contentType, Headers.formUrlEncodedContentType);
    expect(profiles.reads, readsBefore + 1);
    expect(find.text('Profile updated successfully'), findsOneWidget);
    expect(find.text('EDIT PROFILE'), findsNothing);
    expect(find.text('profile of Asha M'), findsOneWidget);
  });

  testWidgets('a name is needed: nothing is sent without one', (tester) async {
    await pumpEdit(tester);
    await tester.enterText(field('Enter your name'), '');
    await save(tester);

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(api.sent('POST', '/user/profile/update'), isEmpty);
    expect(find.text('EDIT PROFILE'), findsOneWidget);
  });

  testWidgets(
      'a WhatsApp number, when given, must be ten digits: a short one is '
      'refused and nothing is sent, a full one is sent', (tester) async {
    api.on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester);
    await tester.enterText(field('Enter your WhatsApp number'), '98765');
    await save(tester);

    expect(find.text('Please enter a valid 10-digit number'), findsOneWidget);
    expect(api.sent('POST', '/user/profile/update'), isEmpty);
    expect(find.text('EDIT PROFILE'), findsOneWidget);

    await tester.enterText(field('Enter your WhatsApp number'), '9123456780');
    await save(tester);

    expect(api.sent('POST', '/user/profile/update').single.data,
        {'full_name': 'Asha Menon', 'whatsapp': '9123456780', 'org_id': 2});
    expect(find.text('Please enter a valid 10-digit number'), findsNothing);
    expect(find.text('EDIT PROFILE'), findsNothing);
  });

  testWidgets(
      'the WhatsApp number is optional: SAVE without one sends none, and saves',
      (tester) async {
    api.on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester);
    expect(find.text('WhatsApp Number (Optional)'), findsOneWidget);

    await tester.enterText(field('Enter your WhatsApp number'), '');
    await save(tester);

    final sent = api.sent('POST', '/user/profile/update').single;
    // Left out: the server clears what it is not sent.
    expect(sent.data, {'full_name': 'Asha Menon', 'org_id': 2});
    expect(find.text('Please enter a valid 10-digit number'), findsNothing);
    expect(find.text('Profile updated successfully'), findsOneWidget);
    expect(find.text('EDIT PROFILE'), findsNothing);
  });

  testWidgets('a refusal says why, in its words, and the form stays',
      (tester) async {
    api.on(
        'POST', '/user/profile/update', {'message': 'Invalid WhatsApp number'},
        status: 400);
    await pumpEdit(tester);
    final readsBefore = profiles.reads;
    await save(tester);

    expect(find.text('Invalid WhatsApp number'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('EDIT PROFILE'), findsOneWidget);
    expect(textOf(tester, 'Enter your name'), 'Asha Menon');
    expect(profiles.reads, readsBefore);
  });

  testWidgets('Edit Interests opens the interests picker', (tester) async {
    await pumpEdit(tester);
    await tester.ensureVisible(find.text('Edit Interests'));
    await tester.tap(find.text('Edit Interests'));
    await tester.pumpAndSettle();

    expect(opened, ['/profile/interests']);
    expect(find.text('the interests picker'), findsOneWidget);
  });

  const noCollege = UserProfile(
    id: '7',
    fullName: 'Asha Menon',
    email: 'asha@example.com',
    whatsapp: '9876543210',
  );

  testWidgets(
      'someone without a college is not given the first one on the list',
      (tester) async {
    await pumpEdit(tester, profile: noCollege);

    expect(find.text('CET Trivandrum'), findsNothing);
    expect(find.text('GEC Thrissur'), findsNothing);
    expect(find.text('Select your college'), findsWidgets);
    expect(find.byKey(EditProfilePage.clearCollegeKey), findsNothing);
  });

  testWidgets(
      'the college is optional: someone without one saves, and no college is '
      'sent', (tester) async {
    api.on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester, profile: noCollege);
    await save(tester);

    expect(find.text('Please select your college'), findsNothing);
    final sent = api.sent('POST', '/user/profile/update').single;
    expect(sent.data, {'full_name': 'Asha Menon', 'whatsapp': '9876543210'});
    expect(find.text('Profile updated successfully'), findsOneWidget);
    expect(find.text('EDIT PROFILE'), findsNothing);
  });

  testWidgets(
      'a college can be taken off: the cross clears it and SAVE sends none',
      (tester) async {
    api.on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester);
    expect(find.text('GEC Thrissur'), findsOneWidget);

    await tester.tap(find.byKey(EditProfilePage.clearCollegeKey));
    await tester.pumpAndSettle();

    expect(find.text('GEC Thrissur'), findsNothing);
    expect(find.text('CET Trivandrum'), findsNothing); // the menu stays shut
    expect(find.text('Select your college'), findsWidgets);
    expect(find.byKey(EditProfilePage.clearCollegeKey), findsNothing);

    await save(tester);

    expect(api.sent('POST', '/user/profile/update').single.data,
        {'full_name': 'Asha Menon', 'whatsapp': '9876543210'});
    expect(find.text('EDIT PROFILE'), findsNothing);
  });

  testWidgets(
      'a college the list leaves out stays theirs, not the first on the list',
      (tester) async {
    api.on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester,
        profile: const UserProfile(
          id: '7',
          fullName: 'Asha Menon',
          email: 'asha@example.com',
          whatsapp: '9876543210',
          organization: Organization(id: 9, name: 'NIT Calicut'),
        ));

    expect(find.text('NIT Calicut'), findsOneWidget);
    expect(find.text('CET Trivandrum'), findsNothing);
    await save(tester);

    expect(api.sent('POST', '/user/profile/update').single.data,
        {'full_name': 'Asha Menon', 'whatsapp': '9876543210', 'org_id': 9});
  });

  testWidgets('when the college list cannot be read, SAVE keeps their college',
      (tester) async {
    api = useFakeApi()
      ..on('GET', '/orgs/list', {'message': 'Server error'}, status: 500)
      ..on('POST', '/user/profile/update', {'message': 'Profile updated'});
    await pumpEdit(tester);

    expect(find.text('GEC Thrissur'), findsOneWidget);
    await save(tester);

    expect(api.sent('POST', '/user/profile/update').single.data,
        {'full_name': 'Asha Menon', 'whatsapp': '9876543210', 'org_id': 2});
  });
}
