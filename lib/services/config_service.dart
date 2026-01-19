// lib/services/config_service.dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(hours: 12),
      ));

      await _remoteConfig.setDefaults({'gemini_api_key': ''});
      await _remoteConfig.fetchAndActivate();

      debugPrint('Remote Config: Initialized successfully');
    } catch (e) {
      debugPrint('Remote Config Error: $e');
    }
  }
  String getGeminiKey() {
    return _remoteConfig.getString('gemini_api_key');
  }
}