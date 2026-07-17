import 'package:finnet/core/api/api_helper.dart';

class Endpoints {
  //TODO: move all integrated endpoints here to keep in track
  static const Endpoints getProfile =
      Endpoints._('/user/profile/me', DioMethod.get);

  final String url;
  final DioMethod requestType;

  const Endpoints._(this.url, this.requestType);
}
