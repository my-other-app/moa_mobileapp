import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';

/// A document on the phone, and whether it is known to be current.
class SavedDocument {
  const SavedDocument({required this.file, required this.current});

  final File file;

  /// False when the server could not be asked (offline) and this is the
  /// copy kept from before: it may be out of date.
  final bool current;
}

/// Tickets' and certificates' PDFs, kept on the phone and fetched again only
/// when they have changed.
///
/// A PDF carries the person's name and the club's design, both of which
/// can change after it was downloaded, so a kept copy is never just
/// trusted:
///
/// 1. With a [version] from the API that matches the kept copy's, the kept
///    copy is current and the network is not asked. (No payload carries one
///    today; see the report on the backend.)
/// 2. Otherwise the server is asked with `If-None-Match` / `If-Modified-
///    Since` from the kept copy. A 304 keeps it; a 200 replaces it. The
///    certificate PDF sends an ETag naming its design, revocation and
///    everything printed. The ticket PDF sends none yet, so it is
///    downloaded in full whenever there is a network -- never stale.
/// 3. When the server cannot be reached at all, the kept copy is handed
///    back marked not [SavedDocument.current]; with none kept, the error.
///
/// Files live in the app's support directory (app-private, not shown in
/// Files), each beside a small `.meta.json` with its validators.
/// [clear] deletes them all at sign-out.
class DocumentCache {
  DocumentCache({
    Dio? dio,
    Future<Directory> Function()? root,
  })  : _dio = dio,
        _root = root ?? _defaultRoot;

  static DocumentCache? _instance;

  /// The app's one cache, over the app's Dio (so requests are signed).
  static DocumentCache get instance => _instance ??= DocumentCache();

  @visibleForTesting
  static set instance(DocumentCache? cache) => _instance = cache;

  final Dio? _dio;
  final Future<Directory> Function() _root;

  Dio get dio => _dio ?? APIService.instance.dio;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/documents');

  /// A file name made safe: letters, digits, dot, dash and underscore.
  static String safeName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<Directory> _directory() async {
    final dir = await _root();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The document at [path] (on the API), kept as [name].
  Future<SavedDocument> fetch(
    String path, {
    required String name,
    String? version,
  }) async {
    final dir = await _directory();
    final file = File('${dir.path}/${safeName(name)}');
    final metaFile = File('${file.path}.meta.json');
    final meta = await _readMeta(metaFile);
    final kept = await file.exists() && await file.length() > 0;

    final keptFinal = kept && meta['final'] == true;
    if (keptFinal && version != null && meta['version'] == version) {
      return SavedDocument(file: file, current: true);
    }

    final headers = <String, dynamic>{};
    if (kept) {
      final etag = meta['etag'];
      final lastModified = meta['last_modified'];
      if (etag is String && etag.isNotEmpty) headers['If-None-Match'] = etag;
      if (lastModified is String && lastModified.isNotEmpty) {
        headers['If-Modified-Since'] = lastModified;
      }
    }

    final Response<List<int>> response;
    try {
      response = await dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          validateStatus: (status) =>
              status != null && (status == 304 || (status >= 200 && status < 300)),
        ),
      );
    } on DioException catch (e) {
      if (kept && RetryInterceptor.isConnectionFailure(e)) {
        debugPrint('DocumentCache: offline, handing back the kept $name');
        return SavedDocument(file: file, current: false);
      }
      rethrow;
    }

    if (response.statusCode == 304 && kept) {
      return SavedDocument(file: file, current: true);
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('The document came back empty');
    }
    // Whole or not at all, so a kill mid-write never leaves half a PDF.
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    final etag = response.headers.value('etag');
    await metaFile.writeAsString(jsonEncode({
      // Kept verbatim: a strong tag goes back exactly as it came.
      if (etag != null) 'etag': etag,
      if (etag != null && response.headers.value('last-modified') != null)
        'last_modified': response.headers.value('last-modified'),
      if (version != null) 'version': version,
      // No tag: rendered without one of its images. Not final.
      'final': etag != null,
    }));
    if (etag == null) {
      debugPrint('DocumentCache: $name came without an ETag; not final');
    }
    return SavedDocument(file: file, current: true);
  }

  Future<Map<String, dynamic>> _readMeta(File file) async {
    try {
      if (!await file.exists()) return const {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Delete every kept document, and the tickets an older build saved in
  /// the documents directory.
  Future<void> clear() async {
    try {
      final dir = await _root();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('DocumentCache: could not clear: $e');
    }
    try {
      final legacy = await getApplicationDocumentsDirectory();
      await for (final entity in legacy.list()) {
        final name = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last;
        if (entity is File &&
            name.startsWith('ticket_') &&
            name.endsWith('.pdf')) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('DocumentCache: could not clear older tickets: $e');
    }
  }
}
