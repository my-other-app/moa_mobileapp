// A certificate's link, `/certificates/{id}`, signed in: the person's own
// opens the app's certificate screen whether the link has the certificate's
// public id (as the server sends it now) or an older ticket id; anyone
// else's public id is the website's public page; anyone else's older link
// opens nothing, and no website address is ever made from a ticket id.

import 'package:finnet/app/router/link_pages.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_detail_page.dart';
import 'package:finnet/features/profile/presentation/providers/certificates_provider.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);

const _mine = 'q7Lk2Vb9_xR4mT0aZ-c8NwPe';
const _theirs = 'Zz0-yX9_wV8uT7sR6qP5oN4m';

final _certificate = Certificate(
  ticketId: 'MOA-9ARSE-J4TEG',
  number: 'CERT-4TQ8B-ZKM2R',
  shareUrl: 'https://myotherapp.in/certificates/$_mine',
  eventId: 29,
  eventName: 'Rapid Chess Open',
  clubName: 'Respawn Room',
  issuedOn: DateTime(2026, 10, 2),
);

/// [CertificateLinkPage] for [id], signed in, holding [_certificate].
/// Returns what was handed to the browser.
Future<List<Uri>> _pump(WidgetTester tester, String id) async {
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => _FakeAuth(_signedIn)),
      certificatesProvider.overrideWith((ref) => Stream.value([_certificate])),
      certificatesKeptProvider.overrideWithValue(null),
      certificateDocumentsProvider
          .overrideWithValue(MemoryCertificateDocuments()),
      networkStatusProvider
          .overrideWithValue(NetworkStatus(probe: () async => false)),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      linkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
    child: MaterialApp(home: CertificateLinkPage(id: id)),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return opened;
}

void main() {
  setUp(useFakeApi);

  testWidgets('their own, by its public id: the certificate screen',
      (tester) async {
    await _pump(tester, _mine);

    final page = tester
        .widget<CertificateDetailPage>(find.byType(CertificateDetailPage));
    expect(page.certificate.ticketId, 'MOA-9ARSE-J4TEG');
  });

  testWidgets('their own, by an older ticket-id link: the certificate screen',
      (tester) async {
    await _pump(tester, 'MOA-9ARSE-J4TEG');

    expect(find.byType(CertificateDetailPage), findsOneWidget);
  });

  testWidgets("someone else's, by public id: the public page by that id",
      (tester) async {
    final opened = await _pump(tester, _theirs);

    expect(find.byType(CertificateDetailPage), findsNothing);
    await tester.tap(find.text('View certificate'));
    expect(opened.single.toString(),
        'https://myotherapp.in/certificates/$_theirs');
  });

  testWidgets("someone else's older ticket-id link: opens nothing, says so",
      (tester) async {
    final opened = await _pump(tester, 'MOA-AAAAA-BBBBB');

    expect(find.byType(CertificateDetailPage), findsNothing);
    expect(find.byKey(CertificateLinkPage.outdatedKey), findsOneWidget);
    expect(find.text('View certificate'), findsNothing);
    expect(opened, isEmpty);
  });
}
