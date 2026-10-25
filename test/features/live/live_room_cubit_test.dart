import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';
import 'package:finnet/features/live/presentation/cubits/live_room_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  late FakeLiveRoomApi api;

  setUp(() => api = FakeLiveRoomApi());

  LiveRoomCubit cubitFor() => LiveRoomCubit(api: api, eventId: 7);

  group('keeping the room current', () {
    test('without a stream: a read now, then every 5 s while in front; '
        'nothing in the background; a read at once on the way back', () {
      fakeAsync((async) {
        api.rooms.add(roomJson());
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        expect(api.roomReads, 1);
        expect(api.roomStreams, 1, reason: 'the stream is tried first');
        expect(cubit.state.room, isNotNull);
        expect(cubit.state.loading, isFalse);

        async.elapse(const Duration(seconds: 5));
        expect(api.roomReads, 2);
        async.elapse(const Duration(seconds: 15));
        expect(api.roomReads, 5);

        cubit.hidden();
        async.elapse(const Duration(minutes: 2));
        expect(api.roomReads, 5, reason: 'stopped in the background');

        cubit.shown();
        async.flushMicrotasks();
        expect(api.roomReads, 6);
        async.elapse(const Duration(seconds: 5));
        expect(api.roomReads, 7);

        cubit.dispose();
        async.elapse(const Duration(minutes: 1));
        expect(api.roomReads, 7, reason: 'nothing after it goes');
      });
    });

    test('a closed room is read no more', () {
      fakeAsync((async) {
        api.rooms
          ..add(roomJson())
          ..add(roomJson(status: 'closed'));
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.room!.isClosed, isTrue);
        async.elapse(const Duration(minutes: 5));
        expect(api.roomReads, 2);
        cubit.dispose();
      });
    });

    test('with a stream: its snapshots, and no reads while it speaks', () {
      fakeAsync((async) {
        final body = StreamController<List<int>>();
        api.rooms.add(roomJson());
        api.roomStream = () => SseResponse(
              statusCode: 200,
              headers: {
                'content-type': ['text/event-stream'],
              },
              body: body.stream,
            );
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        body.add(utf8.encode('id: 1\nevent: snapshot\ndata: '
            '${jsonEncode(roomJson(banner: {
                  'id': 'u1',
                  'kind': 'room',
                  'text': 'Lab 3B'
                }))}\n\n'));
        async.flushMicrotasks();
        expect(cubit.state.room!.banner!.text, 'Lab 3B');
        for (var i = 0; i < 4; i++) {
          async.elapse(const Duration(seconds: 10));
          body.add(utf8.encode('event: ping\n\n'));
          async.flushMicrotasks();
        }
        expect(api.roomReads, 1, reason: 'the stream is the source');
        cubit.dispose();
        async.flushMicrotasks();
        expect(body.hasListener, isFalse);
      });
    });

    test('a first read that fails says so; one that finds nothing says that',
        () {
      fakeAsync((async) {
        api.rooms
          ..add(apiError(500))
          ..add(roomJson());
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        expect(cubit.state.room, isNull);
        expect(cubit.state.loadError, isNotNull);
        expect(cubit.state.notFound, isFalse);
        // The next read puts it right.
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.room, isNotNull);
        expect(cubit.state.loadError, isNull);
        cubit.dispose();
      });
      fakeAsync((async) {
        api = FakeLiveRoomApi()..rooms.add(apiError(404));
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        expect(cubit.state.notFound, isTrue);
        cubit.dispose();
      });
    });

    test('a failed read later leaves the room as it was', () {
      fakeAsync((async) {
        api.rooms
          ..add(roomJson(questions: [questionJson('a')]))
          ..add(apiError(503));
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.room!.questions.single.id, 'a');
        expect(cubit.state.loadError, isNull);
        cubit.dispose();
      });
    });
  });

  group('questions', () {
    test('a vote shows at once, and the server\'s count wins', () async {
      api.rooms.add(roomJson(questions: [questionJson('a', votes: 2)]));
      final cubit = cubitFor();
      await cubit.refresh();
      final done = Completer<({int votes, bool voted})>();
      api.voteAnswer = (_) => done.future;

      final pending = cubit.toggleVote('a');
      final shown = cubit.state.room!.questions.single;
      expect(shown.voted, isTrue);
      expect(shown.votes, 3);
      expect(cubit.state.voting, contains('a'));

      // A second tap while the first is on its way does nothing.
      await cubit.toggleVote('a');
      expect(api.votes, ['a']);

      done.complete((votes: 7, voted: true));
      await pending;
      final q = cubit.state.room!.questions.single;
      expect(q.votes, 7);
      expect(q.voted, isTrue);
      expect(cubit.state.voting, isEmpty);
      cubit.dispose();
    });

    test('taking a vote back, with the server\'s answer', () async {
      api.rooms.add(
          roomJson(questions: [questionJson('a', votes: 4, voted: true)]));
      api.voteAnswer = (_) => (votes: 3, voted: false);
      final cubit = cubitFor();
      await cubit.refresh();
      await cubit.toggleVote('a');
      final q = cubit.state.room!.questions.single;
      expect(q.voted, isFalse);
      expect(q.votes, 3);
      cubit.dispose();
    });

    test('a vote the server refuses is put back', () async {
      api.rooms.add(roomJson(questions: [questionJson('a', votes: 2)]));
      api.voteAnswer = (_) => apiError(429);
      final cubit = cubitFor();
      await cubit.refresh();
      await cubit.toggleVote('a');
      final q = cubit.state.room!.questions.single;
      expect(q.voted, isFalse);
      expect(q.votes, 2);
      cubit.dispose();
    });

    test('an answered question takes no votes', () async {
      api.rooms.add(
          roomJson(questions: [questionJson('a', status: 'answered')]));
      final cubit = cubitFor();
      await cubit.refresh();
      await cubit.toggleVote('a');
      expect(api.votes, isEmpty);
      cubit.dispose();
    });

    test('asking: straight onto the board', () async {
      api.rooms.add(roomJson());
      final cubit = cubitFor();
      await cubit.refresh();
      expect(await cubit.ask('  Is there pizza?  ', name: 'Asha'), isTrue);
      expect(api.asked.single, ('Is there pizza?', 'Asha'));
      expect(cubit.state.askNote, 'Up on the board.');
      expect(cubit.state.room!.questions.single.text, 'Is there pizza?');
      cubit.dispose();
    });

    test('asking where the organiser lets questions through: it waits',
        () async {
      api.rooms.add(roomJson(approveFirst: true));
      api.askAnswer = (text) => questionJson('w', text: text, status: 'pending');
      final cubit = cubitFor();
      await cubit.refresh();
      await cubit.ask('Is there pizza?');
      expect(cubit.state.askNote, 'Sent — the organiser will put it up.');
      expect(cubit.state.room!.questions, isEmpty);
      cubit.dispose();
    });

    test('a floor the server says is closed closes the ask box', () async {
      api.rooms.add(roomJson());
      api.askAnswer = (_) => apiError(409, code: qaClosedCode);
      final cubit = cubitFor();
      await cubit.refresh();
      expect(cubit.state.canAsk, isTrue);
      expect(await cubit.ask('Is there pizza?'), isFalse);
      expect(cubit.state.qaRefused, isTrue);
      expect(cubit.state.canAsk, isFalse);
      cubit.dispose();
    });

    test('a question too short is not sent; another refusal is said',
        () async {
      api.rooms.add(roomJson());
      api.askAnswer = (_) => apiError(429, message: 'Slow down.');
      final cubit = cubitFor();
      await cubit.refresh();
      expect(await cubit.ask('hi'), isFalse);
      expect(api.asked, isEmpty);
      expect(await cubit.ask('Is there pizza?'), isFalse);
      expect(cubit.state.askError, 'Slow down.');
      cubit.dispose();
    });
  });

  group('the poll', () {
    test('a choice: shown at once, then the room\'s counts', () async {
      api.rooms.add(roomJson(poll: pollJson()));
      api.respondAnswer = (id, value) => pollJson(
            id: id,
            responses: 3,
            choices: [
              {'label': 'Pizza', 'count': 2, 'pct': 67},
              {'label': 'Dosa', 'count': 1, 'pct': 33},
            ],
            myResponse: value,
          );
      final cubit = cubitFor();
      await cubit.refresh();
      final going = cubit.respond('Pizza');
      expect(cubit.state.room!.poll!.myResponse, 'Pizza');
      expect(cubit.state.answering, isTrue);
      expect(await going, isTrue);
      expect(api.responses.single, ('p1', 'Pizza'));
      final poll = cubit.state.room!.poll!;
      expect(poll.responses, 3);
      expect(poll.choices.first.pct, 67);
      expect(cubit.state.answering, isFalse);
      cubit.dispose();
    });

    test('a word cloud takes a word or two, and nothing shorter', () async {
      api.rooms.add(roomJson(poll: pollJson(kind: 'words', options: [])));
      api.respondAnswer = (id, value) => pollJson(
            id: id,
            kind: 'words',
            options: [],
            words: [
              {'word': value, 'count': 1},
            ],
            myResponse: value,
          );
      final cubit = cubitFor();
      await cubit.refresh();
      expect(await cubit.respond('a'), isFalse);
      expect(api.responses, isEmpty);
      expect(cubit.state.pollError, 'A word or two.');
      expect(await cubit.respond(' so fun '), isTrue);
      expect(api.responses.single, ('p1', 'so fun'));
      expect(cubit.state.pollError, isNull);
      expect(cubit.state.room!.poll!.words.single.word, 'so fun');
      cubit.dispose();
    });

    test('a rating is 1 to 5', () async {
      api.rooms.add(roomJson(poll: pollJson(kind: 'rating', options: [])));
      final cubit = cubitFor();
      await cubit.refresh();
      expect(await cubit.respond('7'), isFalse);
      expect(await cubit.respond('4'), isTrue);
      expect(api.responses.single, ('p1', '4'));
      expect(cubit.state.room!.poll!.myResponse, '4');
      cubit.dispose();
    });

    test('an answer the server refuses is put back, and said', () async {
      api.rooms.add(roomJson(poll: pollJson(myResponse: 'Dosa')));
      api.respondAnswer = (_, __) => apiError(409, message: 'This poll is not open.');
      final cubit = cubitFor();
      await cubit.refresh();
      expect(await cubit.respond('Pizza'), isFalse);
      expect(cubit.state.room!.poll!.myResponse, 'Dosa');
      expect(cubit.state.pollError, 'This poll is not open.');
      cubit.dispose();
    });
  });
}
