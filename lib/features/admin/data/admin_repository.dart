import '../../../core/network/api_client.dart';
import '../../booking/domain/booking_order.dart';

class AdminRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchOverview() async {
    final response = await _apiClient.request('/admin/overview');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchAd() async {
    final response = await _apiClient.request('/admin/ad');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveAd({
    required String imageUrl,
    required String link,
    required bool enabled,
    String? fileName,
    String? base64Data,
  }) async {
    final response = await _apiClient.request(
      '/admin/ad',
      method: 'PATCH',
      data: {
        'imageUrl': imageUrl,
        'link': link,
        'enabled': enabled,
        'fileName': ?fileName,
        'data': ?base64Data,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchMerchants() async {
    final data = await _apiClient.requestAllPages('/admin/merchants');
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> createMerchant({
    required String username,
    required String displayName,
    required String password,
    required String salonId,
    required String deposit,
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants',
      method: 'POST',
      data: {
        'username': username,
        'displayName': displayName,
        'password': password,
        'salonId': salonId,
        'deposit': deposit,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<Map<String, dynamic>> updateMerchant({
    required String id,
    required String username,
    required String displayName,
    required String salonId,
    required String deposit,
    String password = '',
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants/$id',
      method: 'PATCH',
      data: {
        'username': username,
        'displayName': displayName,
        'salonId': salonId,
        'deposit': deposit,
        'password': password,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<Map<String, dynamic>> reviewMerchantLicense({
    required String id,
    required bool approve,
    String reason = '',
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants/$id/license',
      method: 'PATCH',
      data: {'action': approve ? 'approve' : 'reject', 'reason': reason},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['merchant'] as Map);
  }

  Future<Map<String, dynamic>> reviewMerchantContent({
    required String id,
    required bool approve,
    String reason = '',
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants/$id/content',
      method: 'PATCH',
      data: {'action': approve ? 'approve' : 'reject', 'reason': reason},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['merchant'] as Map);
  }

  Future<Map<String, dynamic>> updateMerchantPublishStatus({
    required String id,
    required bool online,
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants/$id/publish',
      method: 'PATCH',
      data: {'action': online ? 'online' : 'offline'},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['merchant'] as Map);
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final data = await _apiClient.requestAllPages('/admin/users');
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<BookingOrder>> fetchBookings() async {
    final data = await _apiClient.requestAllPages('/admin/bookings');
    return data
        .map(
          (item) =>
              BookingOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchUserImages() async {
    final data = await _apiClient.requestAllPages(
      '/admin/user-images',
      useTotal: false,
    );
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> manageUserImage({
    required String bookingId,
    required String type,
    required String action,
  }) async {
    await _apiClient.request(
      '/admin/user-images',
      method: 'PATCH',
      data: {'bookingId': bookingId, 'type': type, 'action': action},
    );
  }
}
