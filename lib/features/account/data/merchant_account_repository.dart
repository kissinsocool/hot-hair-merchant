import '../../../core/network/api_client.dart';
import '../../auth/data/merchant_session_store.dart';

class MerchantAccountRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchAccount() async {
    final response = await _apiClient.request('/merchant/account');
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<Map<String, dynamic>> fetchQualification() async {
    final response = await _apiClient.request('/merchant/qualification');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> submitQualification({
    String licenseUrl = '',
    String fileName = '',
    String base64Data = '',
  }) async {
    final response = await _apiClient.request(
      '/merchant/qualification',
      method: 'PATCH',
      data: base64Data.isNotEmpty
          ? {'fileName': fileName, 'data': base64Data}
          : {'licenseUrl': licenseUrl},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<MerchantSession> updateAccount({
    required String displayName,
    String currentPassword = '',
    String newPassword = '',
  }) async {
    final response = await _apiClient.request(
      '/merchant/account',
      method: 'PATCH',
      data: {
        'displayName': displayName,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = MerchantSession(
      token: data['token'] as String,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
    ApiClient.authToken = session.token;
    await MerchantSessionStore().save(session);
    return session;
  }
}
