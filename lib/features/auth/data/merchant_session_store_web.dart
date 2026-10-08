// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'merchant_session_store.dart';

class MerchantSessionStoreImpl implements MerchantSessionStore {
  MerchantSessionStoreImpl({this.role = PortalRole.merchant});

  final PortalRole role;
  static const _legacyTokenKey = 'merchant_auth_token';
  static const _legacyUserKey = 'merchant_auth_user';
  String get _tokenKey => '${role.name}_auth_token_v2';
  String get _userKey => '${role.name}_auth_user_v2';

  @override
  Future<MerchantSession?> read() async {
    final token = html.window.localStorage[_tokenKey];
    final userJson = html.window.localStorage[_userKey];
    if (token == null || token.isEmpty || userJson == null) {
      return _readLegacy();
    }

    try {
      final user = Map<String, dynamic>.from(jsonDecode(userJson) as Map);
      return MerchantSession(token: token, user: user);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<MerchantSession?> _readLegacy() async {
    final token = html.window.localStorage[_legacyTokenKey];
    final userJson = html.window.localStorage[_legacyUserKey];
    if (token == null || token.isEmpty || userJson == null) return null;
    try {
      final user = Map<String, dynamic>.from(jsonDecode(userJson) as Map);
      if ((user['role'] == 'admin') != (role == PortalRole.admin)) return null;
      final session = MerchantSession(token: token, user: user);
      await save(session);
      html.window.localStorage.remove(_legacyTokenKey);
      html.window.localStorage.remove(_legacyUserKey);
      return session;
    } catch (_) {
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
    final legacyUserJson = html.window.localStorage[_legacyUserKey];
    if (legacyUserJson != null) {
      try {
        final user = Map<String, dynamic>.from(
          jsonDecode(legacyUserJson) as Map,
        );
        if ((user['role'] == 'admin') == (role == PortalRole.admin)) {
          html.window.localStorage.remove(_legacyTokenKey);
          html.window.localStorage.remove(_legacyUserKey);
        }
      } catch (_) {
        // Leave unknown legacy data untouched for the other portal.
      }
    }
  }
}
