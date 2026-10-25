import 'dart:async';
import 'package:flutter/material.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/shared/motion.dart';

class RegSuccessfullPage extends StatefulWidget {
  final String? ticketId;
  final String? eventName;
  final int? eventId;
  final String? eventDateTime;
  final String? fullName;

  /// The ticket type it was bought as ("Early bird"), when the event sells
  /// more than one.
  final String? ticketType;

  const RegSuccessfullPage({
    super.key,
    this.ticketId,
    this.eventName,
    this.eventId,
    this.eventDateTime,
    this.fullName,
    this.ticketType,
  });

  @override
  State<RegSuccessfullPage> createState() => _RegSuccessfullPageState();
}

class _RegSuccessfullPageState extends State<RegSuccessfullPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  /// Moves on into the ticket. Cancelled when the screen goes.
  Timer? _toTicket;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    // Navigate to ticket view after 3 seconds -- unless the person has left:
    // a screen that Back is still sliding away is mounted, but no longer
    // the current one, and the ticket opened over wherever they went.
    _toTicket = Timer(const Duration(seconds: 3), () {
      if (!mounted || widget.ticketId == null) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _navigateToTicket();
    });
  }

  void _navigateToTicket() {
    DateTime? eventDateTime;
    if (widget.eventDateTime != null) {
      try {
        eventDateTime = DateTime.parse(widget.eventDateTime!);
      } catch (_) {}
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TicketViewPage(
          ticketId: widget.ticketId!,
          eventName: widget.eventName ?? 'Event',
          eventDateTime: eventDateTime,
          ticketHolderName: widget.fullName,
          ticketType: widget.ticketType,
        ),
        // The ticket rises a little as it fades in, on the app's timing.
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final eased = CurvedAnimation(parent: animation, curve: Motion.curve);
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          );
        },
        transitionDuration: motionDuration(context, Motion.slow),
      ),
    );
  }

  @override
  void dispose() {
    _toTicket?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top heading text
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "WOOHOO! YOU'RE OFFICIALLY IN! 🎉🔥",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: "BebasNeue",
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // The circle with the GIF inside
                SizedBox(
                  width: 260,
                  height: 260,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ticketconfirm.gif',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Bottom subtext
                const Text(
                  "Hang tight while we whip up your ticket",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Loading indicator
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2C333D)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
