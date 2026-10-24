import 'package:envied/envied.dart';

part 'env.g.dart';

/// Environment configuration using envied for secure access to environment variables.
///
/// Run `dart run build_runner build --delete-conflicting-outputs` to generate env.g.dart
///
/// These must be `static final` fields, not getters: envied's generator scans the
/// annotated class's *fields*, so declaring them as `get` produced an empty `_Env`
/// and nothing compiled. They can't be `const` either, because `obfuscate: true`
/// makes the generated values computed from encrypted byte arrays at runtime.
@Envied(path: '.env', obfuscate: true)
abstract class Env {
  /// API base URL for network requests
  @EnviedField(varName: 'API_BASE_URL')
  static final String apiBaseUrl = _Env.apiBaseUrl;

  /// Enable analytics tracking
  @EnviedField(varName: 'ENABLE_ANALYTICS', defaultValue: 'false')
  static final String enableAnalytics = _Env.enableAnalytics;

  /// Razorpay key id (the public one; the checkout opens with it)
  @EnviedField(varName: 'RAZORPAY_KEY_ID', defaultValue: '')
  static final String razorpayKeyId = _Env.razorpayKeyId;
}
