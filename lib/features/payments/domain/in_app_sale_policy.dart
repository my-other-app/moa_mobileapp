import 'package:flutter/foundation.dart';

/// What an iPhone says instead of a price and a button for a paid online
/// event.
const iosOnlineSaleBlockedMessage =
    "This online event can't be bought in the iOS app";

/// The longer line under it.
const iosOnlineSaleBlockedDetail =
    'Paid online events aren’t sold in the iPhone app.';

/// Whether this app may sell a place at an event, on [platform] (the
/// running one by default).
///
/// The owner's decision for App Store guideline 3.1.3(d): a paid **online**
/// event -- a webinar, an online workshop -- is a real-time service that
/// Apple would have sold through in-app purchase, so the iOS app doesn't
/// sell it at all: no price button, no checkout, and no link to buy it
/// elsewhere. In-person events (3.1.3(e), services used outside the app)
/// and free events are sold as before, and Android sells everything.
bool canSellInApp({
  required bool hasFee,
  required bool isOnline,
  TargetPlatform? platform,
}) {
  final on = platform ?? defaultTargetPlatform;
  if (on != TargetPlatform.iOS) return true;
  return !(hasFee && isOnline);
}
