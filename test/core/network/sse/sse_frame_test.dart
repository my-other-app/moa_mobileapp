import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:finnet/core/network/sse/sse_frame.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decodes [chunks] as they would arrive off the wire, each its own read.
Future<List<SseFrame>> _decode(List<Object> chunks) =>
    Stream<List<int>>.fromIterable([
      for (final c in chunks) c is String ? utf8.encode(c) : c as List<int>,
    ]).transform(const SseDecoder()).toList();

void main() {
  group('SseDecoder', () {
    test('reads the frames the live stream sends', () async {
      final frames = await _decode([
        'retry: 3000\n\n',
        'id: 1760793812345678\nevent: snapshot\ndata: {"event":{"id":68}}\n\n',
        'event: ping\ndata: {"t":1760793827345}\n\n',
        'event: gone\ndata: {"status":404,"message":"Event not found"}\n\n',
      ]);

      expect(frames, const [
        SseFrame(retry: 3000),
        SseFrame(
            event: 'snapshot',
            id: '1760793812345678',
            data: '{"event":{"id":68}}'),
        SseFrame(event: 'ping', data: '{"t":1760793827345}'),
        SseFrame(
            event: 'gone', data: '{"status":404,"message":"Event not found"}'),
      ]);
    });

    test('joins data lines with a newline', () async {
      final frames = await _decode(['data: first\ndata: second\ndata:\n\n']);
      expect(frames.single.data, 'first\nsecond\n');
      expect(frames.single.event, 'message');
    });

    test('skips comments, and a comment alone is no frame', () async {
      final frames = await _decode([
        ': a keep-alive\n\n',
        ':another\nevent: ping\n: in the middle\ndata: x\n\n',
      ]);
      expect(frames, const [SseFrame(event: 'ping', data: 'x')]);
    });

    test('takes retry only when it is all digits', () async {
      final frames = await _decode([
        'retry: 2500\n\n',
        'retry: 3s\nevent: ping\n\n',
        'retry: -5\nevent: ping\n\n',
        'retry:  100\nevent: ping\n\n',
      ]);
      expect(frames.map((f) => f.retry), [2500, null, null, null]);
    });

    test('drops one space after the colon, no more', () async {
      final frames = await _decode(['data:  two spaces\nevent:ping\n\n']);
      expect(frames.single.data, ' two spaces');
      expect(frames.single.event, 'ping');
    });

    test('a field with no colon is that field with an empty value', () async {
      final frames = await _decode(['data\ndata\n\n', 'id\nevent: ping\n\n']);
      expect(frames[0].data, '\n');
      expect(frames[1].id, '', reason: 'an empty id resets the last id');
    });

    test('ignores an id containing NUL, and fields it does not know', () async {
      final frames = await _decode(['id: a\u0000b\nfoo: bar\nevent: ping\n\n']);
      expect(frames.single, const SseFrame(event: 'ping'));
    });

    test('accepts CRLF and a lone CR as line ends', () async {
      final frames = await _decode([
        'event: snapshot\r\nid: 7\r\ndata: {}\r\n\r\n',
        'event: ping\rdata: x\r\r',
      ]);
      expect(frames, const [
        SseFrame(event: 'snapshot', id: '7', data: '{}'),
        SseFrame(event: 'ping', data: 'x'),
      ]);
    });

    test('puts back a frame, a CRLF and a character split across reads',
        () async {
      final bytes = utf8.encode('id: 9\r\nevent: snapshot\r\n'
          'data: {"banner":{"text":"Demos — Lab 3B ✓"}}\r\n\r\n');
      // Every split point: no read boundary may change what is decoded.
      for (var cut = 1; cut < bytes.length; cut++) {
        final frames =
            await _decode([bytes.sublist(0, cut), bytes.sublist(cut)]);
        expect(
            frames,
            const [
              SseFrame(
                  event: 'snapshot',
                  id: '9',
                  data: '{"banner":{"text":"Demos — Lab 3B ✓"}}'),
            ],
            reason: 'split at byte $cut');
      }
    });

    test('drops a leading byte-order mark', () async {
      final frames = await _decode([
        [0xEF, 0xBB, 0xBF],
        'retry: 3000\n\n',
      ]);
      expect(frames.single.retry, 3000);
    });

    test('drops a block the stream ends in the middle of', () async {
      final frames = await _decode([
        'event: ping\ndata: x\n\n',
        'event: snapshot\nid: 2\ndata: {"half":',
      ]);
      expect(frames, const [SseFrame(event: 'ping', data: 'x')]);
    });

    test('reads a Stream<Uint8List>, as Dio gives the body', () async {
      final body = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode('event: ping\ndata: 1\n\n')),
      ]);
      final frames = await const SseDecoder().bind(body).toList();
      expect(frames, const [SseFrame(event: 'ping', data: '1')]);
    });

    test('hands each frame over as soon as its blank line arrives', () async {
      final input = StreamController<List<int>>();
      final seen = <SseFrame>[];
      final sub = input.stream.transform(const SseDecoder()).listen(seen.add);

      input.add(utf8.encode('event: ping\ndata: 1\n'));
      await pumpEventQueue();
      expect(seen, isEmpty);

      input.add(utf8.encode('\n'));
      await pumpEventQueue();
      expect(seen, const [SseFrame(event: 'ping', data: '1')]);

      await sub.cancel();
      await input.close();
    });
  });
}
