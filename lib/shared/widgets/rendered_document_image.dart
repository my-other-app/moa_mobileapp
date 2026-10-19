import 'package:flutter/material.dart';

import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// A ticket or certificate as the server renders it, shown whole and at its
/// own shape: the panel takes the picture's aspect ratio once it is known,
/// so a layered design is neither cropped nor letterboxed into a shape it
/// does not have.
///
/// Kept on disk like every picture ([appImageProvider]; the private cache
/// by default, emptied at sign-out), so it opens offline once it has been
/// seen. [placeholder] stands in -- at [placeholderAspectRatio] -- while it
/// loads, and for good when it cannot be loaded at all.
class RenderedDocumentImage extends StatefulWidget {
  const RenderedDocumentImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.placeholderAspectRatio = 800 / 519,
    this.privacy = ImagePrivacy.private,
    this.image,
  });

  final String url;
  final Widget placeholder;
  final double placeholderAspectRatio;
  final ImagePrivacy privacy;

  /// The picture, instead of [url]'s: for tests.
  final ImageProvider? image;

  /// The picture itself, once loaded.
  static const imageKey = ValueKey('rendered-document-image');

  @override
  State<RenderedDocumentImage> createState() => _RenderedDocumentImageState();
}

class _RenderedDocumentImageState extends State<RenderedDocumentImage> {
  ImageProvider? _provider;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _loaded,
    onError: (error, _) {
      debugPrint('RenderedDocumentImage: ${widget.url}: $error');
      if (mounted) setState(() => _failed = true);
    },
  );

  /// Width over height, once the picture is in.
  double? _aspectRatio;
  bool _failed = false;

  void _loaded(ImageInfo info, bool _) {
    final image = info.image;
    final ratio = image.height == 0 ? null : image.width / image.height;
    info.dispose();
    if (!mounted || ratio == null || ratio == _aspectRatio) return;
    setState(() => _aspectRatio = ratio);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(RenderedDocumentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.privacy != widget.privacy ||
        oldWidget.image != widget.image) {
      _aspectRatio = null;
      _failed = false;
      _provider = null;
      _resolve();
    }
  }

  void _resolve() {
    if (widget.image == null && !isWebImageUrl(widget.url.trim())) {
      _failed = true;
      return;
    }
    final provider = _provider ??= widget.image ??
        appImageProvider(
          widget.url.trim(),
          privacy: widget.privacy,
          decodeWidth: screenDecodeWidth(context),
        );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final current = _stream;
    if (current != null && identical(current.key, stream.key)) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio;
    final provider = _provider;
    if (_failed || ratio == null || provider == null) {
      return AspectRatio(
        aspectRatio: widget.placeholderAspectRatio,
        child: widget.placeholder,
      );
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: Image(
        key: RenderedDocumentImage.imageKey,
        image: provider,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.placeholder,
      ),
    );
  }
}
