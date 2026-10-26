import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/domain/registration_request.dart';

final registrationRequestsApiProvider =
    Provider<RegistrationRequestsApi>((ref) => RegistrationRequestsApi());

/// A person's requests for a place at events that confirm each
/// registration (feature-register `approvals-contract.md`). Through the
/// app's one API client, as [TicketingApi] is: refusals arrive as
/// `ApiException`s with their `error_code`.
class RegistrationRequestsApi {
  RegistrationRequestsApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  static const minePath = '/registration-requests/mine';

  static String _path(String token) =>
      '/registration-requests/${Uri.encodeComponent(token)}';

  /// `GET /registration-requests/{token}`: where the request stands. The
  /// token is the credential (a guest's status link); no session goes, and
  /// nothing is saved -- the server says `no-store`.
  Future<RegistrationRequest> byToken(String token) async {
    final res = await _client.request(
      _path(token),
      DioMethod.get,
      skipAuth: true,
    );
    final request = RegistrationRequest.fromJson(res.data, token: token);
    if (request == null) {
      throw const FormatException('The request had no answer');
    }
    return request;
  }

  /// `POST /registration-requests/{token}/withdraw`: from pending (or
  /// confirmed and unpaid, which lets the held place go) to withdrawn. The
  /// request as it now stands.
  Future<RegistrationRequest> withdraw(String token) async {
    final res = await _client.request(
      '${_path(token)}/withdraw',
      DioMethod.post,
      skipAuth: true,
    );
    return RegistrationRequest.fromJson(res.data, token: token) ??
        RegistrationRequest(
            id: '', status: RequestStatus.withdrawn, token: token);
  }

  /// `GET /registration-requests/mine`: the signed-in person's requests,
  /// open ones first. Saved like the rest of My events (personal, kept), so
  /// the section shows offline. Null from a server without the route (a
  /// 404): the app then shows nothing of it.
  Future<List<RegistrationRequest>?> mine() async {
    try {
      final res = await _client.request(
        minePath,
        DioMethod.get,
        cache: CachePolicy.personalKept,
      );
      return RegistrationRequest.listFromJson(res.data);
    } catch (e) {
      if (statusCodeOf(e) == 404) return null;
      rethrow;
    }
  }

  /// The copy of [mine] saved on the phone, or null when there is none.
  Future<List<RegistrationRequest>?> savedMine() async {
    try {
      final saved =
          await _client.savedCopy(minePath, policy: CachePolicy.personalKept);
      return saved == null ? null : RegistrationRequest.listFromJson(saved);
    } catch (_) {
      return null;
    }
  }
}
