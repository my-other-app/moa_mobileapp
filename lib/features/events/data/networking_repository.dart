import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/networking.dart';

final networkingRepositoryProvider =
    Provider<NetworkingRepository>((ref) => NetworkingRepository());

/// People Like You on the server: the list for an event, and the person's
/// own "Show me in People Like You".
///
/// Through the app's one Dio, uncached: who is here changes by the minute,
/// and the list is about the person.
class NetworkingRepository {
  /// `GET /events/{id}/networking`. Throws the API's error as it came, so
  /// the screen can tell a closed list from one it couldn't load.
  Future<NetworkingPeople> people(int eventId) async {
    final res = await APIService.instance.request(
      '/events/$eventId/networking',
      DioMethod.get,
    );
    return NetworkingPeople.fromJson(
      jsonObject(res.data) ?? const <String, dynamic>{},
      eventId: eventId,
    );
  }

  /// `PATCH /user/preferences`: on, others here see them; off, nobody
  /// does. What the server kept comes back.
  Future<bool> setVisible(bool visible) async {
    final res = await APIService.instance.request(
      '/user/preferences',
      DioMethod.patch,
      param: {'networking_visible': visible},
    );
    return jsonBool(jsonObject(res.data)?['networking_visible']) ?? visible;
  }
}
