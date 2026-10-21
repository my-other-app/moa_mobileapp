import 'package:finnet/features/discover/domain/entities/discover_where.dart';

/// A city the person can pick as their place: the cities the website has
/// pages for (`src/seo/cities.js`), Kerala first, with the same centres.
class DiscoverCity {
  const DiscoverCity(this.slug, this.name, this.state, this.lat, this.lng);

  final String slug;
  final String name;
  final String state;
  final double lat;
  final double lng;

  /// The city as the lists' place.
  DiscoverWhere get where => DiscoverWhere(
        city: name,
        region: state,
        lat: lat,
        lng: lng,
        source: WhereSource.picked,
      );
}

const discoverCities = [
  DiscoverCity('kochi', 'Kochi', 'Kerala', 9.9816, 76.2999),
  DiscoverCity(
      'thiruvananthapuram', 'Thiruvananthapuram', 'Kerala', 8.5241, 76.9366),
  DiscoverCity('kozhikode', 'Kozhikode', 'Kerala', 11.2588, 75.7804),
  DiscoverCity('thrissur', 'Thrissur', 'Kerala', 10.5276, 76.2144),
  DiscoverCity('kannur', 'Kannur', 'Kerala', 11.8745, 75.3704),
  DiscoverCity('kottayam', 'Kottayam', 'Kerala', 9.5916, 76.5222),
  DiscoverCity('kollam', 'Kollam', 'Kerala', 8.8932, 76.6141),
  DiscoverCity('alappuzha', 'Alappuzha', 'Kerala', 9.4981, 76.3388),
  DiscoverCity('palakkad', 'Palakkad', 'Kerala', 10.7867, 76.6548),
  DiscoverCity('malappuram', 'Malappuram', 'Kerala', 11.051, 76.0711),
  DiscoverCity('bengaluru', 'Bengaluru', 'Karnataka', 12.9716, 77.5946),
  DiscoverCity('chennai', 'Chennai', 'Tamil Nadu', 13.0827, 80.2707),
  DiscoverCity('coimbatore', 'Coimbatore', 'Tamil Nadu', 11.0168, 76.9558),
  DiscoverCity('mangaluru', 'Mangaluru', 'Karnataka', 12.9141, 74.856),
  DiscoverCity('hyderabad', 'Hyderabad', 'Telangana', 17.385, 78.4867),
  DiscoverCity('mumbai', 'Mumbai', 'Maharashtra', 19.076, 72.8777),
  DiscoverCity('pune', 'Pune', 'Maharashtra', 18.5204, 73.8567),
  DiscoverCity('delhi', 'Delhi', 'Delhi', 28.6139, 77.209),
];
