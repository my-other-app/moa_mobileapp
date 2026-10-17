import 'package:equatable/equatable.dart';

/// Whose Razorpay account an order was made on.
enum PaymentGateway {
  /// MyOtherApp's own account: every event, until a club connects its own.
  platform,

  /// The club's own Razorpay account.
  club,
}

/// A Razorpay order to open checkout with, from `POST /payments/orders`.
///
/// The ticket and whatever was picked from the event's shelf ride on one
/// `event_registration` order.
class PaymentOrder extends Equatable {
  final String id;
  final String razorpayOrderId;

  /// In rupees, as the server sends it; checkout wants paise ([amountPaise]).
  final double amount;
  final String currency;
  final String status;

  /// The publishable key of the account the order was made on -- what
  /// checkout must open with. Null from a server older than the club
  /// gateways; [checkoutKey] then falls back to the app's own key.
  final String? keyId;

  /// Whose account [keyId] belongs to. Null from an older server, or for a
  /// value this build does not know.
  final PaymentGateway? gateway;

  const PaymentOrder({
    required this.id,
    required this.razorpayOrderId,
    required this.amount,
    this.currency = 'INR',
    this.status = 'created',
    this.keyId,
    this.gateway,
  });

  int get amountPaise => (amount * 100).round();

  /// The key to open Razorpay Checkout with: the order's own, or
  /// [fallbackKey] (the key compiled into the app) when the order carries
  /// none.
  String checkoutKey({required String fallbackKey}) {
    final key = keyId;
    return (key == null || key.isEmpty) ? fallbackKey : key;
  }

  @override
  List<Object?> get props =>
      [id, razorpayOrderId, amount, currency, status, keyId, gateway];
}
