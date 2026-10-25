import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/domain/ticketing.dart';

const _ink = Color(0xFF2C333D);

/// Asks the server what [code] does to the price of [ticketTypeId]:
/// `TicketingApi.checkCode`, bound to the event.
typedef DiscountCheck = Future<DiscountQuote> Function(
    String code, int? ticketTypeId);

/// "Discount code", checked as it is typed -- once the typing stops, and at
/// once on Apply -- for a price preview. The check is rate limited (10 a
/// minute an address), so a code and ticket already checked are never
/// asked again, and a 429 pauses the checks as it typed for a minute. The
/// registration's answer is the final word; [serverError] is what it said
/// about the code.
class DiscountCodeField extends StatefulWidget {
  const DiscountCodeField({
    super.key,
    required this.controller,
    required this.check,
    required this.onQuote,
    this.ticketTypeId,
    this.needsType = false,
    this.serverError,
    this.debounce = const Duration(milliseconds: 900),
  });

  final TextEditingController controller;
  final DiscountCheck check;

  /// The preview, or null when there is none (no code, or one refused).
  final ValueChanged<DiscountQuote?> onQuote;
  final int? ticketTypeId;

  /// The event sells several types and none is chosen yet: a code can't be
  /// priced.
  final bool needsType;
  final String? serverError;
  final Duration debounce;

  static const fieldKey = ValueKey('discount-code-field');
  static const applyKey = ValueKey('discount-code-apply');
  static const appliedKey = ValueKey('discount-code-applied');
  static const errorKey = ValueKey('discount-code-error');

  /// The shortest code worth asking about while typing.
  static const minLength = 3;

  @override
  State<DiscountCodeField> createState() => _DiscountCodeFieldState();
}

class _DiscountCodeFieldState extends State<DiscountCodeField> {
  Timer? _timer;
  bool _checking = false;
  DiscountQuote? _quote;
  String? _error;
  int _asked = 0;

  /// Answers already had, by code and ticket: a quote or the words of a
  /// refusal.
  final Map<String, Object> _answers = {};

  /// After a 429, typing doesn't ask until then; Apply still does.
  DateTime? _quietUntil;

  String get _code => widget.controller.text.trim();

  @override
  void didUpdateWidget(DiscountCodeField old) {
    super.didUpdateWidget(old);
    if (old.ticketTypeId != widget.ticketTypeId && _code.isNotEmpty) {
      // Another ticket: the same code may do something else to it. Said
      // to the form after this frame: it is building now.
      final had = _quote != null;
      _timer?.cancel();
      _asked++;
      _quote = null;
      _error = null;
      _checking = false;
      if (had) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onQuote(_quote);
        });
      }
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _asked++;
    final had = _quote != null;
    setState(() {
      _quote = null;
      _error = null;
      _checking = false;
    });
    if (had) widget.onQuote(null);
  }

  void _onChanged(String _) {
    _reset();
    _schedule();
  }

  void _schedule() {
    final quiet = _quietUntil;
    if (quiet != null && DateTime.now().isBefore(quiet)) return;
    if (_code.length < DiscountCodeField.minLength) return;
    _timer?.cancel();
    _timer = Timer(widget.debounce, _checkNow);
  }

  String get _key => '${_code.toUpperCase()}|${widget.ticketTypeId ?? ''}';

  Future<void> _checkNow() async {
    _timer?.cancel();
    final code = _code;
    if (code.isEmpty) return;
    if (widget.needsType && widget.ticketTypeId == null) {
      setState(() => _error = 'Choose your ticket first, then apply the code.');
      return;
    }
    final key = _key;
    final known = _answers[key];
    if (known != null) return _show(known);
    final asked = ++_asked;
    setState(() {
      _checking = true;
      _error = null;
    });
    Object answer;
    try {
      answer = await widget.check(code, widget.ticketTypeId);
      _answers[key] = answer;
    } catch (e) {
      final problem = discountCodeProblem(e);
      if (statusCodeOf(e) == 429) {
        _quietUntil = DateTime.now().add(const Duration(minutes: 1));
      } else if (problem != null) {
        _answers[key] = problem;
      }
      answer = problem ?? "We couldn't check that code. Try again in a moment.";
    }
    if (!mounted || asked != _asked) return;
    _show(answer);
  }

  void _show(Object answer) {
    setState(() {
      _checking = false;
      _quote = answer is DiscountQuote ? answer : null;
      _error = answer is String ? answer : null;
    });
    widget.onQuote(_quote);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error ?? (_quote == null ? widget.serverError : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Discount code',
          style: TextStyle(
            color: _ink,
            fontSize: 12,
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: DiscountCodeField.fieldKey,
          controller: widget.controller,
          onChanged: _onChanged,
          onSubmitted: (_) => _checkNow(),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 16,
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
          decoration: InputDecoration(
            hintText: 'Have a code? Enter it here',
            hintStyle: const TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 15,
              fontFamily: 'DMSans',
              letterSpacing: 0,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _ink, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _ink, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _ink, width: 1),
            ),
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    key: DiscountCodeField.applyKey,
                    onPressed: _checkNow,
                    style: TextButton.styleFrom(foregroundColor: _ink),
                    child: const Text('Apply'),
                  ),
          ),
        ),
        if (_quote != null) ...[
          const SizedBox(height: 4),
          Text(
            _quote!.summary,
            key: DiscountCodeField.appliedKey,
            style: const TextStyle(
              color: Color(0xFF15803D),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            key: DiscountCodeField.errorKey,
            style: const TextStyle(color: Color(0xFFCC0000), fontSize: 12),
          ),
        ],
      ],
    );
  }
}
