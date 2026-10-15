import 'dart:async';

import '../../../core/network/api_client.dart';
import '../../booking/data/booking_update_stream.dart';
import 'merchant_session_store.dart';

class MerchantAuthRepository {
  MerchantAuthRepository({
    this.role = PortalRole.merchant,
    MerchantSessionStore? sessionStore,
    ApiClient? apiClient,
  }) : _sessionStore = sessionStore ?? MerchantSessionStore(role: role),
       _apiClient = apiClient ?? ApiClient();

  final PortalRole role;
  final ApiClient _apiClient;
  final MerchantSessionStore _sessionStore;

  Future<MerchantSession?> restoreSession() async {
    final session = await _sessionStore.read();
    if (session == null) return null;

    ApiClient.authToken = session.token;
    try {
      final response = await _apiClient.request(
        role == PortalRole.admin ? '/admin/auth/me' : '/merchant/auth/me',
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final user = Map<String, dynamic>.from(data['user'] as Map);
      final freshSession = MerchantSession(token: session.token, user: user);
      await _sessionStore.save(freshSession);
      return freshSession;
    } catch (_) {
      ApiClient.authToken = null;
      await _sessionStore.clear();
      return null;
    }
  }

  Future<MerchantSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.request(
      role == PortalRole.admin ? '/admin/auth/login' : '/merchant/auth/login',
      method: 'POST',
      data: {'username': username, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = MerchantSession(
      token: data['token'] as String,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
    if (role == PortalRole.merchant && ApiClient.authToken != session.token) {
      BookingUpdateStream.instance.stop();
    }
    ApiClient.authToken = session.token;
    await _sessionStore.save(session);
    return session;
  }

  Future<void> logout() async {
    final token = ApiClient.authToken;
    final pending = token == null
        ? null
        : _apiClient
              .request(
                role == PortalRole.admin
                    ? '/admin/auth/logout'
                    : '/merchant/auth/logout',
                method: 'POST',
              )
              .then<void>((_) {}, onError: (Object _) {});
    if (role == PortalRole.merchant) BookingUpdateStream.instance.stop();
    ApiClient.authToken = null;
    await _sessionStore.clear();
    // Remote revocation must not keep the old home mounted during a timeout.
    if (pending != null) unawaited(pending);
  }
}
