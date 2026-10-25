import 'dart:async';

import 'package:flutter/material.dart';

/// "Registration closes in 2 days 04 hrs 05 mins 06 secs" for what is left
/// until [closesAt], from [now].
@visibleForTesting
String registrationCountdownText(DateTime closesAt, DateTime now) {
  final left = closesAt.difference(now);
  if (left.isNegative || left == Duration.zero) return 'Registration Closed';
  final days = left.inDays;
  final hours = (left.inHours % 24).toString().padLeft(2, '0');
  final minutes = (left.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
  final dayPart = days > 0 ? '$days day${days > 1 ? 's' : ''} ' : '';
  return 'Registration closes in $dayPart$hours hrs $minutes mins $seconds secs';
}

/// The event page's red "Registration closes in …" line, ticking every
/// second on its own.
///
/// The tick used to call setState on the whole event page -- some 2,600
/// lines of widgets rebuilt every second while registration was open. Now
/// only this line rebuilds; the page hears once, through [onClosed], when
/// the deadline passes.
class RegistrationCountdown extends StatefulWidget {
  const RegistrationCountdown({
    super.key,
    required this.closesAt,
    required this.onClosed,
    this.now = DateTime.now,
  });

  final DateTime closesAt;

  /// Called once, when the deadline is reached while the line is shown.
  final VoidCallback onClosed;

  /// The clock; a test's own.
  final DateTime Function() now;

  @override
  State<RegistrationCountdown> createState() => _RegistrationCountdownState();
}

class _RegistrationCountdownState extends State<RegistrationCountdown> {
  Timer? _timer;
  late String _text;

  @override
  void initState() {
    super.initState();
    // Right away: it used to show an empty red box for its first second.
    _text = registrationCountdownText(widget.closesAt, widget.now());
    _start();
  }

  @override
  void didUpdateWidget(RegistrationCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.closesAt != widget.closesAt) {
      _text = registrationCountdownText(widget.closesAt, widget.now());
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (!widget.closesAt.isAfter(widget.now())) {
      _timer = null;
      // Not during this build: the page rebuilds itself.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onClosed();
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = widget.now();
    setState(() => _text = registrationCountdownText(widget.closesAt, now));
    if (!widget.closesAt.isAfter(now)) {
      _timer?.cancel();
      _timer = null;
      widget.onClosed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDEDD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _text,
        key: const ValueKey('registration-countdown'),
        textAlign: TextAlign.left,
        style: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: Color(0xFFCD0000),
        ),
      ),
    );
  }
}
