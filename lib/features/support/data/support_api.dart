import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/support/domain/support.dart';

final supportApiProvider = Provider<SupportApi>((ref) => SupportApi());

/// Whether [error] is the server saying it has no help desk yet: a 404 on
/// one of the desk's own addresses, from a server deployed before it. The
/// screens then offer the support email instead.
bool isDeskMissing(Object? error) => statusCodeOf(error) == 404;

/// The support desk, from the app (feature-register
/// `support-leads-contract.md`, prefix `/api/v1/support`), through the
/// app's one client: the session goes with every call, so a request is
/// linked to the person's account.
class SupportApi {
  SupportApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  /// The published answers, in order. Saved on the phone, so they read
  /// offline once seen.
  Future<List<HelpAnswer>> help() async {
    final res = await _client.request('/support/help', DioMethod.get,
        cache: CachePolicy.shared);
    return HelpAnswer.listFrom(res.data);
  }

  /// What a request can be about.
  Future<List<SupportTopic>> topics() async {
    final res = await _client.request('/support/topics', DioMethod.get,
        cache: CachePolicy.shared);
    return SupportTopic.listFrom(res.data);
  }

  /// One screenshot, to the desk's private storage: its key goes with the
  /// request or reply. The server refuses anything not sent as the
  /// picture's own type, so it is named.
  Future<SupportUpload> upload(String path) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: name,
        contentType: supportFileTypeOf(name),
      ),
    });
    final res = await _client.request(
      '/support/uploads',
      DioMethod.post,
      formData: form,
    );
    final upload = SupportUpload.fromJson(res.data);
    if (upload == null) {
      throw const FormatException('The screenshot came back without a key.');
    }
    return upload;
  }

  /// A new request.
  Future<SupportRequestSent> send({
    required String topic,
    required String message,
    List<String> attachments = const [],
    SupportContext context = const SupportContext(),
  }) async {
    final res = await _client.request(
      '/support/requests',
      DioMethod.post,
      param: {
        'topic': topic,
        'message': message,
        if (attachments.isNotEmpty) 'attachments': attachments,
        'context': context.toJson(),
      },
    );
    return SupportRequestSent.fromJson(res.data);
  }

  /// The person's own requests, newest first as the server orders them.
  Future<List<SupportRequestSummary>> mine() async {
    final res = await _client.request('/support/requests', DioMethod.get);
    return SupportRequestSummary.listFrom(res.data);
  }

  /// One request and its thread.
  Future<SupportRequestDetail> request(String id) async {
    final res = await _client.request(
        '/support/requests/${Uri.encodeComponent(id)}', DioMethod.get);
    return SupportRequestDetail.fromJson(res.data, id: id);
  }

  /// A reply from the person. A request solved within the week reopens; an
  /// older one becomes a new request, linked to it, on the server's side.
  Future<SupportReplySent> reply(
    String id, {
    required String message,
    List<String> attachments = const [],
  }) async {
    final res = await _client.request(
      '/support/requests/${Uri.encodeComponent(id)}/replies',
      DioMethod.post,
      param: {
        'message': message,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
    return SupportReplySent.fromJson(res.data, caseId: id);
  }

  /// A file on a request, from the desk's own address (signed in), saved
  /// to [savePath].
  Future<void> download(String apiPath, String savePath) async {
    await _client.dio.download(apiPath, savePath);
  }

  /// "Did we solve it?"
  Future<void> survey(String id, {required bool solved}) async {
    await _client.request(
      '/support/requests/${Uri.encodeComponent(id)}/survey',
      DioMethod.post,
      param: {'solved': solved},
    );
  }
}

/// The type a picture is sent as, from its name.
DioMediaType supportFileTypeOf(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'png' => DioMediaType('image', 'png'),
    'webp' => DioMediaType('image', 'webp'),
    _ => DioMediaType('image', 'jpeg'),
  };
}
