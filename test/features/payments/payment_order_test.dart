import 'package:finnet/features/payments/data/models/payment_order_model.dart';
import 'package:finnet/features/payments/domain/entities/payment_order.dart';
import 'package:finnet/features/payments/presentation/checkout_options.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up keys: never real ones.
const _appKey = 'rzp_test_app_not_real';
const _clubKey = 'rzp_test_club_not_real';
const _platformKey = 'rzp_test_platform_not_real';

Map<String, dynamic> _order([Map<String, dynamic> extra = const {}]) => {
      'id': '6f1c2a90-0000-4000-8000-000000000001',
      'razorpay_order_id': 'order_1',
      'amount': 250.0,
      'currency': 'INR',
      'status': 'created',
      ...extra,
    };

void main() {
  group('PaymentOrderModel.fromJson', () {
    test('reads key_id and gateway from a club-account order', () {
      final order = PaymentOrderModel.fromJson(
        _order({'key_id': _clubKey, 'gateway': 'club'}),
      ).toEntity();

      expect(order.id, '6f1c2a90-0000-4000-8000-000000000001');
      expect(order.razorpayOrderId, 'order_1');
      expect(order.amount, 250.0);
      expect(order.amountPaise, 25000);
      expect(order.currency, 'INR');
      expect(order.status, 'created');
      expect(order.keyId, _clubKey);
      expect(order.gateway, PaymentGateway.club);
    });

    test('reads a platform-account order', () {
      final order = PaymentOrderModel.fromJson(
        _order({'key_id': _platformKey, 'gateway': 'platform'}),
      ).toEntity();
      expect(order.keyId, _platformKey);
      expect(order.gateway, PaymentGateway.platform);
    });

    test('an older server sends neither: both are null', () {
      final order = PaymentOrderModel.fromJson(_order()).toEntity();
      expect(order.keyId, isNull);
      expect(order.gateway, isNull);
      expect(order.razorpayOrderId, 'order_1');
    });

    test('a null or empty key_id, or an unknown gateway, reads as absent', () {
      final nulls = PaymentOrderModel.fromJson(
        _order({'key_id': null, 'gateway': null}),
      ).toEntity();
      expect(nulls.keyId, isNull);
      expect(nulls.gateway, isNull);

      final odd = PaymentOrderModel.fromJson(
        _order({'key_id': '', 'gateway': 'someone_else'}),
      ).toEntity();
      expect(odd.keyId, isNull);
      expect(odd.gateway, isNull);
    });

    test('an integer amount is fine; paise are rounded, not truncated', () {
      expect(PaymentOrderModel.fromJson(_order({'amount': 199})).toEntity().amountPaise, 19900);
      expect(PaymentOrderModel.fromJson(_order({'amount': 0.29})).toEntity().amountPaise, 29);
    });

    test('no order id or no amount is a FormatException, not a crash later', () {
      expect(
        () => PaymentOrderModel.fromJson(_order({'razorpay_order_id': null})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PaymentOrderModel.fromJson(_order({'amount': null})),
        throwsA(isA<FormatException>()),
      );
      expect(() => PaymentOrderModel.fromJson(null), throwsA(isA<FormatException>()));
    });
  });

  group('the key checkout opens with', () {
    test("is the order's own key_id", () {
      const order = PaymentOrder(
        id: 'o',
        razorpayOrderId: 'order_1',
        amount: 250,
        keyId: _clubKey,
        gateway: PaymentGateway.club,
      );
      expect(order.checkoutKey(fallbackKey: _appKey), _clubKey);
    });

    test("falls back to the app's own key only when the order has none", () {
      const none = PaymentOrder(id: 'o', razorpayOrderId: 'order_1', amount: 250);
      expect(none.checkoutKey(fallbackKey: _appKey), _appKey);
      const empty = PaymentOrder(id: 'o', razorpayOrderId: 'order_1', amount: 250, keyId: '');
      expect(empty.checkoutKey(fallbackKey: _appKey), _appKey);
    });

    test('razorpayCheckoutOptions opens with it, in paise, prefilled', () {
      final club = PaymentOrderModel.fromJson(
        _order({'key_id': _clubKey, 'gateway': 'club'}),
      ).toEntity();
      final options = razorpayCheckoutOptions(
        club,
        fallbackKey: _appKey,
        name: 'Asha Rao',
        email: 'asha@example.org',
        phone: '98765 43210',
      );
      expect(options, {
        'key': _clubKey,
        'order_id': 'order_1',
        'amount': 25000,
        'currency': 'INR',
        'name': 'MyOtherApp',
        'prefill': {'name': 'Asha Rao', 'email': 'asha@example.org', 'contact': '98765 43210'},
      });

      final older = PaymentOrderModel.fromJson(_order()).toEntity();
      expect(
        razorpayCheckoutOptions(older, fallbackKey: _appKey, name: 'A', email: 'a@b.c', phone: '1')['key'],
        _appKey,
      );
    });
  });
}
