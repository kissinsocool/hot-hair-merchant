import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class SalonNameExistsException implements Exception {}

class MerchantSalonRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchSalon() async {
    final response = await _apiClient.request('/merchant/salon');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveSalon(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.request(
        '/merchant/salon',
        method: 'PATCH',
        data: payload,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) throw SalonNameExistsException();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> geocodeAddress(String address) async {
    final response = await _apiClient.request(
      '/merchant/geocode',
      method: 'POST',
      data: {'address': address},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reverseGeocodeLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.request(
      '/merchant/reverse-geocode',
      method: 'POST',
      data: {'latitude': latitude, 'longitude': longitude},
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
