import 'package:equatable/equatable.dart';

/// How far "near" reaches, in km: the server's own radius for "near you"
/// (`NEAR_KM` and the lists' default `radius_km`).
const nearKm = 50.0;

/// Whether something [km] away is near: within [nearKm]. Not when the
/// distance is unknown (online, or no venue yet).
bool isNearby(double? km) => km != null && km <= nearKm;

/// A point to ask the lists about.
typedef DiscoverPoint = ({double lat, double lng});

/// How the place was come by.
enum WhereSource {
  /// A point the caller sent: the server says so of every list the app
  /// asks about its kept place ([DiscoverWhere.point]).
  browser,

  /// Worked out from the connection's address.
  ip,

  /// A city the person picked.
  picked,

  /// Unknown.
  none,
}

/// Where the discover lists are about (`where` on the discover answers, or
/// the place the app keeps for them).
///
/// The app asks for no location permission. The first time, the server
/// places it by the connection's address -- "Near Thiruvananthapuram" --
/// and that guess is kept: every list after is asked about its point, so
/// a phone that moves from Wi-Fi to mobile data, whose address the server
/// often puts in another city, keeps its place. A city the person picks
/// replaces it.
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

  /// There is a point for them.
  bool get isPlaced => lat != null && lng != null && source != WhereSource.none;

  /// The point the lists are asked about, to about a hundred metres (as
  /// the website keeps one); null when not placed.
  DiscoverPoint? get point =>
      isPlaced ? (lat: _round(lat!), lng: _round(lng!)) : null;

  static double _round(double v) => (v * 1000).round() / 1000;

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
    if (source == WhereSource.picked && c.isNotEmpty) return 'You picked $c.';
    if (source == WhereSource.ip && c.isNotEmpty) {
      return 'We guessed $c from your connection.';
    }
    if (isPlaced) return 'We guessed your area from your connection.';
    return "We couldn't tell where you are, so you're seeing everything.";
  }

  @override
  List<Object?> get props => [city, region, lat, lng, source];
}
