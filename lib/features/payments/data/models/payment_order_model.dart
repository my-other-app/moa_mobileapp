import 'package:finnet/features/payments/domain/entities/payment_order.dart';

String? _str(dynamic value) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return null;
}

/// `POST /payments/orders`:
/// `{id, razorpay_order_id, amount, currency, status, key_id, gateway}`.
///
/// `key_id` and `gateway` arrived with clubs' own Razorpay accounts; an older
/// server leaves them out, so both are nullable.
class PaymentOrderModel {
  final String id;
  final String razorpayOrderId;
  final double amount;
  final String currency;
  final String status;
  final String? keyId;
  final String? gateway;

  const PaymentOrderModel({
    required this.id,
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.status,
    this.keyId,
    this.gateway,
  });

  /// Throws [FormatException] when there is no order to open checkout with:
  /// no `razorpay_order_id`, or no amount.
  factory PaymentOrderModel.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final razorpayOrderId = _str(data['razorpay_order_id']);
    if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
      throw const FormatException('The payment order came back without an id.');
    }
    final amount = data['amount'];
    if (amount is! num) {
      throw const FormatException('The payment order came back without an amount.');
    }
    final keyId = _str(data['key_id']);
    return PaymentOrderModel(
      id: _str(data['id']) ?? '',
      razorpayOrderId: razorpayOrderId,
      amount: amount.toDouble(),
      currency: _str(data['currency']) ?? 'INR',
      status: _str(data['status']) ?? 'created',
      keyId: (keyId == null || keyId.isEmpty) ? null : keyId,
      gateway: _str(data['gateway']),
    );
  }

  PaymentOrder toEntity() => PaymentOrder(
        id: id,
        razorpayOrderId: razorpayOrderId,
        amount: amount,
        currency: currency,
        status: status,
        keyId: keyId,
        gateway: switch (gateway) {
          'platform' => PaymentGateway.platform,
          'club' => PaymentGateway.club,
          _ => null,
        },
      );
}
