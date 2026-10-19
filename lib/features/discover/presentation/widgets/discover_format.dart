import 'package:intl/intl.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';

// How the discover screens write things, as the website does
// (`src/utils/format.js`).

final _when = DateFormat('EEE, d MMM · h:mm a');
final _time = DateFormat('h:mm a');
final _whole = NumberFormat.decimalPattern('en_IN');

/// "Sat, 17 Oct · 6:00 PM", in the phone's time; empty when unknown.
String formatWhen(DateTime? at) => at == null ? '' : _when.format(at.toLocal());

/// "6:00 PM".
String formatTime(DateTime? at) => at == null ? '' : _time.format(at.toLocal());

/// "Free", "₹250", or "Paid" when the fee is not given.
String formatPrice(bool hasFee, double? fee) {
  if (!hasFee) return 'Free';
  if (fee == null || fee <= 0) return 'Paid';
  return '₹${_whole.format(fee.round() == fee ? fee.round() : fee)}';
}

/// 950, 1.2k, 34k, 3.4M.
String formatCount(int n) {
  String trim(String s) => s.replaceAll(RegExp(r'\.0$'), '');
  if (n < 1000) return '$n';
  if (n < 1000000) {
    return '${trim((n / 1000).toStringAsFixed(n < 10000 ? 1 : 0))}k';
  }
  return '${trim((n / 1000000).toStringAsFixed(1))}M';
}

/// A list's size: "38", "1.2k"; "1,000+" when the server stopped counting.
String formatTotal(int n, {bool capped = false}) =>
    capped ? '${_whole.format(n)}+' : formatCount(n);

/// "800 m away", "2.4 km away", "38 km away"; null when unknown.
String? formatDistance(double? km) {
  if (km == null || !km.isFinite || km < 0) return null;
  if (km < 1) {
    final metres = ((km * 1000) / 50).round() * 50;
    return '${metres < 50 ? 50 : metres} m away';
  }
  if (km < 10) {
    final text = km.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '$text km away';
  }
  return '${km.round()} km away';
}

/// "3 events", "1 club".
String plural(int n, String one, [String? many]) =>
    '${formatCount(n)} ${n == 1 ? one : (many ?? '${one}s')}';

/// What is most pressing about an event, for a pill; null when nothing is.
String? statusLabel(DiscoverEvent event) {
  switch (event.status) {
    case DiscoverEventStatus.live:
      return 'Live now';
    case DiscoverEventStatus.closingSoon:
      return 'Closing soon';
    case DiscoverEventStatus.full:
      return 'Full';
    case DiscoverEventStatus.ended:
      return 'Ended';
    case DiscoverEventStatus.upcoming:
      return null;
  }
}

/// Where it is: "Online", the venue with its distance, or "Venue to be
/// announced".
String placeLine(DiscoverEvent event) {
  if (event.isOnline) return 'Online';
  final distance = formatDistance(event.distanceKm);
  final venue = event.locationName?.trim() ?? '';
  if (venue.isNotEmpty && distance != null) return '$venue · $distance';
  if (venue.isNotEmpty) return venue;
  return distance ?? 'Venue to be announced';
}
