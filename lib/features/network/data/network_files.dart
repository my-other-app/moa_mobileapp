import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a text file -- contact cards, a spreadsheet -- to the phone's
/// share sheet, from where it goes to Contacts, Files or anywhere else. A
/// provider so a test can see what would have been shared.
typedef TextFileSharer = Future<void> Function({
  required String fileName,
  required String text,
  required String mimeType,
  String? subject,
  Rect? origin,
});

final textFileSharerProvider = Provider<TextFileSharer>(
  (ref) => ({
    required fileName,
    required text,
    required mimeType,
    subject,
    origin,
  }) async {
    // The cache, not the support directory; and only while the share sheet
    // has it: the file is the person's network -- names, shared contact
    // details, their notes -- so it goes as soon as the sheet is done
    // (share_plus hands the receiving app its own copy).
    final dir = await _exportsDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    try {
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType, name: fileName)],
        subject: subject,
        sharePositionOrigin: origin,
      );
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Swept at sign-out ([clearNetworkExports]) if not now.
      }
    }
  },
);

Future<Directory> _exportsDir() async =>
    Directory('${(await getTemporaryDirectory()).path}/network');

/// Every export file left on the phone: at sign-out, with the rest of the
/// person's data (session_services.dart).
Future<void> clearNetworkExports() async {
  final dir = await _exportsDir();
  if (await dir.exists()) await dir.delete(recursive: true);
}

/// A name for a file from [name]: letters, digits and dashes.
String fileNameFor(String name, String extension) {
  final base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${base.isEmpty ? 'contact' : base}.$extension';
}
