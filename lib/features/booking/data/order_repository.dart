import '../../../core/network/api_client.dart';
import '../domain/booking_order.dart';

class MerchantBookingPage {
  const MerchantBookingPage(this.orders, this.hasMore);
  final List<BookingOrder> orders;
  final bool hasMore;
}

class OrderRepository {
  OrderRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();
  final ApiClient _apiClient;

  Future<MerchantBookingPage> fetchMerchantBookingPage({
    required int page,
    Map<String, dynamic>? filters,
  }) async {
    const limit = 20;
    final response = await _apiClient.request(
      '/merchant/bookings',
      queryParameters: {...?filters, 'page': page, 'limit': limit},
    );
    final rows = response.data as List;
    final total = int.tryParse(response.headers.value('x-total-count') ?? '');
    return MerchantBookingPage(
      rows
          .map(
            (item) =>
                BookingOrder.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      hasMorePages((page - 1) * limit + rows.length, rows.length, limit, total),
    );
  }

  Future<Map<String, int>> fetchMerchantBookingCounts(
    Map<String, dynamic> filters,
  ) async {
    final response = await _apiClient.request(
      '/merchant/bookings/summary',
      queryParameters: filters,
    );
    return (response.data['counts'] as Map).map(
      (key, value) => MapEntry(key.toString(), (value as num).toInt()),
    );
  }

  Future<List<Map<String, dynamic>>> fetchRescheduleSlots(
    String bookingId,
    DateTime date,
  ) async {
    final response = await _apiClient.request(
      '/merchant/bookings/$bookingId/slots',
      queryParameters: {'date': date.toIso8601String().split('T').first},
    );
    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<BookingOrder>> fetchMerchantBookings({
    String? status,
    DateTime? date,
  }) async {
    final data = await _apiClient.requestAllPages(
      '/merchant/bookings',
      queryParameters: {
        'status': ?status,
        if (date != null) 'date': date.toIso8601String().split('T').first,
      },
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
