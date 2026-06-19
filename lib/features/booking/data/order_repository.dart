import '../../../core/network/api_client.dart';
import '../domain/booking_order.dart';

class OrderRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<BookingOrder>> fetchMerchantBookings({String? status}) async {
    final path = status == null
        ? '/merchant/bookings'
        : '/merchant/bookings?status=$status';
    final response = await _apiClient.request(path);
    final data = response.data as List<dynamic>;

    return data
        .map((item) => BookingOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BookingOrder> updateMerchantBooking(
    String bookingId, {
    required bool accept,
    String reason = '',
    String assignedStaffId = '',
  }) async {
    return updateMerchantBookingStatus(
      bookingId,
      action: accept ? 'accept' : 'reject',
      reason: reason,
      assignedStaffId: assignedStaffId,
    );
  }

  Future<BookingOrder> updateMerchantBookingStatus(
    String bookingId, {
    required String action,
    String reason = '',
    String assignedStaffId = '',
  }) async {
    final response = await _apiClient.request(
      '/merchant/bookings/$bookingId',
      method: 'PATCH',
      data: {
        'action': action,
        'reason': reason,
        if (assignedStaffId.isNotEmpty) 'assignedStaffId': assignedStaffId,
      },
    );

    return BookingOrder.fromJson(
      Map<String, dynamic>.from(response.data['booking']),
    );
  }

  Future<BookingOrder> replyToReview(
    String bookingId, {
    required String reply,
  }) async {
    final response = await _apiClient.request(
      '/merchant/bookings/$bookingId/review-reply',
      method: 'PATCH',
      data: {'reply': reply},
    );

    return BookingOrder.fromJson(
      Map<String, dynamic>.from(response.data['booking']),
    );
  }
}
