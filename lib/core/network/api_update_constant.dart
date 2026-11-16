import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'network_mode_config.dart';

class UpdateConstants {
  static String get updateBaseUrl => NetworkModeConfig.updateBaseUrl;
  static String get appId =>
      (dotenv.env['APP_ID'] ?? 'tablet').trim(); // default tablet

  static String get versionUrl => '$updateBaseUrl/api/update/$appId/version';

  static String downloadUrl(String fileName) =>
      '$updateBaseUrl/api/update/$appId/download/${fileName.trim()}';
}
