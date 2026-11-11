import 'package:finnet/core/services/push_arrivals.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/pages/contact_us_page.dart';
import 'package:finnet/features/support/presentation/pages/help_page.dart';
import 'package:finnet/features/support/presentation/pages/my_requests_page.dart';
import 'package:finnet/features/support/presentation/pages/support_request_page.dart';
import 'package:finnet/features/support/presentation/support_routes.dart';
import 'package:finnet/features/support/presentation/widgets/support_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support_fakes.dart';

const _answers = [
  HelpAnswer(
      id: '1',
      topic: 'tickets',
      question: 'Where is my ticket?',
      answer: 'In My events, under Upcoming.'),
  HelpAnswer(id: '2', question: 'Can I get a refund?', answer: 'Ask the club.'),
];

SupportRequestDetail _detail({
  SupportStatus status = SupportStatus.open,
  bool canReply = true,
  bool surveyAnswered = false,
}) =>
    SupportRequestDetail(
      id: '77',
      number: 1042,
      subject: 'Ticket missing',
      status: status,
      canReply: canReply,
      surveyAnswered: surveyAnswered,
      messages: const [
        SupportMessage(id: 'm1', fromUs: false, body: 'My ticket is missing'),
        SupportMessage(
            id: 'm2',
            fromUs: true,
            body: 'Found it, check My events.',
            authorName: 'Riya'),
      ],
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('the help page', () {
    testWidgets('answers first, then Contact us and My requests',
        (tester) async {
      _tall(tester);
      await pumpSupport(tester, api: FakeSupportApi(answers: _answers));

      expect(find.text('HELP AND SUPPORT'), findsOneWidget);
      expect(find.byKey(HelpPage.contactKey), findsOneWidget);
      expect(find.byKey(HelpPage.requestsKey), findsOneWidget);
      expect(find.text('COMMON QUESTIONS'), findsOneWidget);
      expect(find.text('Where is my ticket?'), findsOneWidget);
      expect(find.text('In My events, under Upcoming.'), findsNothing);

      await tester.tap(find.text('Where is my ticket?'));
      await tester.pumpAndSettle();
      expect(find.text('In My events, under Upcoming.'), findsOneWidget);
    });

    testWidgets('no answers published: still Contact us, no empty heading',
        (tester) async {
      await pumpSupport(tester, api: FakeSupportApi());
      expect(find.byKey(HelpPage.contactKey), findsOneWidget);
      expect(find.text('COMMON QUESTIONS'), findsNothing);
    });

    testWidgets('a server without the desk (404): the support email, as '
        'Settings had it', (tester) async {
      final (:router, :opened) =
          await pumpSupport(tester, api: FakeSupportApi(missing: true));

      expect(find.byType(EmailSupportView), findsOneWidget);
      expect(find.byKey(HelpPage.contactKey), findsNothing);

      await tester.tap(find.byKey(EmailSupportView.emailKey));
      await tester.pump();
      expect(opened.single.scheme, 'mailto');
      expect(opened.single.path, 'support@myotherapp.in');

      await tester.tap(find.byKey(EmailSupportView.helpCentreKey));
      await tester.pump();
      expect(opened.last, Uri.parse('https://myotherapp.in/support'));
    });

    testWidgets('without a mail app, the address is copied', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpSupport(tester,
          api: FakeSupportApi(missing: true), launches: false);
      await tester.tap(find.byKey(EmailSupportView.emailKey));
      await tester.pump();
      await tester.pump();

      expect(copied, 'support@myotherapp.in');
      expect(find.text('No email app found. support@myotherapp.in is copied.'),
          findsOneWidget);
    });

    testWidgets('Contact us and My requests open their screens',
        (tester) async {
      _tall(tester);
      await pumpSupport(tester, api: FakeSupportApi(answers: _answers));

      await tester.tap(find.byKey(HelpPage.contactKey));
      await tester.pumpAndSettle();
      expect(find.byType(ContactUsPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(ContactUsPage))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HelpPage.requestsKey));
      await tester.pumpAndSettle();
      expect(find.byType(MyRequestsPage), findsOneWidget);
    });
  });

  group('Contact us', () {
    Future<void> write(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(ContactUsPage.messageKey), text);
      await tester.pump();
    }

    Future<void> send(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(ContactUsPage.sendKey));
      await tester.pump();
      await tester.tap(find.byKey(ContactUsPage.sendKey));
      await tester.pump();
      await tester.pump();
    }

    bool sendEnabled(WidgetTester tester) => tester
        .widget<FilledButton>(find.byKey(ContactUsPage.sendKey))
        .enabled;

    testWidgets('warns never to share passwords, OTPs or cards',
        (tester) async {
      await pumpSupport(tester,
          api: FakeSupportApi(), location: SupportLocations.contact);
      expect(find.text(NeverShareNote.text), findsOneWidget);
    });

    testWidgets('sends only with a topic and a message', (tester) async {
      _tall(tester);
      final api = FakeSupportApi(
          topicList: const [SupportTopic('tickets', 'Tickets')]);
      await pumpSupport(tester, api: api, location: SupportLocations.contact);

      expect(sendEnabled(tester), isFalse);
      await write(tester, 'My ticket is missing');
      expect(sendEnabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('contact-topic-tickets')));
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
      await write(tester, '   ');
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('a request with its event and the app\'s version, then '
        '"Request #1042 sent"', (tester) async {
      _tall(tester);
      final api = FakeSupportApi(
          topicList: const [SupportTopic('tickets', 'Tickets')]);
      await pumpSupport(
        tester,
        api: api,
        location: '${SupportLocations.contact}?topic=tickets&event=5',
        events: const [
          SupportEventChoice(eventId: 5, name: 'Hack Night'),
        ],
      );

      expect(find.byKey(ContactUsPage.eventKey), findsOneWidget);
      await write(tester, '  My ticket is missing  ');
      await send(tester);

      expect(api.sentRequests.single, {
        'topic': 'tickets',
        'message': 'My ticket is missing',
        'attachments': <String>[],
        'context': {'platform': 'app', 'app_version': '1.2.1+8', 'event_id': 5},
      });
      expect(find.byKey(ContactUsPage.sentKey), findsOneWidget);
      expect(find.text('Request #1042 sent'), findsOneWidget);

      await tester.tap(find.byKey(ContactUsPage.viewRequestKey));
      await tester.pumpAndSettle();
      expect(find.byType(SupportRequestPage), findsOneWidget);
    });

    testWidgets('no events of theirs: no event picker', (tester) async {
      await pumpSupport(tester,
          api: FakeSupportApi(), location: SupportLocations.contact);
      expect(find.byKey(ContactUsPage.eventKey), findsNothing);
      // The seeded topics while the desk's list is empty.
      expect(find.byKey(const ValueKey('contact-topic-account')),
          findsOneWidget);
    });

    testWidgets('screenshots: picked, uploaded, sent by key; three at most',
        (tester) async {
      _tall(tester);
      final api = FakeSupportApi();
      final picker =
          FakeScreenshotPicker(['/s/one.png', '/s/two.jpg', '/s/three.webp']);
      await pumpSupport(tester,
          api: api, location: SupportLocations.contact, picker: picker);

      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.byKey(AttachmentTray.addKey));
        await tester.pump();
        await tester.tap(find.byKey(AttachmentTray.addKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('support-pick-library')));
        await tester.pumpAndSettle();
      }

      expect(api.uploads, ['/s/one.png', '/s/two.jpg', '/s/three.webp']);
      expect(find.byKey(AttachmentTray.addKey), findsNothing);
      expect(find.text('You can add up to 3 screenshots.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('contact-topic-bug')));
      await tester.pump();
      await write(tester, 'The page is blank');
      await send(tester);

      expect(api.sentRequests.single['attachments'],
          ['key-one.png', 'key-two.jpg', 'key-three.webp']);
    });

    testWidgets('a picture over 5 MB is refused and never sent',
        (tester) async {
      _tall(tester);
      final api = FakeSupportApi();
      await pumpSupport(tester,
          api: api,
          location: SupportLocations.contact,
          picker: FakeScreenshotPicker(['/s/huge.png']),
          sizes: {'/s/huge.png': maxSupportFileBytes + 1});

      await tester.tap(find.byKey(AttachmentTray.addKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('support-pick-camera')));
      await tester.pumpAndSettle();

      expect(api.uploads, isEmpty);
      expect(find.text('That picture is over 5 MB. Choose a smaller one.'),
          findsOneWidget);
    });

    testWidgets('a failed screenshot holds the send until it is removed',
        (tester) async {
      _tall(tester);
      final api = FakeSupportApi()..uploadError = apiError(500);
      await pumpSupport(tester,
          api: api,
          location: SupportLocations.contact,
          picker: FakeScreenshotPicker(['/s/one.png']));

      await tester.tap(find.byKey(const ValueKey('contact-topic-bug')));
      await write(tester, 'Broken');
      await tester.tap(find.byKey(AttachmentTray.addKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('support-pick-library')));
      await tester.pumpAndSettle();

      expect(sendEnabled(tester), isFalse);
      await tester
          .tap(find.byKey(const ValueKey('support-attachment-remove-0')));
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('a server without the desk: email instead', (tester) async {
      _tall(tester);
      final api = FakeSupportApi(missing: true);
      await pumpSupport(tester, api: api, location: SupportLocations.contact);

      await tester.tap(find.byKey(const ValueKey('contact-topic-other')));
      await write(tester, 'Hello');
      await send(tester);

      expect(find.byType(EmailSupportView), findsOneWidget);
    });

    testWidgets('too many requests: wait a little', (tester) async {
      _tall(tester);
      final api = FakeSupportApi()..sendError = apiError(429);
      await pumpSupport(tester, api: api, location: SupportLocations.contact);

      await tester.tap(find.byKey(const ValueKey('contact-topic-other')));
      await write(tester, 'Hello');
      await send(tester);

      expect(find.byKey(const ValueKey('contact-error')), findsOneWidget);
      expect(find.textContaining('Please wait a little'), findsOneWidget);
    });
  });

  group('My requests', () {
    testWidgets('each with its number, status and unread dot; a tap opens it',
        (tester) async {
      final api = FakeSupportApi(
        requests: const [
          SupportRequestSummary(
              id: '77',
              number: 1042,
              subject: 'Ticket missing',
              status: SupportStatus.waiting,
              unread: true),
          SupportRequestSummary(
              id: '78', topic: 'payments', status: SupportStatus.closed),
        ],
        details: {'77': _detail()},
      );
      await pumpSupport(tester, api: api, location: SupportLocations.requests);

      expect(find.text('Ticket missing'), findsOneWidget);
      expect(find.text('Payments and refunds'), findsOneWidget);
      expect(find.text('#1042'), findsOneWidget);
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-unread-77')), findsOneWidget);
      expect(find.byKey(const ValueKey('request-unread-78')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('request-77')));
      await tester.pumpAndSettle();
      expect(find.byType(SupportRequestPage), findsOneWidget);
    });

    testWidgets('none yet: Contact us', (tester) async {
      await pumpSupport(tester,
          api: FakeSupportApi(), location: SupportLocations.requests);
      expect(find.byKey(MyRequestsPage.emptyKey), findsOneWidget);
      expect(find.text('CONTACT US'), findsOneWidget);
    });

    testWidgets('a server without the desk: email instead', (tester) async {
      await pumpSupport(tester,
          api: FakeSupportApi(missing: true),
          location: SupportLocations.requests);
      expect(find.byType(EmailSupportView), findsOneWidget);
      expect(find.byKey(MyRequestsPage.newKey), findsNothing);
    });
  });

  group('a request', () {
    testWidgets('the thread, and a reply', (tester) async {
      final api = FakeSupportApi(details: {'77': _detail()});
      await pumpSupport(tester,
          api: api, location: SupportLocations.request('77'));

      expect(find.text('REQUEST #1042'), findsOneWidget);
      expect(find.text('My ticket is missing'), findsOneWidget);
      expect(find.text('Found it, check My events.'), findsOneWidget);
      expect(find.textContaining('Riya'), findsOneWidget);
      expect(find.text(NeverShareNote.text), findsOneWidget);

      await tester.enterText(
          find.byKey(SupportRequestPage.replyKey), 'Thanks, got it');
      await tester.pump();
      await tester.tap(find.byKey(SupportRequestPage.sendKey));
      await tester.pump();
      await tester.pump();

      final (id, message, attachments) = api.replies.single;
      expect((id, message), ('77', 'Thanks, got it'));
      expect(attachments, isEmpty);
      expect(find.text('Reply sent.'), findsOneWidget);
    });

    testWidgets('a closed request takes no reply', (tester) async {
      final api = FakeSupportApi(details: {
        '77': _detail(status: SupportStatus.closed, canReply: false)
      });
      await pumpSupport(tester,
          api: api, location: SupportLocations.request('77'));

      expect(find.byKey(SupportRequestPage.replyKey), findsNothing);
      expect(find.byKey(SupportRequestPage.closedKey), findsOneWidget);
    });

    testWidgets('solved: "Did we solve it?" once', (tester) async {
      final api = FakeSupportApi(
          details: {'77': _detail(status: SupportStatus.resolved)});
      await pumpSupport(tester,
          api: api, location: SupportLocations.request('77'));

      expect(find.byKey(SupportRequestPage.surveyKey), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('request-survey-yes')));
      await tester.pump();
      await tester.pump();
      expect(api.surveys.single, ('77', true));
      expect(find.byKey(SupportRequestPage.surveyKey), findsNothing);
    });

    testWidgets('not theirs, or gone: said so', (tester) async {
      await pumpSupport(tester,
          api: FakeSupportApi(), location: SupportLocations.request('99'));
      expect(find.byKey(SupportRequestPage.notFoundKey), findsOneWidget);
    });

    testWidgets('a push arriving while it is open reads it again',
        (tester) async {
      final api = FakeSupportApi(details: {'77': _detail()});
      await pumpSupport(tester,
          api: api, location: SupportLocations.request('77'));
      final before = api.detailReads;

      PushArrivals.arrived();
      await tester.pump();
      await tester.pump();

      expect(api.detailReads, before + 1);
    });
  });
}
