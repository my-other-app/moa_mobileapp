import 'package:flutter/material.dart';

/// A titled block of the event page, the way Agenda and "On sale with your
/// ticket" have always looked: an 18pt heading, then the content.
class EventSection extends StatelessWidget {
  final String title;
  final Widget child;

  /// Beside the heading: "See all", "About the club".
  final Widget? trailing;

  const EventSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Text that shows its first [lines] lines, and the rest on "Read more".
class ExpandableText extends StatefulWidget {
  final String text;
  final int lines;
  final TextStyle? style;

  const ExpandableText(this.text, {super.key, this.lines = 6, this.style});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF374151));
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.lines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: _open || !long ? null : widget.lines,
            overflow: _open || !long ? null : TextOverflow.fade,
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _open = !_open),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                foregroundColor: const Color(0xFF2C333D),
              ),
              child: Text(_open ? 'Show less' : 'Read more'),
            ),
        ],
      );
    });
  }
}
