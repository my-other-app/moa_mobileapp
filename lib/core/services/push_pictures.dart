import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// The picture of a push shown while the app is open, on the phone.
///
/// Kept in the temporary folder (`push_pictures/`), which no backup takes
/// and the system may empty, under the notification's id -- one file a
/// notification, however often it is shown. Older builds saved every
/// picture in the documents folder, backed up and never deleted;
/// [PushPictures.prune] deletes those, and its own after a day.
class PushPictures {
  PushPictures({
    http.Client? client,
    Future<Directory> Function()? temporary,
    Future<Directory> Function()? documents,
    DateTime Function()? now,
    @visibleForTesting Duration wait = timeout,
  })  : _wait = wait,
        _client = client,
        _temporary = temporary ?? getTemporaryDirectory,
        _documents = documents ?? getApplicationDocumentsDirectory,
        _now = now ?? DateTime.now;

  final http.Client? _client;
  final Future<Directory> Function() _temporary;
  final Future<Directory> Function() _documents;
  final DateTime Function() _now;
  final Duration _wait;

  /// The one the app uses.
  static final instance = PushPictures();

  /// How long a picture may take: the notification waits for it.
  static const timeout = Duration(seconds: 8);

  /// The largest picture taken. A poster is a few hundred kilobytes.
  static const maxBytes = 2 * 1024 * 1024;

  /// How long a picture is kept after it was shown.
  static const keptFor = Duration(days: 1);

  static const folderName = 'push_pictures';

  /// Downloads [url] for notification [id] and answers its path, or null
  /// when there is no picture to show -- the text alone, then. Only an
  /// http(s) address, a 200 answer that says it is an image, and at most
  /// [maxBytes], within [timeout]. Never throws.
  Future<String?> download(String url, {required int id}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    final client = _client ?? http.Client();
    try {
      final picture = await _fetch(client, uri).timeout(_wait);
      if (picture == null) return null;
      final dir = Directory('${(await _temporary()).path}/$folderName');
      await dir.create(recursive: true);
      // An iPhone types an attachment by its name's ending.
      final file = File('${dir.path}/push-${id.toUnsigned(32)}'
          '${extensionFor(picture.type)}');
      await file.writeAsBytes(picture.bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('PushPictures: no picture: $e');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<({Uint8List bytes, String type})?> _fetch(
      http.Client client, Uri uri) async {
    final response = await client.send(http.Request('GET', uri));
    final type = (response.headers['content-type'] ?? '').toLowerCase();
    final length = response.contentLength;
    if (response.statusCode != 200 ||
        !type.startsWith('image/') ||
        (length != null && length > maxBytes)) {
      // Not read: the connection is dropped with the client.
      unawaited(response.stream.listen(null).cancel());
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) return null;
    }
    if (bytes.isEmpty) return null;
    return (bytes: bytes.takeBytes(), type: type);
  }

  /// The file ending for a picture of [contentType]: what an iPhone's
  /// notification needs to show it.
  @visibleForTesting
  static String extensionFor(String contentType) {
    if (contentType.startsWith('image/png')) return '.png';
    if (contentType.startsWith('image/gif')) return '.gif';
    return '.jpg';
  }

  /// At start-up: pictures shown more than [keptFor] ago go, and every
  /// picture older builds left in the documents folder. Never throws.
  Future<void> prune() async {
    try {
      final dir = Directory('${(await _temporary()).path}/$folderName');
      if (await dir.exists()) {
        final cutOff = _now().subtract(keptFor);
        await for (final entry in dir.list()) {
          if (entry is File && (await entry.lastModified()).isBefore(cutOff)) {
            await entry.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('PushPictures: could not prune: $e');
    }
    try {
      final documents = await _documents();
      if (!await documents.exists()) return;
      await for (final entry in documents.list()) {
        final name = entry.uri.pathSegments.last;
        if (entry is File &&
            name.startsWith('bigPicture-') &&
            name.endsWith('.jpg')) {
          await entry.delete();
        }
      }
    } catch (e) {
      debugPrint('PushPictures: could not delete older pictures: $e');
    }
  }
}
