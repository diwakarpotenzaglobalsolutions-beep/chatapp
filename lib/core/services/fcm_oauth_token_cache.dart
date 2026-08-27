import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fcm_oauth_token_helper.dart';

/// Persists and reuses FCM OAuth access tokens until they expire.
class FcmOAuthTokenCache {
  static const _tokenKey = 'fcm_oauth_access_token';
  static const _expiryKey = 'fcm_oauth_token_expiry_ms';
  static const _expiryBuffer = Duration(minutes: 5);

  String? _memoryToken;
  DateTime? _memoryExpiry;
  Future<String?>? _refreshInFlight;

  /// Returns a valid cached token, refreshing only when expired or missing.
  Future<String?> getValidToken() async {
    final memory = _readFromMemory();
    if (memory != null) return memory;

    final persisted = await _readFromStorage();
    if (persisted != null) {
      _memoryToken = persisted;
      return persisted;
    }

    return _refreshToken();
  }

  Future<void> clear() async {
    _memoryToken = null;
    _memoryExpiry = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_expiryKey);
  }

  String? _readFromMemory() {
    if (_memoryToken != null &&
        _memoryExpiry != null &&
        DateTime.now().isBefore(_memoryExpiry!)) {
      return _memoryToken;
    }
    return null;
  }

  Future<String?> _readFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final expiryMs = prefs.getInt(_expiryKey);
      if (token == null || expiryMs == null) return null;

      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      if (DateTime.now().isBefore(expiry)) {
        _memoryExpiry = expiry;
        return token;
      }
    } catch (e) {
      developer.log('FCM token cache read error: $e');
    }
    return null;
  }

  Future<String?> _refreshToken() async {
    if (_refreshInFlight != null) return _refreshInFlight;

    _refreshInFlight = _performRefresh();
    try {
      return await _refreshInFlight;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _performRefresh() async {
    final result = await FcmOAuthTokenHelper.generateAccessToken();
    if (result == null) return null;

    final expiry = result.expiresAt.subtract(_expiryBuffer);
    _memoryToken = result.token;
    _memoryExpiry = expiry;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result.token);
      await prefs.setInt(_expiryKey, expiry.millisecondsSinceEpoch);
    } catch (e) {
      developer.log('FCM token cache write error: $e');
    }

    return result.token;
  }
}
