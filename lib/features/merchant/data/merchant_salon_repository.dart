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

  /// [authorStaffId] 为 null 时以店铺本身的名义投稿（authorType: salon）。
  /// [promotionCategoryId] 取自 salonPostPromotionCategories，后端据此把作品归到小程序首页的分类。
  Future<Map<String, dynamic>> createSalonPost({
    required String? authorStaffId,
    required String content,
    required List<String> imageUrls,
    required String promotionCategoryId,
    String? serviceId,
  }) async {
    final response = await _apiClient.request(
      '/merchant/salon-posts',
      method: 'POST',
      data: {
        'authorType': authorStaffId == null ? 'salon' : 'staff',
        'authorStaffId': ?authorStaffId,
        'content': content,
        'imageUrls': imageUrls,
        'serviceId': ?serviceId,
        'promotionCategoryId': promotionCategoryId,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteSalonPost(String id) async {
    await _apiClient.request('/merchant/salon-posts/$id', method: 'DELETE');
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
    CancelToken? cancelToken,
  }) async {
    final uploads = await _apiClient.uploadBase64Images(
      type: 'public',
      cancelToken: cancelToken,
      images: [(fileName: fileName, base64Data: base64Data)],
    );
    return uploads.single['url'] as String;
  }
}
