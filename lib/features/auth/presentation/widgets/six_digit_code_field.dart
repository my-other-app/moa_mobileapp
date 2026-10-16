import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the digits of whatever was typed or pasted, up to [length]: a
/// pasted "123 456" or "Your code is 123456." becomes "123456".
class CodeDigitsFormatter extends TextInputFormatter {
  final int length;

  const CodeDigitsFormatter({this.length = 6});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > length) digits = digits.substring(0, length);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Six boxes, one digit each, over a single hidden text field: typing moves
/// along the boxes, backspace moves back, and paste and the keyboard's
/// one-time-code suggestion fill them all at once. [onCompleted] fires when
/// the sixth digit lands.
class SixDigitCodeField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;
  final bool autofocus;

  const SixDigitCodeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = true,
  });

  static const int length = 6;

  @override
  State<SixDigitCodeField> createState() => _SixDigitCodeFieldState();
}

class _SixDigitCodeFieldState extends State<SixDigitCodeField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  static const _ink = Color(0xFF2C333D);
  static const _accent = Color(0xFF17A58F);
  static const _error = Color(0xFFCC0000);

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SixDigitCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _changed(String value) {
    widget.onChanged?.call(value);
    if (value.length == SixDigitCodeField.length) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final focused = _focusNode.hasFocus && widget.enabled;
    return Semantics(
      label: 'Six-digit code',
      value: text,
      textField: true,
      child: Stack(
        children: [
          Row(
            children: List.generate(SixDigitCodeField.length, (i) {
              final filled = i < text.length;
              final active = focused &&
                  (i == text.length ||
                      (text.length == SixDigitCodeField.length &&
                          i == SixDigitCodeField.length - 1));
              final border = widget.hasError
                  ? _error
                  : active
                      ? _accent
                      : _ink;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    key: ValueKey('code-box-$i'),
                    height: 56,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: widget.enabled
                          ? Colors.white
                          : const Color(0xFFF3F3F3),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: active || widget.hasError ? 1.5 : 0.5,
                            color: border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      filled ? text[i] : '',
                      style: const TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 24,
                        fontFamily: 'DMSans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          // The field that actually takes the input: invisible, but over the
          // boxes so a tap focuses it and a long press offers Paste.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey('code-input'),
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: const [CodeDigitsFormatter()],
                showCursor: false,
                enableInteractiveSelection: true,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: _changed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
