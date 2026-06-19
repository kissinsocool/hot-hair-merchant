// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'merchant_session_store.dart';

class MerchantSessionStoreImpl implements MerchantSessionStore {
  static const _tokenKey = 'merchant_auth_token';
  static const _userKey = 'merchant_auth_user';

  @override
  Future<MerchantSession?> read() async {
    final token = html.window.localStorage[_tokenKey];
    final userJson = html.window.localStorage[_userKey];
    if (token == null || token.isEmpty || userJson == null) return null;

    try {
      final user = Map<String, dynamic>.from(jsonDecode(userJson) as Map);
      return MerchantSession(token: token, user: user);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(MerchantSession session) async {
    html.window.localStorage[_tokenKey] = session.token;
    html.window.localStorage[_userKey] = jsonEncode(session.user);
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_tokenKey);
    html.window.localStorage.remove(_userKey);
  }
}
