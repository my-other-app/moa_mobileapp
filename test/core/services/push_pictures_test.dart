import 'dart:async';
import 'dart:io';

import 'package:finnet/core/services/push_pictures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory root;
  late Directory temporary;
  late Directory documents;
  var now = DateTime(2026, 11, 28, 9);

  setUp(() {
    root = Directory.systemTemp.createTempSync('push_pictures');
    temporary = Directory('${root.path}/tmp')..createSync();
    documents = Directory('${root.path}/Documents')..createSync();
    now = DateTime(2026, 11, 28, 9);
  });

  tearDown(() => root.deleteSync(recursive: true));

  PushPictures pictures(http.Client client) => PushPictures(
        client: client,
        temporary: () async => temporary,
        documents: () async => documents,
        now: () => now,
      );

  http.Response image(List<int> bytes, {String type = 'image/jpeg'}) =>
      http.Response.bytes(bytes, 200, headers: {'content-type': type});

  test('a picture goes to the temporary folder, named after the notification',
      () async {
    final p = pictures(MockClient((_) async => image([1, 2, 3])));

    final path = await p.download('https://cdn.example/p.jpg', id: 42);

    expect(path, '${temporary.path}/push_pictures/push-42.jpg');
    expect(File(path!).readAsBytesSync(), [1, 2, 3]);
    // Nothing in the documents folder, which backups take.
    expect(documents.listSync(), isEmpty);
  });

  test('the same notification shown again reuses its one file', () async {
    final p = pictures(MockClient((_) async => image([9])));
    await p.download('https://cdn.example/p.jpg', id: -7);
    await p.download('https://cdn.example/p.jpg', id: -7);

    expect(
        Directory('${temporary.path}/push_pictures').listSync(), hasLength(1));
  });

  test('a PNG or a GIF keeps its own ending (an iPhone needs it)', () async {
    final png =
        await pictures(MockClient((_) async => image([1], type: 'image/png')))
            .download('https://cdn.example/p', id: 1);
    final gif =
        await pictures(MockClient((_) async => image([1], type: 'image/gif')))
            .download('https://cdn.example/p', id: 2);

    expect(png, endsWith('push-1.png'));
    expect(gif, endsWith('push-2.gif'));
  });

  group('no picture, so the text alone, when', () {
    Future<String?> answer(http.Response response) =>
        pictures(MockClient((_) async => response))
            .download('https://cdn.example/p.jpg', id: 1);

    test('the server answers an error page', () async {
      expect(
          await answer(http.Response('<html>nope</html>', 404,
              headers: {'content-type': 'text/html'})),
          isNull);
    });

    test('the answer is not an image', () async {
      expect(
          await answer(http.Response('<html></html>', 200,
              headers: {'content-type': 'text/html'})),
          isNull);
    });

    test('it is over the size cap', () async {
      expect(await answer(image(List.filled(PushPictures.maxBytes + 1, 0))),
          isNull);
    });

    test('it is empty', () async {
      expect(await answer(image([])), isNull);
    });

    test('the address is not a web address', () async {
      var asked = false;
      final p = pictures(MockClient((_) async {
        asked = true;
        return image([1]);
      }));
      expect(await p.download('file:///etc/hosts', id: 1), isNull);
      expect(await p.download('not a url', id: 1), isNull);
      expect(asked, isFalse);
    });

    test('the network fails', () async {
      final p = pictures(
          MockClient((_) async => throw const SocketException('down')));
      expect(await p.download('https://cdn.example/p.jpg', id: 1), isNull);
    });
  });

  test('a server that never answers is given up on after the timeout',
      () async {
    final never = Completer<http.Response>();
    final p = PushPictures(
      client: MockClient((_) => never.future),
      temporary: () async => temporary,
      wait: const Duration(milliseconds: 50),
    );

    expect(await p.download('https://cdn.example/p.jpg', id: 1), isNull);
    expect(PushPictures.timeout, const Duration(seconds: 8));
  });

  group('pruning at start-up', () {
    test('deletes pictures shown over a day ago, keeps newer ones', () async {
      final dir = Directory('${temporary.path}/push_pictures')..createSync();
      final old = File('${dir.path}/push-1.jpg')..writeAsBytesSync([1]);
      final recent = File('${dir.path}/push-2.jpg')..writeAsBytesSync([1]);
      old.setLastModifiedSync(now.subtract(const Duration(days: 2)));
      recent.setLastModifiedSync(now.subtract(const Duration(hours: 3)));

      await pictures(MockClient((_) async => image([]))).prune();

      expect(old.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
    });

    test(
        'deletes the pictures older builds left in the documents folder, '
        'and nothing else there', () async {
      final legacy = File('${documents.path}/bigPicture-1731000000000.jpg')
        ..writeAsBytesSync([1]);
      final other = File('${documents.path}/ticket_MOA-1.pdf')
        ..writeAsBytesSync([1]);

      await pictures(MockClient((_) async => image([]))).prune();

      expect(legacy.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    test('with nothing there, does nothing', () async {
      await expectLater(
          pictures(MockClient((_) async => image([]))).prune(), completes);
    });
  });
}
