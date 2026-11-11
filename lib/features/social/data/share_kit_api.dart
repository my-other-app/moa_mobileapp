import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/social/domain/share_kit.dart';
import 'package:finnet/shared/widgets/toast.dart';

final shareKitApiProvider =
    Provider<ShareKitApi>((ref) => ShareKitApi(ref.watch(dioProvider)));

/// The share kits (feature-register `social-posting-contract.md`, "Share
/// kit"): for a person on a club's team, each recent event's words and
/// posters, per platform.
class ShareKitApi {
  ShareKitApi(this._dio);

  final Dio _dio;

  /// Recent published events of the clubs the person is on the team of.
  Future<List<ShareKitEvent>> kits() async {
    final res = await _dio.get<dynamic>('/social/share-kits');
    return ShareKitEvent.listFrom(res.data);
  }

  /// One event's kit.
  Future<ShareKit> kit(int eventId) async {
    final res = await _dio.get<dynamic>('/social/share-kit/$eventId');
    return ShareKit.fromJson(res.data, eventId: eventId);
  }
}

/// The person's share kits: none signed out, and none -- the entry hidden
/// -- when the server has no share kits (404) or cannot say.
final shareKitsProvider =
    FutureProvider.autoDispose<List<ShareKitEvent>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return const [];
  try {
    return await ref.watch(shareKitApiProvider).kits();
  } catch (e) {
    debugPrint('Share kits unavailable: $e');
    return const [];
  }
});

/// One event's kit; null when the person may not see it (not on the
/// club's team, 403) or there is none (404, an older server too).
final shareKitProvider =
    FutureProvider.autoDispose.family<ShareKit?, int>((ref, eventId) async {
  try {
    return await ref.watch(shareKitApiProvider).kit(eventId);
  } catch (e) {
    final status = statusCodeOf(e);
    if (status == 404 || status == 403) return null;
    rethrow;
  }
});

/// Hands a poster ([imagePath]) and/or [text] to the phone's share sheet.
/// A provider so a test can see what would have been shared.
typedef ShareKitSharer = Future<void> Function({
  String? text,
  String? imagePath,
  Rect? origin,
});

final shareKitSharerProvider = Provider<ShareKitSharer>(
  (ref) => ({text, imagePath, origin}) async {
    if (imagePath == null) {
      await Share.share(text ?? '', sharePositionOrigin: origin);
      return;
    }
    await Share.shareXFiles(
      [XFile(imagePath, mimeType: _imageType(imagePath))],
      text: text,
      sharePositionOrigin: origin,
    );
  },
);

String _imageType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// The poster at [url] as a file on the phone: from the picture cache when
/// the screen has drawn it already.
final posterFileProvider = Provider<Future<String> Function(String url)>(
  (ref) => (url) async => (await AppImageCaches.public.getSingleFile(url)).path,
);

/// What sharing [post] hands over beside the poster: its words, with the
/// event's link when they don't carry it already.
String shareKitText(ShareKitPost post) {
  final link = post.link?.toString();
  if (link == null || post.text.contains(link)) return post.text;
  return '${post.text}\n\n$link';
}

/// Share [post] from the button at [buttonContext] (the sheet points at it
/// on an iPad).
///
/// Instagram and WhatsApp Status ignore the words another app hands them:
/// for those the caption is copied first -- "Caption copied — paste it in
/// Instagram" -- then the poster is shared (alone to Instagram; with the
/// words to WhatsApp, whose chats keep them). Every other platform gets the
/// poster with its words; without a poster, the words alone.
Future<void> shareKitPost(
  BuildContext buttonContext,
  WidgetRef ref,
  ShareKitPost post,
) async {
  final box = buttonContext.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final text = shareKitText(post);
  if (post.copiesCaptionFirst) {
    // The caption as the club wrote it for the platform ("link in bio").
    await Clipboard.setData(ClipboardData(text: post.text));
    if (buttonContext.mounted) {
      showToast(buttonContext, 'Caption copied — paste it in ${post.pasteInto}',
          icon: Icons.copy_rounded, duration: const Duration(seconds: 4));
    }
  }
  String? imagePath;
  final url = post.imageUrl;
  if (url != null) {
    try {
      imagePath = await ref.read(posterFileProvider)(url);
    } catch (e) {
      debugPrint('Share kit poster unavailable: $e');
    }
  }
  if (!buttonContext.mounted) return;
  if (imagePath == null && post.copiesCaptionFirst) {
    // Nothing to post without the picture: the caption is copied, and the
    // person can try again for the poster.
    showToast(buttonContext,
        "Couldn't get the poster. The caption is copied; try again.",
        icon: Icons.error_outline);
    return;
  }
  try {
    await ref.read(shareKitSharerProvider)(
      text: imagePath == null || post.sendsWordsWithPoster ? text : null,
      imagePath: imagePath,
      origin: origin,
    );
  } catch (e) {
    debugPrint('Share kit share failed: $e');
    if (!buttonContext.mounted) return;
    showToast(buttonContext, "Couldn't open sharing. Try again.",
        icon: Icons.error_outline);
  }
}
