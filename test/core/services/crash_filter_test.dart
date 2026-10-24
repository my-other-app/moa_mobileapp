import 'dart:io';

import 'package:finnet/core/services/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNonFatalFlutterError', () {
    test('an image that failed to load is not a crash', () {
      // How NetworkImage and cached_network_image both report it.
      final details = FlutterErrorDetails(
        exception: const HttpException('Invalid statusCode: 404'),
        library: 'image resource service',
      );

      expect(isNonFatalFlutterError(details), isTrue);
    });

    test('nor is a NetworkImageLoadException from anywhere', () {
      final details = FlutterErrorDetails(
        exception: NetworkImageLoadException(
          statusCode: 403,
          uri: Uri.parse('https://cdn.example/poster.jpg'),
        ),
        library: 'some other library',
      );

      expect(isNonFatalFlutterError(details), isTrue);
    });

    test('a layout or build error still is', () {
      final details = FlutterErrorDetails(
        exception: FlutterError('A RenderFlex overflowed by 12 pixels.'),
        library: 'rendering library',
      );

      expect(isNonFatalFlutterError(details), isFalse);
    });
  });

  group('isNonFatalError', () {
    test('a fetch nothing awaited is not a crash', () {
      expect(isNonFatalError(const SocketException('Failed host lookup')),
          isTrue);
      expect(isNonFatalError(const HttpException('Connection closed')), isTrue);
    });

    test('a bug is', () {
      expect(isNonFatalError(StateError('Bad state')), isFalse);
      expect(isNonFatalError(TypeError()), isFalse);
    });
  });
}
