import 'package:flutter/widgets.dart';

/// Builds with the size of a loaded picture, for a frame that draws a
/// picture differently by its shape: a poster that is not 4:5, a logo that
/// is not square.
///
/// [image] is a picture already loaded (an image builder's provider), so its
/// size is known before the first build and nothing jumps. Until it is
/// known, [builder] gets null.
class PictureShape extends StatefulWidget {
  const PictureShape({super.key, required this.image, required this.builder});

  final ImageProvider image;
  final Widget Function(BuildContext context, Size? size) builder;

  @override
  State<PictureShape> createState() => _PictureShapeState();
}

class _PictureShapeState extends State<PictureShape> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PictureShape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream != null && stream.key == _stream!.key) return;
    _stop();
    final listener = ImageStreamListener((info, synchronousCall) {
      final size =
          Size(info.image.width.toDouble(), info.image.height.toDouble());
      info.dispose();
      // A decoded picture answers at once, inside addListener: before the
      // first build, where setState is not wanted.
      if (synchronousCall) {
        _size = size;
      } else if (mounted && size != _size) {
        setState(() => _size = size);
      }
    });
    _listener = listener;
    _stream = stream..addListener(listener);
  }

  void _stop() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _size);
}
