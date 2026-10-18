import 'package:dio/dio.dart';

/// Tells the push service that the person's FCM topics may have changed.
///
/// A follow, an unfollow, a mute, a saved list of interests or a notification
/// switch changes which topics the server lists for them
/// (`GET /notifications/topics`). Those requests are made from many screens;
/// this sees each that succeeded, in one place, and calls [listener] -- the
/// push service, which reconciles its topics shortly after (once for a burst
/// of follows). Nothing happens while no listener is set.
class TopicChangeInterceptor extends Interceptor {
  /// Set by the push service once it has started.
  static void Function()? listener;

  static final _changes = <RegExp>[
    RegExp(r'^/?clubs/(follow|unfollow)/\d+$'),
    RegExp(r'^/?user/interests/select$'),
    RegExp(r'^/?notifications/mutes/clubs/\d+$'),
    RegExp(r'^/?notifications/settings$'),
  ];

  /// Whether a request with [method] to [path] (relative to the API's base)
  /// can change the person's topics.
  static bool changesTopics(String method, String path) {
    if (method.toUpperCase() == 'GET') return false;
    final bare = path.split('?').first;
    return _changes.any((pattern) => pattern.hasMatch(bare));
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    final status = response.statusCode ?? 0;
    if (status >= 200 &&
        status < 300 &&
        changesTopics(options.method, options.path)) {
      listener?.call();
    }
    handler.next(response);
  }
}
