// A certificate's DOWNLOAD CERTIFICATE (and the toolbar's Open the PDF):
// the PDF kept on the phone, opened in the phone's own viewer -- which can
// save and share it -- offline from the kept copy; the browser only when
// there is no viewer or no PDF, and a plain note when nothing can open it.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

const _id = 'MOA-9ARSE-J4TEG';
const _keptPath = '/kept/documents/certificate_$_id.pdf';
const _browser = MethodChannel('plugins.flutter.io/url_launcher');

final _certificate = Certificate(
  ticketId: _id,
  eventId: 29,
  eventName: 'Rapid Chess Open and Board Game Night',
  clubName: 'Respawn Room',
  issuedOn: DateTime(2026, 10, 2),
);

/// The certificate's documents, with the PDF's answer set by each test.
class _Documents extends MemoryCertificateDocuments {
  _Documents(this.answer);

  SavedDocument Function() answer;
  final asked = <String>[];

  @override
  Future<SavedDocument> pdf(String ticketId) async {
    asked.add(ticketId);
    return answer();
  }
}

SavedDocument _kept({bool current = true}) =>
    SavedDocument(file: File(_keptPath), current: current);

DioException _error(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/events/certificates/$_id/pdf');
  return DioException(
    requestOptions: options,
    type: type,
    response:
        status == null ? null : Response(requestOptions: options, statusCode: status),
    error: type == DioExceptionType.connectionError
        ? const SocketException('offline')
        : null,
  );
}

/// What the screen asked the browser to open, answered with [answer].
List<String> _browserCalls(WidgetTester tester, {bool answer = true}) {
  final urls = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_browser, (call) async {
    if (call.method == 'launch') {
      final args = call.arguments as Map;
      // A browser or viewer, not a web view inside the app.
      expect(args['useWebView'], isFalse);
      urls.add(args['url'] as String);
      return answer;
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_browser, null));
  return urls;
}

/// The certificate screen; [viewer] says whether the phone's viewer opened
/// what it was given. Returns what was handed to the viewer.
Future<List<String>> _pump(
  WidgetTester tester,
  _Documents documents, {
  bool viewer = true,
}) async {
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      certificateDocumentsProvider.overrideWithValue(documents),
      networkStatusProvider
          .overrideWithValue(NetworkStatus(probe: () async => false)),
      certificatePdfOpenerProvider.overrideWithValue((path) async {
        opened.add(path);
        return viewer;
      }),
    ],
    child: MaterialApp(home: CertificateDetailPage(certificate: _certificate)),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return opened;
}

Future<void> _tap(WidgetTester tester, Finder button) async {
  await tester.tap(button);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _download = find.text('DOWNLOAD CERTIFICATE');

void main() {
  setUp(useFakeApi);

  testWidgets("DOWNLOAD CERTIFICATE opens the kept PDF in the phone's viewer",
      (tester) async {
    final documents = _Documents(_kept);
    final browser = _browserCalls(tester);
    final opened = await _pump(tester, documents);

    await _tap(tester, _download);

    expect(documents.asked, [_id]);
    expect(opened, [_keptPath]);
    expect(browser, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets("the toolbar's Open the PDF does the same", (tester) async {
    final documents = _Documents(_kept);
    final opened = await _pump(tester, documents);

    await _tap(tester, find.byTooltip('Open the PDF'));

    expect(opened, [_keptPath]);
  });

  testWidgets('offline, the copy saved on the phone opens, and it says so',
      (tester) async {
    final opened = await _pump(tester, _Documents(() => _kept(current: false)));

    await _tap(tester, _download);

    expect(opened, [_keptPath]);
    expect(find.text('Offline — this is your saved copy'), findsOneWidget);
  });

  testWidgets(
      'offline and never saved: says so, with no browser that cannot load '
      'it either', (tester) async {
    final browser = _browserCalls(tester);
    final opened = await _pump(tester,
        _Documents(() => throw _error(DioExceptionType.connectionError)));

    await _tap(tester, _download);

    expect(opened, isEmpty);
    expect(browser, isEmpty);
    expect(find.text("You're offline, and this PDF hasn't been saved yet"),
        findsOneWidget);
  });

  testWidgets("a phone with no PDF viewer: the PDF's address in the browser",
      (tester) async {
    final browser = _browserCalls(tester);
    final opened = await _pump(tester, _Documents(_kept), viewer: false);

    await _tap(tester, _download);

    expect(opened, [_keptPath]);
    expect(browser, [_certificate.pdfUrl(Env.apiBaseUrl)]);
    expect(find.text('Could not open the certificate'), findsNothing);
  });

  testWidgets('a PDF the server would not give: the browser instead',
      (tester) async {
    final browser = _browserCalls(tester);
    final opened = await _pump(tester,
        _Documents(() => throw _error(DioExceptionType.badResponse, status: 500)));

    await _tap(tester, _download);

    expect(opened, isEmpty);
    expect(browser, [_certificate.pdfUrl(Env.apiBaseUrl)]);
  });

  testWidgets('nothing on the phone can open it: says so', (tester) async {
    final browser = _browserCalls(tester, answer: false);
    await _pump(tester, _Documents(_kept), viewer: false);

    await _tap(tester, _download);

    expect(browser, hasLength(1));
    expect(find.text('Could not open the certificate'), findsOneWidget);
  });
}
