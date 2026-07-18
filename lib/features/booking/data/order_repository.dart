import '../../../core/network/api_client.dart';
import '../domain/booking_order.dart';

class OrderRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<BookingOrder>> fetchMerchantBookings({String? status}) async {
    final data = await _apiClient.requestAllPages(
      '/merchant/bookings',
      queryParameters: {'status': ?status},
    );

    return data
        .map((item) => BookingOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchStaffSlots(
    String staffId,
    DateTime date, {
    String salonId = '',
  }) async {
    final response = await _apiClient.request(
      '/staff/$staffId/slots',
      queryParameters: {
        'date': date.toIso8601String().split('T').first,
        if (salonId.isNotEmpty) 'salonId': salonId,
      },
    );
    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
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
    DateTime? startTime,
  }) async {
    final response = await _apiClient.request(
      '/merchant/bookings/$bookingId',
      method: 'PATCH',
      data: {
        'action': action,
        'reason': reason,
        if (assignedStaffId.isNotEmpty) 'assignedStaffId': assignedStaffId,
        if (startTime != null) 'startTime': startTime.toIso8601String(),
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
