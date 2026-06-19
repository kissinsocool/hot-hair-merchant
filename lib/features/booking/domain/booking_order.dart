class BookingOrder {
  final String id;
  final String userId;
  final String userName;
  final String salonName;
  final String staffId;
  final String staffName;
  final String serviceName;
  final String servicePrice;
  final String serviceDuration;
  final DateTime startTime;
  final String status;
  final String statusLabel;
  final String userMessage;
  final String merchantMessage;
  final String? rejectReason;
  final bool reviewed;
  final Map<String, dynamic>? review;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookingOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.salonName,
    required this.staffId,
    required this.staffName,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceDuration,
    required this.startTime,
    required this.status,
    required this.statusLabel,
    required this.userMessage,
    required this.merchantMessage,
    this.rejectReason,
    this.reviewed = false,
    this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingOrder.fromJson(Map<String, dynamic> json) {
    return BookingOrder(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      salonName: json['salonName'] as String,
      staffId: json['staffId'] as String? ?? '',
      staffName: json['staffName'] as String,
      serviceName: json['serviceName'] as String,
      servicePrice: json['servicePrice'] as String? ?? '',
      serviceDuration: json['serviceDuration'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String? ?? json['status'] as String,
      userMessage: json['userMessage'] as String? ?? '',
      merchantMessage: json['merchantMessage'] as String? ?? '',
      rejectReason: json['rejectReason'] as String?,
      reviewed: json['reviewed'] as bool? ?? false,
      review: json['review'] is Map
          ? Map<String, dynamic>.from(json['review'] as Map)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
