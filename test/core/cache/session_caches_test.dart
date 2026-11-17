import 'package:finnet/core/cache/session_caches.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> cleared;
  late SessionCaches caches;

  setUp(() {
    cleared = [];
    caches = SessionCaches({
      'saved answers': () async => cleared.add('saved answers'),
      'broken': () async => throw StateError('disk'),
    }, atSessionEnd: {
      'quiz players': () async => cleared.add('quiz players'),
    });
  });

  test('a session ending clears everything, past a part that fails',
      () async {
    await caches.clearAll();

    expect(cleared, unorderedEquals(['saved answers', 'quiz players']));
  });

  test('a session beginning keeps what goes only when one ends', () async {
    await caches.clearAll(signingIn: true);

    expect(cleared, ['saved answers']);
  });
}
