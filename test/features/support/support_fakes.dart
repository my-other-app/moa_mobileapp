import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/profile/data/photo_picker.dart';
import 'package:finnet/features/support/data/support_api.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:finnet/features/support/presentation/support_routes.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A server that answers [status] (a 404 is one without the help desk).
ApiException apiError(int status, [String message = 'No']) => ApiException(
      message: message,
      statusCode: status,
      type: status == 404
          ? ApiExceptionType.notFound
          : status == 429
              ? ApiExceptionType.badRequest
              : ApiExceptionType.server,
    );

/// The help desk, in memory. Each call is recorded; set [missing] for a
/// server without the desk (every call answers 404).
class FakeSupportApi extends SupportApi {
  FakeSupportApi({
    this.answers = const [],
    this.topicList = const [],
    this.requests = const [],
    Map<String, SupportRequestDetail>? details,
    this.missing = false,
  }) : details = details ?? {};

  List<HelpAnswer> answers;
  List<SupportTopic> topicList;
  List<SupportRequestSummary> requests;
  final Map<String, SupportRequestDetail> details;
  bool missing;

  /// What POST /support/requests answers with, else a new request #1042.
  Object? sendError;
  Object? uploadError;

  final sentRequests = <Map<String, Object?>>[];
  final uploads = <String>[];
  final replies = <(String, String, List<String>)>[];
  final surveys = <(String, bool)>[];
  int detailReads = 0;

  void _desk() {
    if (missing) throw apiError(404, 'Not Found');
  }

  @override
  Future<List<HelpAnswer>> help() async {
    _desk();
    return answers;
  }

  @override
  Future<List<SupportTopic>> topics() async {
    _desk();
    return topicList;
  }

  @override
  Future<SupportUpload> upload(String path) async {
    uploads.add(path);
    if (uploadError != null) throw uploadError!;
    final name = path.split('/').last;
    return SupportUpload(key: 'key-$name', name: name);
  }

  @override
  Future<SupportRequestSent> send({
    required String topic,
    required String message,
    List<String> attachments = const [],
    SupportContext context = const SupportContext(),
  }) async {
    _desk();
    sentRequests.add({
      'topic': topic,
      'message': message,
      'attachments': attachments,
      'context': context.toJson(),
    });
    if (sendError != null) throw sendError!;
    return const SupportRequestSent(id: '77', number: 1042);
  }

  @override
  Future<List<SupportRequestSummary>> mine() async {
    _desk();
    return requests;
  }

  @override
  Future<SupportRequestDetail> request(String id) async {
    _desk();
    detailReads++;
    final detail = details[id];
    if (detail == null) throw apiError(404, 'Not Found');
    return detail;
  }

  @override
  Future<void> reply(String id,
      {required String message, List<String> attachments = const []}) async {
    _desk();
    replies.add((id, message, attachments));
  }

  @override
  Future<void> survey(String id, {required bool solved}) async {
    surveys.add((id, solved));
  }
}

/// Hands back [paths] in turn, one per pick.
class FakeScreenshotPicker implements PhotoPicker {
  FakeScreenshotPicker(this.paths);

  final List<String> paths;
  final asked = <PhotoSource>[];

  @override
  Future<String?> pick(PhotoSource source) async {
    asked.add(source);
    return paths.isEmpty ? null : paths.removeAt(0);
  }
}

/// The help screens under a router of their own, starting at [location].
/// Answers what was opened outside the app.
Future<({GoRouter router, List<Uri> opened})> pumpSupport(
  WidgetTester tester, {
  required FakeSupportApi api,
  String location = SupportLocations.help,
  List<SupportEventChoice> events = const [],
  FakeScreenshotPicker? picker,
  Map<String, int> sizes = const {},
  bool launches = true,
}) async {
  final opened = <Uri>[];
  final rootKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, __) => const Scaffold(body: Text('profile')),
            routes: supportRoutes(rootKey),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      supportApiProvider.overrideWithValue(api),
      supportEventChoicesProvider.overrideWithValue(events),
      supportAppVersionProvider.overrideWithValue(() async => '1.2.1+8'),
      supportFileSizeProvider
          .overrideWithValue((path) async => sizes[path] ?? 1000),
      screenshotPickerProvider
          .overrideWithValue(picker ?? FakeScreenshotPicker([])),
      linkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return launches;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.pump();
  return (router: router, opened: opened);
}
