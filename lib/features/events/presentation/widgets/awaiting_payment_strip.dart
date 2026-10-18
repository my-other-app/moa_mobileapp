import 'package:flutter/material.dart';

/// Above a registration still waiting for its payment, in place of a ticket:
/// what's owed, and the way to pay it.
class AwaitingPaymentStrip extends StatelessWidget {
  final VoidCallback onFinishPayment;

  const AwaitingPaymentStrip({super.key, required this.onFinishPayment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFFFCC80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PAYMENT DUE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF8A4B00),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "You're registered, but your ticket is issued once the payment goes through.",
            style: TextStyle(fontSize: 13.5, color: Color(0xFF5D4037)),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onFinishPayment,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C333D),
            ),
            child: const Text('FINISH PAYMENT'),
          ),
        ],
      ),
    );
  }
}
