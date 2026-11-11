import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/support/data/support_api.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show useFakeApi;

/// The help desk's answers as the app reads them (support-leads-contract.md,
/// "Public / signed-in"), and the calls it makes.
void main() {
  group('reading the desk', () {
    test('help answers keep their order and skip rows without words', () {
      final answers = HelpAnswer.listFrom([
        {'id': 1, 'topic': 'tickets', 'question': 'Where is my ticket?', 'answer': 'In My events.'},
        {'id': 2, 'question': '  ', 'answer': 'No question'},
        {'id': 3, 'question': 'Refunds?', 'answer': 'Within 7 days.'},
      ]);
      expect(answers.map((a) => a.id), ['1', '3']);
      expect(answers.first.topic, 'tickets');
      expect(HelpAnswer.listFrom({'items': [{'question': 'Q', 'answer': 'A'}]}),
          hasLength(1));
      expect(HelpAnswer.listFrom('nonsense'), isEmpty);
    });

    test('topics leave out the club dashboard\'s, and fall back to the seeded '
        'words', () {
      final topics = SupportTopic.listFrom([
        {'key': 'account', 'label': 'Account'},
        {'key': 'dashboard', 'label': 'Club dashboard'},
        {'key': 'bug'},
      ]);
      expect(topics.map((t) => t.key), ['account', 'bug']);
      expect(topics.last.label, 'bug');
      expect(SupportTopic.labelFor('payments'), 'Payments and refunds');
      expect(SupportTopic.labelFor('new_thing'), 'New thing');
      expect(SupportTopic.labelFor(null), 'Request');
    });

    test('a request in the list: number, status and the unread dot', () {
      final rows = SupportRequestSummary.listFrom([
        {
          'id': 7,
          'number': 1042,
          'subject': 'Refund for Hack Night',
          'topic': 'payments',
          'status': 'waiting',
          'updated_at': '2026-11-11T09:00:00+05:30',
          'unread': true,
        },
        {'number': 1}, // no id: nothing to open
      ]);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.id, '7');
      expect(supportNumber(row.number), '#1042');
      expect(row.status, SupportStatus.waiting);
      expect(row.status.label, 'Waiting for you');
      expect(row.unread, isTrue);
      expect(row.updatedAt, isNotNull);
    });

    test('statuses read as the asker sees them', () {
      expect(supportStatusFrom('new').label, 'Sent');
      expect(supportStatusFrom('open').label, 'Open');
      expect(supportStatusFrom('resolved').label, 'Solved');
      expect(supportStatusFrom('closed').label, 'Closed');
      expect(supportStatusFrom('something').label, 'Open');
      expect(SupportStatus.resolved.isDone, isTrue);
      expect(SupportStatus.waiting.isDone, isFalse);
    });

    test('a thread: the person\'s and the team\'s messages, never a note', () {
      final detail = SupportRequestDetail.fromJson({
        'id': 7,
        'number': 1042,
        'status': 'open',
        'messages': [
          {'id': 1, 'kind': 'reply_in', 'body_text': 'My ticket is missing', 'author_name': 'Asha', 'attachments': [{'name': 'shot.png', 'url': 'https://files.myotherapp.in/s/1'}]},
          {'id': 2, 'kind': 'note', 'body_text': 'internal: check payment'},
          {'id': 3, 'kind': 'reply_out', 'body_text': 'Found it!', 'author_name': 'Riya'},
          {'id': 4, 'kind': 'reply_out', 'body_text': '', 'attachments': []},
          {'id': 5, 'kind': 'reply_out', 'body_text': 'Bad link', 'attachments': [{'name': 'x', 'url': 'javascript:alert(1)'}]},
        ],
        'can_reply': true,
        'survey': null,
      }, id: '7');
      expect(detail.messages.map((m) => m.id), ['1', '3', '5']);
      expect(detail.messages.first.fromUs, isFalse);
      expect(detail.messages.first.attachments.single.url.toString(),
          'https://files.myotherapp.in/s/1');
      expect(detail.messages[1].fromUs, isTrue);
      expect(detail.messages.last.attachments.single.url, isNull);
      expect(detail.canReply, isTrue);
      expect(detail.surveyAnswered, isFalse);
    });

    test("the desk's own files open with the session; nothing else does",
        () {
      SupportAttachment? read(Object url) => SupportAttachment.fromJson(
          {'id': 4, 'name': 'shot one.png', 'url': url});
      final own = read('/api/v1/support/requests/7/attachments/4')!;
      expect(own.url, isNull);
      expect(own.apiPath, '/support/requests/7/attachments/4');
      expect(own.canOpen, isTrue);
      expect(own.fileName, '4-shot_one.png');
      expect(read('/support/requests/7/attachments/4')!.apiPath,
          '/support/requests/7/attachments/4');
      // Climbing out of the desk, or another part of the API: not opened.
      expect(read('/api/v1/support/../user/delete')!.canOpen, isFalse);
      expect(read('/api/v1/user/profile/me')!.canOpen, isFalse);
      expect(read('https://files.example.com/x.png')!.url, isNotNull);
    });

    test('the survey is asked when the server says so, else once solved', () {
      expect(
          SupportRequestDetail.fromJson(
              {'status': 'resolved', 'can_survey': false},
              id: '1').canSurvey,
          isFalse);
      expect(
          SupportRequestDetail.fromJson(
              {'status': 'closed', 'can_survey': true},
              id: '1').canSurvey,
          isTrue);
      expect(
          SupportRequestDetail.fromJson({'status': 'resolved'}, id: '1')
              .canSurvey,
          isTrue);
      expect(
          SupportRequestDetail.fromJson({
            'status': 'resolved',
            'survey': {'solved': true}
          }, id: '1').canSurvey,
          isFalse);
    });

    test('a reply that opened a new request says which', () {
      final sent = SupportReplySent.fromJson(
          {'id': 3, 'case_id': 80, 'number': 1050, 'new_case': true},
          caseId: '77');
      expect(sent.caseId, '80');
      expect(sent.newCase, isTrue);
      expect(SupportReplySent.fromJson({'id': 3}, caseId: '77').caseId, '77');
    });

    test('a closed request without can_reply takes none; an answered survey '
        'is not asked again', () {
      final detail = SupportRequestDetail.fromJson(
          {'status': 'closed', 'survey': {'solved': true}}, id: '9');
      expect(detail.id, '9');
      expect(detail.canReply, isFalse);
      expect(detail.surveyAnswered, isTrue);
    });

    test('an upload\'s key, from an object or a list', () {
      expect(SupportUpload.fromJson({'key': 'k1', 'name': 'a.png', 'size': 10})!.key,
          'k1');
      expect(SupportUpload.fromJson([{'key': 'k2'}])!.key, 'k2');
      expect(SupportUpload.fromJson({'items': [{'key': 'k3'}]})!.key, 'k3');
      expect(SupportUpload.fromJson({'name': 'no key'}), isNull);
    });

    test('the context says the app, its version and the event', () {
      expect(const SupportContext(appVersion: '1.2.1+8', eventId: 5).toJson(),
          {'platform': 'app', 'app_version': '1.2.1+8', 'event_id': 5});
      expect(const SupportContext().toJson(), {'platform': 'app'});
    });

    test('a support_reply opens the request, or My requests without one', () {
      expect(supportReplyRoute({'case_id': 77, 'number': 1042}),
          '/profile/help/requests/77');
      expect(supportReplyRoute({'case_id': 'a/b'}),
          '/profile/help/requests/a%2Fb');
      expect(supportReplyRoute({}), '/profile/help/requests');
    });
  });

  group('the calls', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('help, topics, requests and a thread from their addresses', () async {
      final api = useFakeApi();
      api.on('GET', '/support/help', [
        {'id': 1, 'question': 'Q', 'answer': 'A'}
      ]);
      api.on('GET', '/support/requests', [
        {'id': 7, 'status': 'open'}
      ]);
      api.on('GET', '/support/requests/7', {'id': 7, 'status': 'open', 'messages': []});

      final support = SupportApi();
      expect(await support.help(), hasLength(1));
      expect(await support.mine(), hasLength(1));
      expect((await support.request('7')).id, '7');
    });

    test('a 404 is a server without the desk: the help page offers email',
        () async {
      useFakeApi(); // nothing routed: every call answers 404
      expect(await container.read(helpAnswersProvider.future), isNull);
      expect(await container.read(myRequestsProvider.future), isNull);
      expect(await container.read(supportRequestProvider('7').future), isNull);
      // The form never waits on the topics.
      expect(await container.read(supportTopicsProvider.future),
          SupportTopic.defaults);
    });

    test('any other failure is an error to retry, not a missing desk',
        () async {
      final api = useFakeApi();
      api.on('GET', '/support/help', {'message': 'Down'}, status: 500);
      final sub = container.listen(helpAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      await expectLater(
          container.read(helpAnswersProvider.future), throwsA(anything));
    });

    test('a request goes with its topic, words, screenshots and context',
        () async {
      final api = useFakeApi();
      api.on('POST', '/support/requests', {'id': 77, 'number': 1042, 'status': 'new'});
      final sent = await SupportApi().send(
        topic: 'tickets',
        message: 'My ticket is missing',
        attachments: ['k1'],
        context: const SupportContext(appVersion: '1.2.1+8', eventId: 5),
      );
      expect(sent.id, '77');
      expect(sent.number, 1042);
      expect(api.sent('POST', '/support/requests').single.data, {
        'topic': 'tickets',
        'message': 'My ticket is missing',
        'attachments': ['k1'],
        'context': {'platform': 'app', 'app_version': '1.2.1+8', 'event_id': 5},
      });
    });

    test('a reply and the survey', () async {
      final api = useFakeApi();
      api.on('POST', '/support/requests/7/replies', {'id': 3});
      api.on('POST', '/support/requests/7/survey', {'ok': true});
      final sent = await SupportApi().reply('7', message: 'Thanks');
      expect(sent.caseId, '7');
      expect(sent.newCase, isFalse);
      await SupportApi().survey('7', solved: true);
      expect(api.sent('POST', '/support/requests/7/replies').single.data,
          {'message': 'Thanks'});
      expect(api.sent('POST', '/support/requests/7/survey').single.data,
          {'solved': true});
    });

    test('a screenshot goes as the file field, typed as a picture', () async {
      final api = useFakeApi();
      api.on('POST', '/support/uploads', {'key': 'up-1', 'name': 'shot.png', 'size': 4});
      final dir = await Directory.systemTemp.createTemp('support');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/shot.png')..writeAsBytesSync([1, 2, 3, 4]);

      final upload = await SupportApi().upload(file.path);

      expect(upload.key, 'up-1');
      final form = api.sent('POST', '/support/uploads').single.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'shot.png');
      expect(form.files.single.value.contentType.toString(), 'image/png');
    });

    test('an upload answer without a key is the server breaking its word',
        () async {
      final api = useFakeApi();
      api.on('POST', '/support/uploads', {'ok': true});
      final dir = await Directory.systemTemp.createTemp('support');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);
      await expectLater(
          SupportApi().upload(file.path), throwsA(isA<FormatException>()));
    });

    test('isDeskMissing is a 404 only', () {
      expect(isDeskMissing(const ApiException(
          message: 'x', statusCode: 404, type: ApiExceptionType.notFound)),
          isTrue);
      expect(isDeskMissing(const ApiException(
          message: 'x', statusCode: 500, type: ApiExceptionType.server)),
          isFalse);
      expect(isDeskMissing(Exception('x')), isFalse);
    });
  });

  group('screenshots', () {
    SupportAttachments tray({Map<String, int> sizes = const {}}) =>
        SupportAttachments(
          upload: (path) async => SupportUpload(key: 'k-$path', name: path),
          sizeOf: (path) async => sizes[path] ?? 1000,
        );

    test('at most three, each sent at once', () async {
      final t = tray();
      expect(await t.add('/a.png'), isNull);
      expect(await t.add('/b.jpg'), isNull);
      expect(await t.add('/c.webp'), isNull);
      expect(t.canAdd, isFalse);
      expect(await t.add('/d.png'), SupportAttachments.limitMessage);
      expect(t.state, hasLength(3));
      expect(t.keys, ['k-/a.png', 'k-/b.jpg', 'k-/c.webp']);
      expect(t.busy, isFalse);
    });

    test('only pictures the desk takes, up to 5 MB', () async {
      final t = tray(sizes: {'/big.png': maxSupportFileBytes + 1});
      expect(await t.add('/doc.heic'), SupportAttachments.typeMessage);
      expect(await t.add('/clip.gif'), SupportAttachments.typeMessage);
      expect(await t.add('/noext'), SupportAttachments.typeMessage);
      expect(await t.add('/big.png'), SupportAttachments.sizeMessage);
      expect(t.state, isEmpty);
      expect(await t.add('/JUST.JPEG'), isNull);
    });

    test('a failed upload says why, and retries or goes', () async {
      final failing = {'/a.png'};
      final t = SupportAttachments(
        upload: (path) async {
          if (failing.contains(path)) {
            throw const ApiException(
                message: 'File too large',
                statusCode: 413,
                type: ApiExceptionType.badRequest);
          }
          return SupportUpload(key: 'k', name: path);
        },
        sizeOf: (_) async => 10,
      );
      await t.add('/a.png');
      expect(t.state.single.status, AttachmentStatus.failed);
      expect(t.state.single.error, 'File too large');
      expect(t.hasFailed, isTrue);
      expect(t.keys, isEmpty);

      failing.clear();
      await t.retry(t.state.single.id);
      expect(t.state.single.status, AttachmentStatus.ready);
      expect(t.keys, ['k']);

      t.remove(t.state.single.id);
      expect(t.state, isEmpty);
      expect(t.canAdd, isTrue);
    });

    test('one removed while it uploads stays removed', () async {
      final gate = Completer<SupportUpload>();
      final t = SupportAttachments(
          upload: (_) => gate.future, sizeOf: (_) async => 10);
      final adding = t.add('/a.png');
      await Future<void>.delayed(Duration.zero);
      expect(t.state.single.status, AttachmentStatus.uploading);
      expect(t.busy, isTrue);
      t.remove(t.state.single.id);
      gate.complete(const SupportUpload(key: 'k', name: 'a.png'));
      await adding;
      expect(t.state, isEmpty);
    });
  });
}
