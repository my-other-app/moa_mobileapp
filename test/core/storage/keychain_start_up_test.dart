import 'dart:io';

import 'package:finnet/core/storage/keychain_start_up.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ios_keychain_fake.dart';

const _older = KeychainAccessibility.first_unlock;
const _thisDevice = KeychainAccessibility.first_unlock_this_device;

void main() {
  late Directory root;
  late Directory support;
  late Directory caches;
  late Directory documents;
  late FakeIosKeychain keychain;

  setUp(() {
    root = Directory.systemTemp.createTempSync('keychain_start_up');
    support = Directory('${root.path}/Library/Application Support')
      ..createSync(recursive: true);
    caches = Directory('${root.path}/Library/Caches')
      ..createSync(recursive: true);
    documents = Directory('${root.path}/Documents')..createSync();
    keychain = FakeIosKeychain();
  });

  tearDown(() {
    if (root.existsSync()) {
      Process.runSync('chmod', ['-R', 'u+rwx', root.path]);
      root.deleteSync(recursive: true);
    }
  });

  KeychainStartUp check({bool isIos = true}) => KeychainStartUp(
        supportDirectory: support,
        cacheDirectory: caches,
        documentsDirectory: documents,
        storageAt: keychain.at,
        isIos: isIos,
      );

  File marker() => File('${support.path}/${KeychainStartUp.markerName}');

  /// What 1.2.1 and 1.3.0 leave in the keychain of a signed-in iPhone.
  void signedInOnAnOlderBuild() {
    keychain
      ..put('access_token', 'access-1', _older)
      ..put('refresh_token', 'refresh-1', _older)
      ..put('saved:/events/tickets/upcoming', '{"data":[]}', _older)
      ..put('live_install_key', 'install-1', _older);
  }

  /// What every launch of 1.2.1 and 1.3.0 left in the app's folders.
  void foldersOfAnOlderBuild() {
    File('${support.path}/moaImagesPublic.db').writeAsStringSync('');
    File('${support.path}/moaImagesPrivate.db').writeAsStringSync('');
    Directory('${caches.path}/api_cache').createSync();
  }

  group('an update from 1.2.1 or 1.3.0 (no marker, the old folders)', () {
    test('keeps the session and every other entry', () async {
      signedInOnAnOlderBuild();
      foldersOfAnOlderBuild();

      expect(await check().run(), KeychainStart.kept);

      expect(keychain.values, {
        'access_token': 'access-1',
        'refresh_token': 'refresh-1',
        'saved:/events/tickets/upcoming': '{"data":[]}',
        'live_install_key': 'install-1',
      });
      expect(marker().readAsStringSync(), 'done');
    });

    test('moves the entries to this phone only, values unchanged', () async {
      signedInOnAnOlderBuild();
      foldersOfAnOlderBuild();

      await check().run();

      expect(keychain.valuesAt(_older), isEmpty);
      expect(keychain.valuesAt(_thisDevice), hasLength(4));
      expect(keychain.valuesAt(_thisDevice)['refresh_token'], 'refresh-1');
    });

    // Each trace on its own is enough: the cache folder can be emptied by
    // the system, and the picture indexes are only there since 19 Oct.
    for (final trace in [
      ...KeychainStartUp.supportTraces.map((n) => 'support/$n'),
      ...KeychainStartUp.cacheTraces.map((n) => 'caches/$n'),
      'documents/bigPicture-1731000000000.jpg',
      'documents/ticket_MOA-7K3QF-X9PWM.pdf',
    ]) {
      test('is told by $trace alone', () async {
        signedInOnAnOlderBuild();
        final [folder, name] = trace.split('/');
        final dir = switch (folder) {
          'support' => support,
          'caches' => caches,
          _ => documents,
        };
        final path = '${dir.path}/$name';
        if (name.contains('.')) {
          File(path).writeAsStringSync('');
        } else {
          Directory(path).createSync();
        }

        expect(await check().run(), KeychainStart.kept);
        expect(keychain.values['access_token'], 'access-1');
      });
    }

    test('stays signed in at every later launch', () async {
      signedInOnAnOlderBuild();
      foldersOfAnOlderBuild();
      await check().run();

      // The next launch: the marker is there.
      expect(await check().run(), KeychainStart.kept);
      expect(await check().run(), KeychainStart.kept);
      expect(keychain.values['refresh_token'], 'refresh-1');
    });

    test('a signed-out phone keeps its other entries too', () async {
      keychain.put('live_install_key', 'install-1', _older);
      foldersOfAnOlderBuild();

      expect(await check().run(), KeychainStart.kept);
      expect(keychain.values, {'live_install_key': 'install-1'});
    });
  });

  group('a new install (no marker, empty folders)', () {
    test('clears what an earlier install left in the keychain', () async {
      signedInOnAnOlderBuild();
      keychain
        ..put('saved:/user/profile', '{}', _thisDevice)
        ..put('from_a_test_build', 'x', KeychainAccessibility.unlocked);

      expect(await check().run(), KeychainStart.cleared);

      expect(keychain.values, isEmpty);
      expect(marker().readAsStringSync(), 'done');
    });

    test('with nothing in the keychain, only marks the install', () async {
      expect(await check().run(), KeychainStart.cleared);
      expect(keychain.values, isEmpty);
      expect(marker().readAsStringSync(), 'done');
    });

    test('Firebase\'s and the system\'s own files are not an earlier run',
        () async {
      signedInOnAnOlderBuild();
      Directory('${support.path}/Google/FIRApp').createSync(recursive: true);
      File('${documents.path}/.DS_Store').writeAsStringSync('');

      expect(await check().run(), KeychainStart.cleared);
      expect(keychain.values, isEmpty);
    });

    test('a sign-in after the clear survives the next launches', () async {
      signedInOnAnOlderBuild();
      await check().run();

      // Signed in during the first launch, which also left its files.
      final storage = SecureStorageService(
          storage: keychain.at(_thisDevice), legacy: keychain.at(_older));
      await storage.saveTokens(accessToken: 'access-2', refreshToken: 'r-2');
      foldersOfAnOlderBuild();

      expect(await check().run(), KeychainStart.kept);
      expect(await check().run(), KeychainStart.kept);
      expect(await storage.getRefreshToken(), 'r-2');
    });

    test('a keychain that refuses is cleared at the next launch', () async {
      signedInOnAnOlderBuild();
      keychain.refusing.add(_older);

      expect(await check().run(), KeychainStart.deferred);
      expect(marker().readAsStringSync(), 'pending 1');
      expect(keychain.values['access_token'], 'access-1');

      // The first launch left its files; the marker still says "clear".
      foldersOfAnOlderBuild();
      keychain.refusing.clear();
      expect(await check().run(), KeychainStart.cleared);
      expect(keychain.values, isEmpty);
      expect(marker().readAsStringSync(), 'done');
    });

    test('tries at most three launches, then keeps what is there', () async {
      signedInOnAnOlderBuild();
      keychain.refusing.add(_older);

      for (var launch = 1; launch <= KeychainStartUp.maxAttempts; launch++) {
        expect(await check().run(), KeychainStart.deferred);
        expect(marker().readAsStringSync(), 'pending $launch');
      }
      expect(await check().run(), KeychainStart.kept);
      expect(marker().readAsStringSync(), 'done');
    });

    test('a level the app never wrote at may refuse', () async {
      signedInOnAnOlderBuild();
      keychain.refusing.add(KeychainAccessibility.passcode);

      expect(await check().run(), KeychainStart.cleared);
      expect(keychain.values, isEmpty);
    });
  });

  test('an unreadable marker decides nothing this launch', () async {
    signedInOnAnOlderBuild();
    marker().writeAsStringSync('pending 1');
    Process.runSync('chmod', ['000', marker().path]);

    expect(await check().run(), KeychainStart.deferred);
    expect(keychain.values['access_token'], 'access-1');
  });

  test('Android: nothing is read, cleared or marked', () async {
    signedInOnAnOlderBuild();

    expect(await check(isIos: false).run(), KeychainStart.notIos);
    expect(keychain.values, hasLength(4));
    expect(marker().existsSync(), isFalse);
  });

  group('moving entries to this phone', () {
    test('leaves entries already there, and moves the older ones', () async {
      keychain
        ..put('access_token', 'new', _thisDevice)
        ..put('saved:a', '1', _older)
        ..put('saved:b', '2', KeychainAccessibility.unlocked);

      expect(await check().moveToThisDevice(), 2);
      expect(keychain.valuesAt(_thisDevice),
          {'access_token': 'new', 'saved:a': '1', 'saved:b': '2'});
    });

    test('after a move, a sign-out deletes the session', () async {
      signedInOnAnOlderBuild();
      foldersOfAnOlderBuild();
      await check().run();

      await SecureStorageService(storage: keychain.at(_thisDevice))
          .clearTokens();

      expect(keychain.values.keys,
          isNot(anyOf(contains('access_token'), contains('refresh_token'))));
    });
  });
}
