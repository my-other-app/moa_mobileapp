import 'package:equatable/equatable.dart';

/// How the server placed whoever asked.
enum WhereSource {
  /// A point the caller sent (the app never sends one: near-you is by
  /// connection only).
  browser,

  /// Worked out from the connection's address.
  ip,

  /// Unknown.
  none,
}

/// Where the server thinks the person is (`where` on the discover answers).
///
/// The app sends no coordinates, so the server places it by the
/// connection's address: "Near Thiruvananthapuram".
class DiscoverWhere extends Equatable {
  const DiscoverWhere({
    this.city,
    this.region,
    this.lat,
    this.lng,
    this.source = WhereSource.none,
  });

  static const unknown = DiscoverWhere();

  final String? city;
  final String? region;
  final double? lat;
  final double? lng;
  final WhereSource source;

  /// The server knows a point for them.
  bool get isPlaced => lat != null && lng != null && source != WhereSource.none;

  /// "Near Thiruvananthapuram", "Near you", or "Everywhere".
  String get label {
    final c = city?.trim() ?? '';
    if (c.isNotEmpty) return 'Near $c';
    if (isPlaced) return 'Near you';
    return 'Everywhere';
  }

  /// Why the list is about that place, in a sentence.
  String get explanation {
    final c = city?.trim() ?? '';
    if (source == WhereSource.ip && c.isNotEmpty) {
      return 'We guessed $c from your connection.';
    }
    if (isPlaced) return 'We guessed your area from your connection.';
    return "We couldn't tell where you are, so you're seeing everything.";
  }

  @override
  List<Object?> get props => [city, region, lat, lng, source];
}
