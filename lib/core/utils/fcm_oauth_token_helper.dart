import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

class FcmOAuthTokenResult {
  final String token;
  final DateTime expiresAt;

  const FcmOAuthTokenResult({
    required this.token,
    required this.expiresAt,
  });
}

class FcmOAuthTokenHelper {
  FcmOAuthTokenHelper._();

  static const _serviceAccountAsset = 'assets/notijson.json';

  /// Generates a new OAuth access token. Prefer [FcmOAuthTokenCache.getValidToken].
  static Future<FcmOAuthTokenResult?> generateAccessToken() async {
    try {
      final jsonString = await rootBundle.loadString(_serviceAccountAsset);

      final credentials = ServiceAccountCredentials.fromJson(
        json.decode(jsonString) as Map<String, dynamic>,
      );

      final client = await clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

      final accessToken = client.credentials.accessToken;
      final expiresAt = accessToken.expiry ??
          DateTime.now().add(const Duration(hours: 1));

      developer.log('FCM OAuth access token generated (expires: $expiresAt)');
      if (kDebugMode) {
        debugPrint('FCM OAuth token refreshed, expires at: $expiresAt');
      }

      client.close();

      return FcmOAuthTokenResult(
        token: accessToken.data,
        expiresAt: expiresAt,
      );
    } catch (e) {
      developer.log('FCM OAuth token error: $e');
      return null;
    }
  }

  static Future<String?> getProjectId() async {
    try {
      final jsonString = await rootBundle.loadString(_serviceAccountAsset);
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return jsonMap['project_id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
