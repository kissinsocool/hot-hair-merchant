import '../../../core/network/api_client.dart';
import '../../booking/domain/booking_order.dart';

class AdminRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchOverview() async {
    final response = await _apiClient.request('/admin/overview');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchMerchants() async {
    final response = await _apiClient.request('/admin/merchants');
    return (response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createMerchant({
    required String username,
    required String displayName,
    required String password,
    required String salonId,
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants',
      method: 'POST',
      data: {
        'username': username,
        'displayName': displayName,
        'password': password,
        'salonId': salonId,
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
    String password = '',
  }) async {
    final response = await _apiClient.request(
      '/admin/merchants/$id',
      method: 'PATCH',
      data: {
        'username': username,
        'displayName': displayName,
        'salonId': salonId,
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
    final response = await _apiClient.request('/admin/users');
    return (response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<BookingOrder>> fetchBookings() async {
    final response = await _apiClient.request('/admin/bookings');
    return (response.data as List<dynamic>)
        .map(
          (item) =>
              BookingOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
