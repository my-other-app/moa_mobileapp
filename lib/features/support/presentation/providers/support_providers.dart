import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finnet/core/network/interceptors/app_version_interceptor.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/profile/data/photo_picker.dart';
import 'package:finnet/features/support/data/support_api.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/shared/utils/external_links.dart';

/// The help page's answers; null when the server has no help desk yet (a
/// 404), and the page offers the support email instead.
final helpAnswersProvider =
    FutureProvider.autoDispose<List<HelpAnswer>?>((ref) async {
  try {
    return await ref.watch(supportApiProvider).help();
  } catch (e) {
    if (isDeskMissing(e)) return null;
    rethrow;
  }
});

/// What a request can be about: the desk's list, or the seeded topics when
/// it cannot be read -- the form never waits on it.
final supportTopicsProvider =
    FutureProvider.autoDispose<List<SupportTopic>>((ref) async {
  try {
    final topics = await ref.watch(supportApiProvider).topics();
    return topics.isEmpty ? SupportTopic.defaults : topics;
  } catch (_) {
    return SupportTopic.defaults;
  }
});

/// My requests; null when the server has no help desk yet.
final myRequestsProvider =
    FutureProvider.autoDispose<List<SupportRequestSummary>?>((ref) async {
  try {
    return await ref.watch(supportApiProvider).mine();
  } catch (e) {
    if (isDeskMissing(e)) return null;
    rethrow;
  }
});

/// One request and its thread; null when there is no such request of
/// theirs (or no desk).
final supportRequestProvider = FutureProvider.autoDispose
    .family<SupportRequestDetail?, String>((ref, id) async {
  try {
    return await ref.watch(supportApiProvider).request(id);
  } catch (e) {
    if (isDeskMissing(e)) return null;
    rethrow;
  }
});

/// The person's events a request can be about: their tickets on this
/// phone, one line per event.
final supportEventChoicesProvider = Provider<List<SupportEventChoice>>((ref) {
  final seen = <int>{};
  return [
    for (final ticket in ref.watch(savedTicketsProvider))
      if (seen.add(ticket.eventId))
        SupportEventChoice(
          eventId: ticket.eventId,
          name: ticket.eventName,
          when: ticket.startsAt,
        ),
  ];
});

/// Opens a file on a request; answers whether anything opened. A web
/// address opens as any link does; the desk's own file is fetched with
/// the session into the phone's temporary folder and handed to the app
/// for its kind.
final supportAttachmentOpenerProvider =
    Provider<Future<bool> Function(SupportAttachment file)>((ref) {
  return (file) async {
    final url = file.url;
    if (url != null) return ref.read(linkLauncherProvider)(url);
    final path = file.apiPath;
    if (path == null) return false;
    final dir = await getTemporaryDirectory();
    final save = '${dir.path}/support-${file.fileName}';
    await ref.read(supportApiProvider).download(path, save);
    return (await OpenFilex.open(save)).type == ResultType.done;
  };
});

/// Where a screenshot comes from: the photo picker, or the camera at the
/// back.
final screenshotPickerProvider =
    Provider<PhotoPicker>((ref) => DevicePhotoPicker.screenshots());

/// How big a picked file is, in bytes.
final supportFileSizeProvider = Provider<Future<int> Function(String path)>(
    (ref) => (path) => File(path).length());

/// This build's version, for the request's context.
final supportAppVersionProvider =
    Provider<Future<String?> Function()>((ref) => AppVersion.load);

/// The screenshots on a request ([trayId] `new`) or on a reply to one (its
/// id), each sent to the desk as soon as it is picked.
final supportAttachmentsProvider = StateNotifierProvider.autoDispose
    .family<SupportAttachments, List<AttachmentDraft>, String>((ref, trayId) {
  final api = ref.watch(supportApiProvider);
  return SupportAttachments(
    upload: api.upload,
    sizeOf: ref.watch(supportFileSizeProvider),
  );
});

/// Where a screenshot stands.
enum AttachmentStatus { uploading, ready, failed }

