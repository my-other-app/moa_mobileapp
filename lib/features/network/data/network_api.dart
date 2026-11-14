import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/network/data/profiles_api.dart'
    show textOfAnswer;
import 'package:finnet/features/network/domain/network.dart';

final networkApiProvider = Provider<NetworkApi>((ref) => NetworkApi());

/// The person's network on the server (feature-register
/// `profiles-networking-contract.md`, "Network").
class NetworkApi {
  NetworkApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  /// `POST /network`: save someone, by their personal code or their
  /// handle. [metAt] is when a scan taken offline was made; the server
  /// records the event only when both are checked in to it, and it is on.
  Future<SaveResult> save({
    String? code,
    String? handle,
    required MetHow method,
    int? eventId,
    DateTime? metAt,
  }) async {
    assert(code != null || handle != null);
    final res = await _client.request('/network', DioMethod.post, param: {
      if (code != null) 'code': code,
      if (code == null && handle != null) 'handle': handle,
      'method': method.name,
      if (eventId != null) 'event_id': eventId,
      if (metAt != null) 'met_at': metAt.toUtc().toIso8601String(),
    });
    final saved = SaveResult.fromJson(res.data);
    if (saved == null) throw const FormatException('No person in the answer');
    return saved;
  }

  /// `GET /network`. Kept on the phone (cleared at sign-out), so the tab
  /// opens with no signal.
  Future<NetworkList> list(NetworkQuery query) async {
    final res = await _client.request('/network', DioMethod.get,
        param: query.toParams(), cache: CachePolicy.personal);
    return NetworkList.fromJson(res.data);
  }

  /// `GET /network/{id}`: with every encounter.
  Future<NetworkPerson> person(int id) async {
    final res = await _client.request('/network/$id', DioMethod.get,
        cache: CachePolicy.personal);
    return _person(res.data);
  }

  /// `PATCH /network/{id}`: the note and tags, both private.
  Future<NetworkPerson> update(int id,
      {String? note, List<String>? tags}) async {
    final res = await _client.request('/network/$id', DioMethod.patch, param: {
      if (note != null) 'note': note.trim().isEmpty ? null : note.trim(),
      if (tags != null) 'tags': tags,
    });
    return _person(res.data);
  }

  /// `DELETE /network/{id}`: silent to them.
  Future<void> remove(int id) =>
      _client.request('/network/$id', DioMethod.delete);

  /// `GET /network/saved-me`: who saved the person, not saved back.
  Future<({List<SavedMeEntry> items, int total})> savedMe(
      {int? eventId, int page = 1}) async {
    final res = await _client.request('/network/saved-me', DioMethod.get,
        param: {if (eventId != null) 'event_id': eventId, 'page': page});
    final items = SavedMeEntry.listFrom(res.data);
    return (
      items: items,
      total: jsonInt(jsonObject(res.data)?['total']) ?? items.length,
    );
  }

  /// `GET /network/export?format=vcf|csv`: everyone, as a file's text.
  Future<String> export(NetworkExportFormat format) async {
    final res = await _client.request('/network/export', DioMethod.get,
        param: {'format': format.name});
    return textOfAnswer(res.data);
  }

  static NetworkPerson _person(Object? data) {
    final person = NetworkPerson.fromJson(data);
    if (person == null) throw const FormatException('No person in the answer');
    return person;
  }
}

/// The network as contact cards (vCard 3.0) or a spreadsheet.
enum NetworkExportFormat { vcf, csv }
