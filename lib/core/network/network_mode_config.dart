import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NetworkMode { auto, internal, public }

class NetworkModeConfig {
  static const String _prefsKey = 'network_mode';
  static const String _autoResolvedPrefsKey = 'network_mode_auto_resolved';

  static NetworkMode _currentMode = NetworkMode.auto;
  static NetworkMode _resolvedAutoMode = NetworkMode.internal;
  static bool _initialized = false;
  static bool _isConnectivityListenerAttached = false;
  static final Connectivity _connectivity = Connectivity();

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    _currentMode = _parseMode(saved) ?? _defaultModeFromEnv();

    final savedResolved = _parseMode(prefs.getString(_autoResolvedPrefsKey));
    if (savedResolved == NetworkMode.internal ||
        savedResolved == NetworkMode.public) {
      _resolvedAutoMode = savedResolved!;
    } else {
      _resolvedAutoMode = NetworkMode.internal;
    }

    await prefs.setString(_prefsKey, _currentMode.name);
    await prefs.setString(_autoResolvedPrefsKey, _resolvedAutoMode.name);
    _initialized = true;

    _ensureAutoConnectivityState();
    if (_currentMode == NetworkMode.auto) {
      unawaited(_syncResolvedModeFromConnectivity());
    }
  }

  static void attachNetworkChangeListener() {
    if (_isConnectivityListenerAttached) return;
    _isConnectivityListenerAttached = true;
    _log('Attach connectivity listener');
    _connectivity.onConnectivityChanged.listen((results) {
      if (_currentMode != NetworkMode.auto) return;
      _log('Connectivity changed: ${_resultsText(results)}');
      unawaited(_applyConnectivityResults(results));
    });
    if (_currentMode == NetworkMode.auto) {
      unawaited(_syncResolvedModeFromConnectivity());
    }
  }

  static NetworkMode get currentMode => _currentMode;
  static NetworkMode get autoResolvedMode => _resolvedAutoMode;

  static String get currentModeLabel {
    switch (_currentMode) {
      case NetworkMode.internal:
        return 'Internal';
      case NetworkMode.public:
        return 'Public';
      case NetworkMode.auto:
        final resolved = _resolvedAutoMode == NetworkMode.public
            ? 'Public'
            : 'Internal';
        return 'Auto ($resolved)';
    }
  }

  static Future<void> setMode(NetworkMode mode) async {
    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
    _ensureAutoConnectivityState();
    if (_currentMode == NetworkMode.auto) {
      await _syncResolvedModeFromConnectivity();
    }
  }

  static String get apiBaseUrl {
    _ensureInitialized();
    final preferPublic = switch (_currentMode) {
      NetworkMode.public => true,
      NetworkMode.internal => false,
      NetworkMode.auto => _resolvedAutoMode == NetworkMode.public,
    };
    final chosen = preferPublic ? _publicApiUrl : _internalApiUrl;
    // Mode tersimpan bisa menunjuk ke URL yang belum dikonfigurasi (mis. mode
    // "public" tersimpan permanen padahal env saat ini tidak punya public
    // URL) -> jatuh balik ke URL lain yang tersedia daripada macet permanen.
    if (chosen.isNotEmpty) return chosen;
    return preferPublic ? _internalApiUrl : _publicApiUrl;
  }

  static String get updateBaseUrl {
    _ensureInitialized();
    final preferPublic = switch (_currentMode) {
      NetworkMode.public => true,
      NetworkMode.internal => false,
      NetworkMode.auto => _resolvedAutoMode == NetworkMode.public,
    };
    final chosen = preferPublic ? _publicUpdateUrl : _internalUpdateUrl;
    if (chosen.isNotEmpty) return chosen;
    return preferPublic ? _internalUpdateUrl : _publicUpdateUrl;
  }

  static String get internalApiBaseUrl => _internalApiUrl;

  static String get publicApiBaseUrl => _publicApiUrl;

  static NetworkMode _defaultModeFromEnv() {
    final raw = (dotenv.env['DEFAULT_NETWORK_MODE'] ?? '').trim().toLowerCase();
    return _parseMode(raw) ?? NetworkMode.auto;
  }

  static NetworkMode? _parseMode(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'internal':
        return NetworkMode.internal;
      case 'public':
        return NetworkMode.public;
      case 'auto':
        return NetworkMode.auto;
      default:
        return null;
    }
  }

  static String get _internalApiUrl =>
      (dotenv.env['API_BASE_URL_INTERNAL'] ?? dotenv.env['API_BASE_URL'] ?? '')
          .trim();

  static String get _publicApiUrl =>
      (dotenv.env['API_BASE_URL_PUBLIC'] ?? '').trim();

  static String get _internalUpdateUrl =>
      (dotenv.env['UPDATE_BASE_URL_INTERNAL'] ??
              dotenv.env['UPDATE_BASE_URL'] ??
              '')
          .trim();

  static String get _publicUpdateUrl =>
      (dotenv.env['UPDATE_BASE_URL_PUBLIC'] ?? '').trim();

  static void _ensureInitialized() {
    if (_initialized) return;
    _currentMode = _defaultModeFromEnv();
    _resolvedAutoMode = NetworkMode.internal;
    _initialized = true;
    _ensureAutoConnectivityState();
  }

  static void _ensureAutoConnectivityState() {
    if (_currentMode != NetworkMode.auto) return;
    if (!_isConnectivityListenerAttached) {
      attachNetworkChangeListener();
    }
  }

  static void notifyNetworkFailure() {
    if (_currentMode != NetworkMode.auto) return;
    unawaited(_syncResolvedModeFromConnectivity());
  }

  static Future<void> _syncResolvedModeFromConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _log('Connectivity check: ${_resultsText(results)}');
    await _applyConnectivityResults(results);
  }

  static Future<void> _setResolvedAutoMode(NetworkMode mode) async {
    if (mode == NetworkMode.auto) return;
    if (_resolvedAutoMode == mode) return;

    final previous = _resolvedAutoMode;
    _resolvedAutoMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoResolvedPrefsKey, _resolvedAutoMode.name);
    _log('AUTO SWITCH: ${previous.name.toUpperCase()} -> ${mode.name.toUpperCase()}');
  }

  static Future<void> _applyConnectivityResults(
    List<ConnectivityResult> results,
  ) async {
    final hasWifi = results.contains(ConnectivityResult.wifi);

    NetworkMode target = hasWifi ? NetworkMode.internal : NetworkMode.public;
    if (target == NetworkMode.internal && _internalApiUrl.isEmpty) {
      target = NetworkMode.public;
    } else if (target == NetworkMode.public && _publicApiUrl.isEmpty) {
      target = NetworkMode.internal;
    }

    _log(
      'Resolve mode from connectivity (wifi=$hasWifi) -> ${target.name.toUpperCase()}',
    );
    await _setResolvedAutoMode(target);
  }

  static String _resultsText(List<ConnectivityResult> results) {
    if (results.isEmpty) return 'none';
    return results.map((e) => e.name).join(',');
  }

  static void _log(String message) {
    debugPrint('[NetworkModeConfig] $message');
  }
}