/// A picked screenshot.
class AttachmentDraft {
  const AttachmentDraft({
    required this.id,
    required this.path,
    this.status = AttachmentStatus.uploading,
    this.upload,
    this.error,
  });

  final int id;
  final String path;
  final AttachmentStatus status;

  /// The desk's copy, once it has it.
  final SupportUpload? upload;

  /// Why it could not be sent.
  final String? error;

  String get name => path.split(RegExp(r'[/\\]')).last;

  AttachmentDraft copyWith({
    AttachmentStatus? status,
    SupportUpload? upload,
    String? error,
  }) =>
      AttachmentDraft(
        id: id,
        path: path,
        status: status ?? this.status,
        upload: upload ?? this.upload,
        error: error,
      );
}

/// Up to [maxSupportAttachments] screenshots, each checked (a picture the
/// desk takes, at most 5 MB) and uploaded at once, so sending waits on
/// nothing but the words.
class SupportAttachments extends StateNotifier<List<AttachmentDraft>> {
  SupportAttachments({
    required Future<SupportUpload> Function(String path) upload,
    required Future<int> Function(String path) sizeOf,
  })  : _upload = upload,
        _sizeOf = sizeOf,
        super(const []);

  final Future<SupportUpload> Function(String path) _upload;
  final Future<int> Function(String path) _sizeOf;
  int _next = 0;

  static const limitMessage =
      'You can add up to $maxSupportAttachments screenshots.';
  static const typeMessage =
      "That file can't be attached. Choose a screenshot or photo "
      '(PNG, JPG or WebP).';
  static const sizeMessage =
      'That picture is over 5 MB. Choose a smaller one.';

  bool get canAdd => state.length < maxSupportAttachments;

  /// A screenshot is still on its way.
  bool get busy => state.any((a) => a.status == AttachmentStatus.uploading);

  /// A screenshot could not be sent: retry or remove it before sending.
  bool get hasFailed => state.any((a) => a.status == AttachmentStatus.failed);

  /// The desk's keys for the screenshots it has.
  List<String> get keys => [
        for (final a in state)
          if (a.upload case final upload?) upload.key,
      ];

  /// Adds the picture at [path] and sends it. Answers why it was not
  /// added, or null.
  Future<String?> add(String path) async {
    if (!canAdd) return limitMessage;
    final name = path.split(RegExp(r'[/\\]')).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!supportFileTypes.contains(ext)) return typeMessage;
    int size;
    try {
      size = await _sizeOf(path);
    } catch (_) {
      return "Couldn't read that picture. Try another.";
    }
    if (size > maxSupportFileBytes) return sizeMessage;
    if (!mounted || !canAdd) return limitMessage;
    final draft = AttachmentDraft(id: _next++, path: path);
    state = [...state, draft];
    await _send(draft);
    return null;
  }

  /// Sends a failed screenshot again.
  Future<void> retry(int id) async {
    final draft = state.where((a) => a.id == id).firstOrNull;
    if (draft == null || draft.status != AttachmentStatus.failed) return;
    _replace(draft.copyWith(status: AttachmentStatus.uploading));
    await _send(draft);
  }

  void remove(int id) {
    state = [
      for (final a in state)
        if (a.id != id) a,
    ];
  }

  /// Empties the tray, after a send.
  void clear() => state = const [];

  Future<void> _send(AttachmentDraft draft) async {
    try {
      final upload = await _upload(draft.path);
      _replace(draft.copyWith(status: AttachmentStatus.ready, upload: upload));
    } catch (e) {
      _replace(draft.copyWith(
        status: AttachmentStatus.failed,
        error: extractErrorMessage(e,
            defaultMessage: "Couldn't attach it. Tap to try again."),
      ));
    }
  }

  void _replace(AttachmentDraft draft) {
    if (!mounted) return;
    // Removed while it was on its way: it stays removed.
    if (!state.any((a) => a.id == draft.id)) return;
    state = [
      for (final a in state) a.id == draft.id ? draft : a,
    ];
  }
}
