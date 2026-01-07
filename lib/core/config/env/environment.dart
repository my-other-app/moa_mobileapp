/// Application environment types for different build configurations.
enum Environment {
  development,
  staging,
  production,
}

/// Extension methods for Environment enum.
extension EnvironmentExtension on Environment {
  bool get isDevelopment => this == Environment.development;
  bool get isStaging => this == Environment.staging;
  bool get isProduction => this == Environment.production;
  bool get isDebug => this != Environment.production;
}
