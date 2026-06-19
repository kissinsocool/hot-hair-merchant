import '../../../core/network/api_client.dart';

class MerchantSalonRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchSalon() async {
    final response = await _apiClient.request('/merchant/salon');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveSalon(Map<String, dynamic> payload) async {
    final response = await _apiClient.request(
      '/merchant/salon',
      method: 'PATCH',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> uploadImage({
    required String fileName,
    required String base64Data,
  }) async {
    final response = await _apiClient.request(
      '/merchant/uploads',
      method: 'POST',
      data: {'fileName': fileName, 'data': base64Data},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['url'] as String;
  }
}
