import 'package:dio/dio.dart' show Response;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
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
  /// opens with no signal -- without its pictures then ([_fresh]).
  Future<NetworkList> list(NetworkQuery query) async {
    final res = await _client.request('/network', DioMethod.get,
        param: query.toParams(), cache: CachePolicy.personal);
    return NetworkList.fromJson(_fresh(res));
  }

  /// `GET /network/{id}`: with every encounter.
  Future<NetworkPerson> person(int id) async {
    final res = await _client.request('/network/$id', DioMethod.get,
        cache: CachePolicy.personal);
    return _person(_fresh(res));
  }

  /// The answer's data -- minus its pictures when it is the copy saved on
  /// the phone, answered for lack of a signal. Pictures are signed links
  /// that expire within the hour, so an old copy's are never used; the
  /// screens read the list again once the phone is back online. A 304's
  /// copy is the server's current answer byte for byte, links and all.
  static Object? _fresh(Response<dynamic> res) =>
      ApiCacheInterceptor.answerOf(res) == CachedAnswer.offline
          ? withoutPictures(res.data)
          : res.data;

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
      {int? eventId, int page = 1, int pageSize = savedMePageSize}) async {
    final res =
        await _client.request('/network/saved-me', DioMethod.get, param: {
      if (eventId != null) 'event_id': eventId,
      'page': page,
      // The server's default is 20; its most, 100.
      'page_size': pageSize,
    });
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

/// How many of "Saved you" are read at a time: the server's most.
const savedMePageSize = 100;

/// [json] with every `picture` and `image` link taken out, at any depth.
Object? withoutPictures(Object? json) {
  if (json is List) return [for (final item in json) withoutPictures(item)];
  if (json is Map) {
    return {
      for (final entry in json.entries)
        if (entry.key != 'picture' && entry.key != 'image')
          '${entry.key}': withoutPictures(entry.value),
    };
  }
  return json;
}

/// The network as contact cards (vCard 3.0) or a spreadsheet.
enum NetworkExportFormat { vcf, csv }
