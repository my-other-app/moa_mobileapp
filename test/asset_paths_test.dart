import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every literal asset path in lib/ (`'assets/...'` or `"assets/..."`),
/// leaving out any built with `$`.
Map<String, String> _namedAssets() {
  final named = <String, String>{};
  final literal = RegExp(r'''['"](assets/[^'"$]+)['"]''');
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    for (final m in literal.allMatches(file.readAsStringSync())) {
      named[m.group(1)!] = file.path;
    }
  }
  return named;
}

void main() {
  test('every asset the code names is in the app', () {
    // The Badges page showed assets/images/mybadges.gif for nine months
    // after the file was deleted: every visit failed to load it.
    final named = _namedAssets();
    expect(named, isNotEmpty);
    final missing = {
      for (final entry in named.entries)
        if (!File(entry.key).existsSync()) entry.key: entry.value,
    };
    expect(missing, isEmpty, reason: 'named but not in assets/: $missing');
  });
}
