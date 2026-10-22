import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'discover_fixtures.dart';

// A stand-in for `/discover/*` that places the caller as the backend does
// (`app/api/discover/geo.py`, `service.py`), measured against production on
// 2026-10-22:
//
// - Without `lat`/`lng`, the caller is wherever their connection's address
//   says ([PlaceServer.ip]), which moves with the network.
// - With them, that point (`source: browser`), named only when the address
//   agrees within 75 km.
// - The home page's `near` is in-person events within 50 km; its `clubs`
//   are the nearest few however far, with their distances.
// - Find events near (a radius, the default 50 km) adds every online event
//   after the near ones, unless `type` says otherwise.

const ipThiruvananthapuram = {
  'city': 'Thiruvananthapuram',
  'region': 'Kerala',
  'lat': 8.48333,
  'lng': 76.91667,
  'source': 'ip',
};

const ipMumbai = {
  'city': 'Mumbai',
  'region': 'Maharashtra',
  'lat': 19.0728,
  'lng': 72.8826,
  'source': 'ip',
};

/// An event or a club somewhere (no point: online).
class Somewhere {
  const Somewhere(this.id, this.name, [this.lat, this.lng]);
  final int id;
  final String name;
  final double? lat;
  final double? lng;
  bool get online => lat == null;
}

const demoEvents = [
  Somewhere(1, 'Neural Tide Demo Day', 8.4947, 76.9285),
  Somewhere(2, "Founders' Dinner", 8.5662, 76.8740),
  Somewhere(3, 'Profiling in Production', 9.9627, 76.2950),
  Somewhere(4, 'Long Run to Kappad', 11.2570, 75.7800),
  Somewhere(5, 'First PR Saturday'),
];

const demoClubs = [
  Somewhere(11, 'Neural Tide', 8.4950, 76.9290),
  Somewhere(12, 'Borrow Checkers Kochi', 9.9630, 76.2950),
  Somewhere(13, 'Sulaimani Striders', 11.2570, 75.7800),
];

double km(double aLat, double aLng, double bLat, double bLng) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(bLat - aLat);
  final dLng = rad(bLng - aLng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(aLat)) *
          math.cos(rad(bLat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371 * math.asin(math.min(1, math.sqrt(h)));
}

class PlaceServer implements HttpClientAdapter {
  /// Where the connection's address puts the caller right now.
  Map<String, dynamic> ip = ipThiruvananthapuram;

  /// Every request, in order.
  final requests = <RequestOptions>[];

  /// Answers for `/discover/home` wait for this while it is set.
  Future<void>? holdHome;

  /// The phone has no connection: nothing reaches the server.
  bool offline = false;

  List<RequestOptions> sent(String path) =>
      requests.where((r) => r.path == path).toList();

  Map<String, dynamic> _where(Map<String, dynamic> q) {
    final lat = double.tryParse('${q['lat'] ?? ''}');
    final lng = double.tryParse('${q['lng'] ?? ''}');
    if (lat == null || lng == null) return Map.of(ip);
    final agrees = ip['lat'] != null &&
        km(lat, lng, ip['lat'] as double, ip['lng'] as double) <= 75;
    return {
      'city': agrees ? ip['city'] : null,
      'region': agrees ? ip['region'] : null,
      'lat': lat,
      'lng': lng,
      'source': 'browser',
    };
  }

  double? _from(Map<String, dynamic> where, Somewhere s) {
    final lat = where['lat'] as double?;
    final lng = where['lng'] as double?;
    if (lat == null || lng == null || s.online) return null;
    return double.parse(km(lat, lng, s.lat!, s.lng!).toStringAsFixed(1));
  }

  Map<String, dynamic> _event(Map<String, dynamic> where, Somewhere e) =>
      eventCard(e.id,
          name: e.name, online: e.online, distanceKm: _from(where, e))
        ..['lat'] = e.lat
        ..['lng'] = e.lng
        ..['location_name'] = e.online ? null : 'Venue of ${e.name}';

  Map<String, dynamic> _club(Map<String, dynamic> where, Somewhere c) =>
      clubCard(c.id, name: c.name, distanceKm: _from(where, c));

  Map<String, dynamic> _home(Map<String, dynamic> where) {
    final placed = where['lat'] != null;
    final near = [
      for (final e in demoEvents)
        if (placed && !e.online && _from(where, e)! <= 50) _event(where, e),
    ];
    final clubs = [for (final c in demoClubs) _club(where, c)];
    if (placed) {
      clubs.sort((a, b) =>
          (a['distance_km'] as double).compareTo(b['distance_km'] as double));
    }
    return homeBody(
      where: where,
      near: near,
      thisWeek: [for (final e in demoEvents) _event(where, e)],
      online: [
        for (final e in demoEvents)
          if (e.online) _event(where, e)
      ],
      popular: const [],
      clubs: clubs,
      threads: const [],
    );
  }

  Map<String, dynamic> _events(Map<String, dynamic> where, Map q) {
    final placed = where['lat'] != null;
    final radius = double.tryParse('${q['radius_km'] ?? 50}') ?? 50;
    final type = q['type'] ?? 'any';
    final items = <Map<String, dynamic>>[];
    for (final e in demoEvents) {
      if (type == 'online' && !e.online) continue;
      if (type == 'in_person' && e.online) continue;
      // Online events are anywhere: they pass any radius.
      if (placed && radius > 0 && !e.online && _from(where, e)! > radius) {
        continue;
      }
      items.add(_event(where, e));
    }
    if (q['sort'] == 'distance' && placed) {
      // Nearest first, then everything without a distance.
      items.sort((a, b) => ((a['distance_km'] as double?) ?? double.infinity)
          .compareTo((b['distance_km'] as double?) ?? double.infinity));
    }
    return eventsPage(items, where: where);
  }

  Map<String, dynamic> _clubs(Map<String, dynamic> where, Map q) {
    final placed = where['lat'] != null;
    final radius = double.tryParse('${q['radius_km'] ?? 50}') ?? 50;
    return clubsPage([
      for (final c in demoClubs)
        if (!placed || radius == 0 || _from(where, c)! <= radius)
          _club(where, c),
    ], where: where);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    }
    final q = options.uri.queryParameters;
    final where = _where(q);
    final Object body;
    switch (options.path) {
      case '/discover/home':
        final hold = holdHome;
        if (hold != null) await hold;
        body = _home(_where(q));
      case '/discover/events':
        body = _events(where, q);
      case '/discover/clubs':
        body = _clubs(where, q);
      case '/discover/calendar':
        body = {'month': q['month'], 'days': <String, int>{}};
      default:
        return ResponseBody.fromString(
            jsonEncode({'message': 'Not found'}), 404,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
