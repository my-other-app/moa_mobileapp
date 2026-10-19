import 'package:flutter/foundation.dart';

/// The saved copy first, when there is one, then the fresh answer: the body
/// of a `StreamProvider` for read-mostly data, so a screen draws at once
/// from disk and updates when the network answers.
///
/// With nothing saved, the fresh answer's failure is the provider's error,
/// as before. After a saved copy, a failure leaves the copy on screen (the
/// offline strip says why) rather than replacing it with an error. A saved
/// copy that cannot be read counts as none.
Stream<T> savedThenFresh<T>({
  required Future<T?> Function() saved,
  required Future<T> Function() fresh,
}) async* {
  T? copy;
  try {
    copy = await saved();
  } catch (e) {
    debugPrint('savedThenFresh: no saved copy: $e');
  }
  if (copy != null) yield copy;
  try {
    yield await fresh();
  } catch (e) {
    if (copy == null) rethrow;
    debugPrint('savedThenFresh: kept the saved copy: $e');
  }
}
