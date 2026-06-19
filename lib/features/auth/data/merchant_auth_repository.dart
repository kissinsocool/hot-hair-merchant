import '../../../core/network/api_client.dart';
import 'merchant_session_store.dart';

class MerchantAuthRepository {
  MerchantAuthRepository({MerchantSessionStore? sessionStore})
    : _sessionStore = sessionStore ?? MerchantSessionStore();

  final ApiClient _apiClient = ApiClient();
  final MerchantSessionStore _sessionStore;

  Future<MerchantSession?> restoreSession() async {
    final session = await _sessionStore.read();
    if (session == null) return null;

    ApiClient.authToken = session.token;
    try {
      final role = session.user['role']?.toString();
      final response = await _apiClient.request(
        role == 'admin' ? '/admin/auth/me' : '/merchant/auth/me',
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
    bool admin = false,
  }) async {
    final response = await _apiClient.request(
      admin ? '/admin/auth/login' : '/merchant/auth/login',
      method: 'POST',
      data: {'username': username, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = MerchantSession(
      token: data['token'] as String,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
    ApiClient.authToken = session.token;
    await _sessionStore.save(session);
    return session;
  }

  Future<void> logout() async {
    ApiClient.authToken = null;
    await _sessionStore.clear();
  }
}
