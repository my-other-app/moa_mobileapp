import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Razorpay plugin's channel, answered here instead of by the native
/// checkout sheet.
const razorpayChannel = MethodChannel('razorpay_flutter');

/// What the native sheet hands back for a payment that went through.
const razorpayPaid = {
  'type': 0,
  'data': {
    'razorpay_payment_id': 'pay_1',
    'razorpay_order_id': 'order_1',
    'razorpay_signature': 'sig_1',
  },
};

/// What it hands back when the person closes the sheet without paying.
const razorpayCancelled = {
  'type': 1,
  'data': {'code': 2, 'message': 'Payment cancelled by user'},
};

/// Stands in for the Razorpay checkout sheet: records every call and
/// answers `open` with [answer].
class FakeRazorpaySheet {
  FakeRazorpaySheet(this.answer);

  Map<String, Object?> answer;
  final calls = <MethodCall>[];

  /// The options each checkout was opened with.
  List<Map<Object?, Object?>> get opened => [
        for (final call in calls)
          if (call.method == 'open') call.arguments as Map<Object?, Object?>,
      ];

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(razorpayChannel, (call) async {
      calls.add(call);
      return call.method == 'open' ? answer : null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(razorpayChannel, null));
  }
}

/// `POST /payments/orders`: an order on the club's own Razorpay account,
/// unless [keyId] is null (an older server, which sends none).
Map<String, dynamic> paymentOrderBody({String? keyId = 'rzp_live_club'}) => {
      'id': 'o-1',
      'razorpay_order_id': 'order_1',
      'amount': 250,
      'currency': 'INR',
      'status': 'created',
      if (keyId != null) 'key_id': keyId,
      if (keyId != null) 'gateway': 'club',
    };

/// `/events/info/7` for a paid event the person registered for.
Map<String, dynamic> paidEventInfo({required bool isPaid}) => {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'poster': null,
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': true,
      'reg_fee': 250,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': null,
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': {}},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': <dynamic>[],
      'rating': 0,
      'total_rating': 0,
      'is_registered': true,
      'is_attended': false,
      'is_paid': isPaid,
      'registration_id': 'reg-1',
      'ticket_url': 'https://myotherapp.in/tickets/T-1',
    };
