import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_width.dart';
import '../../booking/data/booking_update_stream.dart';
import '../data/image_upload_picker.dart';
import '../data/merchant_salon_repository.dart';
import 'merchant_notifications_screen.dart';

class MerchantSalonScreen extends StatefulWidget {
  const MerchantSalonScreen({
    super.key,
    this.repository,
    this.enableRealtime = true,
  });

  final MerchantSalonRepository? repository;
  final bool enableRealtime;

  @override
  State<MerchantSalonScreen> createState() => _MerchantSalonScreenState();
}

class _MerchantSalonScreenState extends State<MerchantSalonScreen> {
  late final MerchantSalonRepository _repository =
      widget.repository ?? MerchantSalonRepository();

  static const List<String> _staffRoleOptions = [
    '初级理发师',
    '中级理发师',
    '高级理发师',
    '首席发型师',
    '创意总监',
    '店长',
  ];
  static final List<int> _experienceYearOptions = List.generate(
    30,
    (index) => index + 1,
  );
  static final List<int> _serviceDurationOptions = List.generate(
    6,
    (index) => (index + 1) * 30,
  );

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGeocoding = false;
  bool _hasTriedAutoLocation = false;
  bool _isUploadingCover = false;
  int? _uploadingStaffIndex;
  int? _uploadingServiceIndex;
  String _errorMessage = '';
  Map<String, dynamic> _salon = {};
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _staff = [];
  final List<MerchantNotification> _notifications = [];
  final Set<String> _notifiedReviewIds = {};
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;
  int _unreadNotificationCount = 0;
  final Map<int, DateTime> _absenceDatesByStaffIndex = {};
  final Map<int, String> _absenceStartTimesByStaffIndex = {};
  final Map<int, String> _absenceEndTimesByStaffIndex = {};

  @override
  void initState() {
    super.initState();
    _loadSalon();
    if (widget.enableRealtime) {
      BookingUpdateStream.instance.start();
      _bookingUpdateSubscription = BookingUpdateStream.instance.stream.listen(
        _handleBookingEvent,
      );
    }
  }

  @override
  void dispose() {
    _bookingUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSalon() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final salon = await _repository.fetchSalon();
      if (!mounted) return;
      setState(() {
        _salon = salon;
        _services = _mapList(salon['services']);
        _staff = _mapList(salon['staff']);
        _isLoading = false;
      });
      unawaited(_autoFillAddressFromCurrentLocation());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleBookingEvent(Map<String, dynamic> event) {
    final booking = event['booking'];
    if (booking is! Map) return;
    final salonId = booking['salonId']?.toString() ?? '';
    final currentSalonId = _salon['id']?.toString() ?? '';
    if (currentSalonId.isNotEmpty &&
        salonId.isNotEmpty &&
        salonId != currentSalonId) {
      return;
    }

    final notification = _notificationFromBookingEvent(event, booking);
    if (notification == null || !mounted) return;

    setState(() {
      _notifications.insert(0, notification);
      if (_notifications.length > 30) {
        _notifications.removeRange(30, _notifications.length);
      }
      _unreadNotificationCount += 1;
    });
  }

  MerchantNotification? _notificationFromBookingEvent(
    Map<String, dynamic> event,
    Map<dynamic, dynamic> booking,
  ) {
    final userName = booking['userName']?.toString() ?? '用户';
    final serviceName = booking['serviceName']?.toString() ?? '预约服务';
    final reviewed = booking['reviewed'] == true;
    final review = booking['review'];

    if (reviewed && review is Map) {
      final reviewId = review['id']?.toString() ?? '${booking['id']}-review';
      if (_notifiedReviewIds.contains(reviewId)) return null;
      _notifiedReviewIds.add(reviewId);
      final rating = review['rating']?.toString() ?? '';
      final comment = review['comment']?.toString() ?? '';
      return MerchantNotification(
        id: reviewId,
        icon: Icons.rate_review_outlined,
        title: '收到新的客户评价',
        message: [
          '$userName 评价了 $serviceName${rating.isEmpty ? '' : ' · $rating星'}',
          if (comment.isNotEmpty) comment,
        ].join('\n'),
        time: DateTime.now(),
      );
    }

    return null;
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _saveSalon() async {
    final validationMessage = _validateSalonBeforeSave();
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final savedSalon = await _repository.saveSalon({
        ..._salon,
        'services': _services,
        'staff': _staff,
      });
      if (!mounted) return;
      setState(() {
        _salon = savedSalon;
        _services = _mapList(savedSalon['services']);
        _staff = _mapList(savedSalon['staff']);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店铺信息已提交审核')));
    } on SalonNameExistsException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店名已存在，不能保存成功')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateSalonBeforeSave() {
    String text(dynamic value) => value?.toString().trim() ?? '';

    for (final item in [
      ('店铺名称', _salon['name']),
      ('店铺地址', _salon['address']),
      ('营业时间', _salon['openingHours']),
      ('电话', _salon['phone']),
      ('首页短介绍', _salon['description']),
      ('详情页关于我们', _salon['fullDescription']),
      ('封面图', _salon['image']),
    ]) {
      if (text(item.$2).isEmpty) return '请填写${item.$1}';
    }
    if (_promoImages().isEmpty) return '请至少上传一张推广图';
    if (_services.isEmpty) return '请至少添加一个服务套餐';
    for (var i = 0; i < _services.length; i += 1) {
      final service = _services[i];
      for (final item in [
        ('第${i + 1}个套餐服务效果图', service['imageUrl']),
        ('第${i + 1}个套餐名称', service['name']),
        ('第${i + 1}个套餐价格', service['price']),
        ('第${i + 1}个套餐时长', service['duration']),
        ('第${i + 1}个套餐备注', service['note']),
      ]) {
        if (text(item.$2).isEmpty || text(item.$2) == '¥') {
          return '请填写${item.$1}';
        }
      }
    }
    if (_staff.isEmpty) return '请至少添加一个理发师';
    for (var i = 0; i < _staff.length; i += 1) {
      final profile = _staff[i];
      for (final item in [
        ('第${i + 1}个理发师头像', profile['imageUrl']),
        ('第${i + 1}个理发师姓名', profile['name']),
        ('第${i + 1}个理发师职位', profile['role']),
        ('第${i + 1}个理发师经验', profile['experience']),
        ('第${i + 1}个理发师个人简介', profile['bio']),
      ]) {
        if (text(item.$2).isEmpty) return '请填写${item.$1}';
      }
    }
    return null;
  }

  String _salonAddressText() {
    return (_salon['address'] ?? '').toString().trim();
  }

  Future<void> _autoFillAddressFromCurrentLocation() async {
    if (_hasTriedAutoLocation || !mounted) return;
    _hasTriedAutoLocation = true;
    if (_salonAddressText().isNotEmpty) return;

    setState(() => _isGeocoding = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final result = await _repository.reverseGeocodeLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final address = result['address']?.toString().trim() ?? '';
      if (!mounted || address.isEmpty || _salonAddressText().isNotEmpty) {
        return;
      }

      setState(() {
        _setSalonLocation(position.latitude, position.longitude);
        _salon['address'] = address;
        _salon['addressDetail'] = '';
        _salon['addressRegion'] = {};
      });
    } catch (_) {
      // 自动定位失败时保持空地址，商家仍可手动编辑。
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _refreshSalonLocation() async {
    if (!mounted) return;

    setState(() => _isGeocoding = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请开启定位服务后重试')));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请允许定位权限后重试')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      var address = '';
      try {
        final result = await _repository.reverseGeocodeLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        address = result['address']?.toString().trim() ?? '';
      } catch (_) {
        address = '';
      }
      if (!mounted) return;

      setState(() {
        _setSalonLocation(position.latitude, position.longitude);
        if (address.isNotEmpty) {
          _salon['address'] = address;
          _salon['addressDetail'] = '';
          _salon['addressRegion'] = {};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            address.isEmpty ? '已重新获取定位，请确认店铺地址' : '已重新获取定位和店铺地址，请保存店铺信息',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重新定位失败: $e')));
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Map<String, double>? _salonLocation() {
    final location = _salon['location'];
    if (location is! Map) return null;

    final latitude = double.tryParse(location['latitude']?.toString() ?? '');
    final longitude = double.tryParse(location['longitude']?.toString() ?? '');
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return {'latitude': latitude, 'longitude': longitude};
  }

  void _setSalonLocation(double latitude, double longitude) {
    _salon['location'] = {
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
    };
  }

  String _coverImage() {
    final image = _salon['image']?.toString().trim() ?? '';
    _salon['image'] = image;
    return image;
  }

  List<String> _promoImages() {
    final rawPromoImages = _salon['promoImages'];
    final legacyImages = _salon['images'];
    final promoImages = <String>[];

    void addImage(dynamic value) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty && !promoImages.contains(url)) promoImages.add(url);
    }

    if (rawPromoImages is List) {
      for (final image in rawPromoImages) {
        addImage(image);
      }
    }
    if (promoImages.isEmpty && legacyImages is List) {
      final coverImage = _coverImage();
      for (final image in legacyImages) {
        final url = image?.toString().trim() ?? '';
        if (url.isNotEmpty && url != coverImage) addImage(url);
      }
    }

    final normalized = promoImages.take(20).toList();
    _salon['promoImages'] = normalized;
    _salon['images'] = normalized;
    return normalized;
  }

  void _setPromoImages(List<String> images) {
    final normalized = images
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toSet()
        .take(20)
        .toList();
    _salon['promoImages'] = normalized;
    _salon['images'] = normalized;
  }

  void _addService() {
    setState(() {
      _services.insert(0, {
        'id': '',
        'name': '',
        'price': '¥',
        'duration': '30分钟',
        'note': '',
        'imageUrl': '',
      });
    });
  }

  void _addStaff() {
    setState(() {
      _staff.insert(0, {
        'id': '',
        'name': '',
        'role': _staffRoleOptions.first,
        'experience': '1年',
        'extraServiceFee': 0,
        'imageUrl': '',
        'bio': '',
        'unavailableSlots': <String>[],
      });
    });
  }

  void _moveService(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _services.length) return;
    setState(() {
      final item = _services.removeAt(fromIndex);
      _services.insert(toIndex, item);
    });
  }

  void _moveStaff(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _staff.length) return;
    setState(() {
      final item = _staff.removeAt(fromIndex);
      _staff.insert(toIndex, item);
    });
  }

  List<DateTime> _generateAbsenceDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day + index),
    );
  }

  List<String> _generateTimeBoundaries() {
    final boundaries = <String>[];
    for (var minutes = 0; minutes <= 23 * 60 + 30; minutes += 30) {
      boundaries.add(_minutesToTime(minutes));
    }
    return boundaries;
  }

  ({String start, String end}) _openingHoursRange() {
    final value = _salon['openingHours']?.toString() ?? '';
    final match = RegExp(
      r'(\d{1,2}:\d{2})\s*[-~—–]\s*(\d{1,2}:\d{2})',
    ).firstMatch(value);
    final start = match?.group(1) ?? '10:00';
    final end = match?.group(2) ?? '20:00';
    final options = _generateTimeBoundaries();
    return (
      start: options.contains(start) ? start : '10:00',
      end: options.contains(end) && _timeToMinutes(end) > _timeToMinutes(start)
          ? end
          : '20:00',
    );
  }

  void _setOpeningHours(String start, String end) {
    _salon['openingHours'] = '$start - $end';
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatAbsenceDateLabel(DateTime date) {
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return '${isToday ? '今天' : '周${weekdays[date.weekday - 1]}'}\n${date.month}/${date.day}';
  }

  List<String> _staffUnavailableSlots(Map<String, dynamic> profile) {
    final slots = profile['unavailableSlots'];
    if (slots is List) return slots.map((slot) => slot.toString()).toList();
    profile['unavailableSlots'] = <String>[];
    return profile['unavailableSlots'] as List<String>;
  }

  List<({String start, String end})> _unavailableRangesForDate(
    Map<String, dynamic> profile,
    DateTime date,
  ) {
    final dateKey = _formatDateKey(date);
    final times =
        _staffUnavailableSlots(profile)
            .where((slot) => slot.startsWith('$dateKey '))
            .map((slot) => slot.substring(11))
            .toList()
          ..sort((a, b) => _timeToMinutes(a).compareTo(_timeToMinutes(b)));

    if (times.isEmpty) return [];

    final ranges = <({String start, String end})>[];
    var rangeStart = times.first;
    var previous = times.first;

    for (final time in times.skip(1)) {
      if (_timeToMinutes(time) != _timeToMinutes(previous) + 30) {
        ranges.add((
          start: rangeStart,
          end: _minutesToTime(_timeToMinutes(previous) + 30),
        ));
        rangeStart = time;
      }
      previous = time;
    }

    ranges.add((
      start: rangeStart,
      end: _minutesToTime(_timeToMinutes(previous) + 30),
    ));
    return ranges;
  }

  void _addStaffUnavailableRange(
    Map<String, dynamic> profile,
    DateTime date,
    String startTime,
    String endTime,
  ) {
    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);
    if (endMinutes <= startMinutes) return;

    final dateKey = _formatDateKey(date);
    final slots = _staffUnavailableSlots(profile);
    setState(() {
      for (var minutes = startMinutes; minutes < endMinutes; minutes += 30) {
        final key = '$dateKey ${_minutesToTime(minutes)}';
        if (!slots.contains(key)) slots.add(key);
      }
      slots.sort();
      profile['unavailableSlots'] = slots;
    });
  }

  void _removeStaffUnavailableRange(
    Map<String, dynamic> profile,
    DateTime date,
    String startTime,
    String endTime,
  ) {
    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);
    final dateKey = _formatDateKey(date);
    final slots = _staffUnavailableSlots(profile);
    setState(() {
      for (var minutes = startMinutes; minutes < endMinutes; minutes += 30) {
        slots.remove('$dateKey ${_minutesToTime(minutes)}');
      }
      profile['unavailableSlots'] = slots;
    });
  }

  Future<void> _uploadStaffAvatar(int index) async {
    final pickedImage = await pickImageForUpload();
    if (pickedImage == null) return;

    setState(() => _uploadingStaffIndex = index);
    try {
      final url = await _repository.uploadImage(
        fileName: pickedImage.fileName,
        base64Data: pickedImage.base64Data,
      );
      if (!mounted) return;
      setState(() => _staff[index]['imageUrl'] = url);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像已上传，请保存店铺信息')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像上传失败: $e')));
    } finally {
      if (mounted) setState(() => _uploadingStaffIndex = null);
    }
  }

  Future<void> _uploadCoverImage() async {
    final pickedImage = await pickImageForUpload();
    if (pickedImage == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final url = await _repository.uploadImage(
        fileName: pickedImage.fileName,
        base64Data: pickedImage.base64Data,
      );
      if (!mounted) return;
      setState(() => _salon['image'] = url);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('封面已上传，请保存店铺信息')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('封面上传失败: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _uploadPromoImages() async {
    final currentImages = _promoImages();
    final remainCount = 20 - currentImages.length;
    if (remainCount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多上传20张推广图')));
      return;
    }

    final pickedImages = await pickImagesForUpload(limit: remainCount);
    if (pickedImages.isEmpty) return;
    if (!mounted) return;

    setState(() => _isUploadingCover = true);
    try {
      final uploadedUrls = <String>[];
      for (final pickedImage in pickedImages) {
        final url = await _repository.uploadImage(
          fileName: pickedImage.fileName,
          base64Data: pickedImage.base64Data,
        );
        uploadedUrls.add(url);
      }
      if (!mounted) return;
      setState(() => _setPromoImages([..._promoImages(), ...uploadedUrls]));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('推广图已上传，请保存店铺信息')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('推广图上传失败: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _uploadServiceImage(int index) async {
    final pickedImage = await pickImageForUpload();
    if (pickedImage == null) return;

    setState(() => _uploadingServiceIndex = index);
    try {
      final url = await _repository.uploadImage(
        fileName: pickedImage.fileName,
        base64Data: pickedImage.base64Data,
      );
      if (!mounted) return;
      setState(() => _services[index]['imageUrl'] = url);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('服务效果图已上传，请保存店铺信息')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('服务效果图上传失败: $e')));
    } finally {
      if (mounted) setState(() => _uploadingServiceIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: const Text(
          '店铺首页',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: _isLoading || _isSaving ? null : _loadSalon,
            icon: const Icon(Icons.refresh),
          ),
          _buildNotificationButton(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: '通知',
          onPressed: _openNotificationsPage,
          icon: const Icon(Icons.notifications_none),
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 12,
            top: 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.white, width: 1.4),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openNotificationsPage() async {
    setState(() => _unreadNotificationCount = 0);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MerchantNotificationsScreen(
          notifications: List.unmodifiable(_notifications),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPink),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text('店铺信息加载失败', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSalon,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppTheme.white,
            child: const TabBar(
              labelColor: AppTheme.primaryPink,
              unselectedLabelColor: AppTheme.textDark,
              indicatorColor: AppTheme.primaryPink,
              tabs: [
                Tab(icon: Icon(Icons.storefront), text: '店铺简介'),
                Tab(icon: Icon(Icons.spa), text: '服务套餐'),
                Tab(icon: Icon(Icons.badge), text: '理发师'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTabPage(_buildProfileSection()),
                _buildTabPage(_buildServicesSection()),
                _buildTabPage(_buildStaffSection()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.white,
              border: Border(top: BorderSide(color: AppTheme.accentBeige)),
            ),
            child: PageWidth(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSalon,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('保存并提交审核'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPage(Widget child) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        PageWidth(child: _buildContentReviewNotice()),
        const SizedBox(height: 12),
        PageWidth(child: child),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildContentReviewNotice() {
    final status = _salon['contentReviewStatus']?.toString() ?? 'pending';
    final reason = _salon['contentRejectReason']?.toString().trim() ?? '';
    final (icon, color, text) = switch (status) {
      'approved' => (
        Icons.check_circle_outline,
        Colors.green,
        '当前内容已通过审核，客户端正在展示这版内容。',
      ),
      'rejected' => (
        Icons.report_gmailerrorred_outlined,
        Colors.redAccent,
        reason.isEmpty ? '当前内容审核未通过，请修改后重新提交。' : '当前内容审核未通过：$reason',
      ),
      _ => (
        Icons.hourglass_top_outlined,
        AppTheme.primaryPink,
        '当前内容正在审核中，通过前客户端仍展示上一版已审核内容。',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return _buildSection(
      title: '店铺简介',
      icon: Icons.storefront,
      children: [
        _buildTextField('店铺名称', _salon['name'], (value) {
          _salon['name'] = value;
        }),
        _buildAddressFields(),
        _buildOpeningHoursSelector(),
        _buildTextField('电话', _salon['phone'], (value) {
          _salon['phone'] = value;
        }),
        _buildTextField('首页短介绍', _salon['description'], (value) {
          _salon['description'] = value;
        }, maxLines: 2),
        _buildTextField('详情页关于我们', _salon['fullDescription'], (value) {
          _salon['fullDescription'] = value;
        }, maxLines: 4),
        _buildCoverImagesUploader(),
      ],
    );
  }

  Widget _buildAddressFields() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppTheme.primaryPink),
              SizedBox(width: 8),
              Text(
                '店铺地址',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLocationCoordinatePicker(),
        ],
      ),
    );
  }

  Widget _buildLocationCoordinatePicker() {
    final location = _salonLocation();
    final address = _salonAddressText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey(address),
          initialValue: address,
          maxLines: 2,
          minLines: 1,
          onChanged: (value) => _salon['address'] = value.trim(),
          decoration: InputDecoration(
            hintText: '请重新定位生成店铺地址，也可以手动修改',
            filled: true,
            fillColor: AppTheme.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.accentBeige),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryPink),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                location == null ? '重新定位后会自动生成店铺地址。' : '定位和地址会随店铺信息一起保存。',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            FilledButton.icon(
              onPressed: _isGeocoding ? null : _refreshSalonLocation,
              icon: _isGeocoding
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined, size: 18),
              label: Text(_isGeocoding ? '定位中' : '重新定位'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpeningHoursSelector() {
    final range = _openingHoursRange();
    final options = _generateTimeBoundaries();
    final startOptions = options.take(options.length - 1).toList();
    final endOptions = options
        .where((time) => _timeToMinutes(time) > _timeToMinutes(range.start))
        .toList();
    final selectedEnd = endOptions.contains(range.end)
        ? range.end
        : endOptions.first;
    if (selectedEnd != range.end) {
      _setOpeningHours(range.start, selectedEnd);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimeDropdown(
              label: '营业开始时间',
              value: range.start,
              options: startOptions,
              onChanged: (value) {
                if (value == null) return;
                final nextEndOptions = options
                    .where(
                      (time) => _timeToMinutes(time) > _timeToMinutes(value),
                    )
                    .toList();
                final nextEnd = nextEndOptions.contains(selectedEnd)
                    ? selectedEnd
                    : nextEndOptions.first;
                setState(() => _setOpeningHours(value, nextEnd));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTimeDropdown(
              label: '营业结束时间',
              value: selectedEnd,
              options: endOptions,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _setOpeningHours(range.start, value));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return _buildSection(
      title: '服务套餐',
      icon: Icons.spa,
      trailing: IconButton(
        tooltip: '添加套餐',
        onPressed: _addService,
        icon: const Icon(Icons.add),
      ),
      children: [
        if (_services.isEmpty)
          _buildEmptyHint('还没有服务套餐')
        else
          ..._services.asMap().entries.map((entry) {
            final index = entry.key;
            final service = entry.value;
            return _buildNestedCard(
              title: service['name']?.toString().isNotEmpty == true
                  ? service['name'].toString()
                  : '新套餐',
              headerActions: [
                IconButton(
                  tooltip: '上移',
                  onPressed: index == 0
                      ? null
                      : () => _moveService(index, index - 1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: '下移',
                  onPressed: index == _services.length - 1
                      ? null
                      : () => _moveService(index, index + 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
              onDelete: () => setState(() => _services.removeAt(index)),
              children: [_buildServiceSummaryRow(index, service)],
            );
          }),
      ],
    );
  }

  Widget _buildServiceSummaryRow(int index, Map<String, dynamic> service) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth * 0.25;
        const summaryHeight = 238.0;
        const imageModuleHeight = summaryHeight - 12;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: summaryHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: imageWidth,
                  height: imageModuleHeight,
                  child: _buildImageUploader(
                    imageUrl: service['imageUrl']?.toString() ?? '',
                    title: '服务效果图',
                    emptyText: '尚未上传效果图',
                    uploadedText: '已上传效果图',
                    isUploading: _uploadingServiceIndex == index,
                    onUpload: () => _uploadServiceImage(index),
                    aspectRatio: 16 / 9,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: summaryHeight,
                    child: Column(
                      children: [
                        _buildTextField('套餐名称', service['name'], (value) {
                          service['name'] = value;
                        }),
                        Row(
                          children: [
                            Expanded(child: _buildServicePriceField(service)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildServiceDurationDropdown(service),
                            ),
                          ],
                        ),
                        Expanded(
                          child: _buildTextField(
                            '备注',
                            service['note'],
                            (value) {
                              service['note'] = value;
                            },
                            maxLines: null,
                            expands: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffSection() {
    return _buildSection(
      title: '理发师',
      icon: Icons.badge,
      trailing: IconButton(
        tooltip: '添加理发师',
        onPressed: _addStaff,
        icon: const Icon(Icons.add),
      ),
      children: [
        if (_staff.isEmpty)
          _buildEmptyHint('还没有理发师信息')
        else
          ..._staff.asMap().entries.map((entry) {
            final index = entry.key;
            final profile = entry.value;
            return _buildNestedCard(
              title: profile['name']?.toString().isNotEmpty == true
                  ? profile['name'].toString()
                  : '新理发师',
              headerActions: [
                IconButton(
                  tooltip: '上移',
                  onPressed: index == 0
                      ? null
                      : () => _moveStaff(index, index - 1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: '下移',
                  onPressed: index == _staff.length - 1
                      ? null
                      : () => _moveStaff(index, index + 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
              onDelete: () => setState(() => _staff.removeAt(index)),
              children: [
                _buildStaffSummaryRow(index, profile),
                _buildAbsenceScheduler(index, profile),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryPink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStaffSummaryRow(int index, Map<String, dynamic> profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth * 0.25;
        const summaryHeight = 238.0;
        const imageModuleHeight = summaryHeight - 12;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: summaryHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: imageWidth,
                  height: imageModuleHeight,
                  child: _buildAvatarUploader(index, profile),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: summaryHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField('姓名', profile['name'], (
                                value,
                              ) {
                                profile['name'] = value;
                              }),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStaffRoleDropdown(profile)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildExperienceDropdown(profile)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildExtraServiceFeeDropdown(profile),
                            ),
                          ],
                        ),
                        Expanded(
                          child: _buildTextField(
                            '个人简介',
                            profile['bio'],
                            (value) {
                              profile['bio'] = value;
                            },
                            maxLines: null,
                            expands: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarUploader(int index, Map<String, dynamic> profile) {
    final imageUrl = profile['imageUrl']?.toString() ?? '';
    final isUploading = _uploadingStaffIndex == index;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                color: AppTheme.bgCream,
                child: Center(
                  child: imageUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: AppTheme.primaryPink,
                          size: 40,
                        )
                      : Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 32,
                              ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: isUploading ? null : () => _uploadStaffAvatar(index),
              icon: isUploading
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload, size: 14),
              label: Text(isUploading ? '上传中' : '上传'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceScheduler(int index, Map<String, dynamic> profile) {
    final dates = _generateAbsenceDates();
    final selectedDate = _absenceDatesByStaffIndex[index] ?? dates.first;
    final openingRange = _openingHoursRange();
    final openingStart = _timeToMinutes(openingRange.start);
    final openingEnd = _timeToMinutes(openingRange.end);
    final businessTimeOptions = _generateTimeBoundaries().where((time) {
      final minutes = _timeToMinutes(time);
      return minutes >= openingStart && minutes <= openingEnd;
    }).toList();
    final startOptions = businessTimeOptions
        .take(businessTimeOptions.length - 1)
        .toList();
    final selectedStart = _absenceStartTimesByStaffIndex[index] ?? '13:00';
    final normalizedStart = startOptions.contains(selectedStart)
        ? selectedStart
        : startOptions.first;
    final endOptions = businessTimeOptions
        .where((time) => _timeToMinutes(time) > _timeToMinutes(normalizedStart))
        .toList();
    final selectedEnd = endOptions.contains(_absenceEndTimesByStaffIndex[index])
        ? _absenceEndTimesByStaffIndex[index]!
        : endOptions.first;
    final ranges = _unavailableRangesForDate(profile, selectedDate);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy, color: AppTheme.primaryPink),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '缺勤安排',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${ranges.length} 段缺勤',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: dates.map((date) {
                final selected =
                    _formatDateKey(date) == _formatDateKey(selectedDate);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      _formatAbsenceDateLabel(date),
                      textAlign: TextAlign.center,
                    ),
                    selected: selected,
                    selectedColor: AppTheme.primaryPink,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.textDark,
                      fontSize: 12,
                      height: 1.2,
                    ),
                    onSelected: (_) {
                      setState(() => _absenceDatesByStaffIndex[index] = date);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeDropdown(
                  label: '开始时间',
                  value: normalizedStart,
                  options: startOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    final nextEndOptions = businessTimeOptions
                        .where(
                          (time) =>
                              _timeToMinutes(time) > _timeToMinutes(value),
                        )
                        .toList();
                    setState(() {
                      _absenceStartTimesByStaffIndex[index] = value;
                      if (!nextEndOptions.contains(
                        _absenceEndTimesByStaffIndex[index],
                      )) {
                        _absenceEndTimesByStaffIndex[index] =
                            nextEndOptions.first;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimeDropdown(
                  label: '结束时间',
                  value: selectedEnd,
                  options: endOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _absenceEndTimesByStaffIndex[index] = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _addStaffUnavailableRange(
                      profile,
                      selectedDate,
                      selectedStart,
                      selectedEnd,
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ranges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '当天没有缺勤安排',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ranges.map((range) {
                return InputChip(
                  label: Text('${range.start}-${range.end}'),
                  selected: true,
                  selectedColor: Colors.orange.shade100,
                  deleteIconColor: Colors.orange.shade800,
                  labelStyle: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                  onDeleted: () {
                    _removeStaffUnavailableRange(
                      profile,
                      selectedDate,
                      range.start,
                      range.end,
                    );
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: options
          .map((time) => DropdownMenuItem(value: time, child: Text(time)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.accentBeige),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryPink),
        ),
      ),
    );
  }

  Widget _buildExtraServiceFeeDropdown(Map<String, dynamic> profile) {
    final value = _normalizeFee(profile['extraServiceFee']);
    profile['extraServiceFee'] = value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value == 0 ? '' : value.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (fee) {
          profile['extraServiceFee'] = _normalizeFee(fee);
        },
        decoration: InputDecoration(
          labelText: '额外服务费',
          prefixText: '¥ ',
          filled: true,
          fillColor: AppTheme.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accentBeige),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryPink),
          ),
        ),
      ),
    );
  }

  int _normalizeFee(dynamic value) {
    final digits = value?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    return int.tryParse(digits) ?? 0;
  }

  Widget _buildServicePriceField(Map<String, dynamic> service) {
    final price = _normalizePrice(service['price']);
    service['price'] = price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: price.replaceFirst('¥', ''),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          service['price'] = _normalizePrice(value);
        },
        decoration: InputDecoration(
          labelText: '价格',
          prefixText: '¥ ',
          filled: true,
          fillColor: AppTheme.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accentBeige),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryPink),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceDurationDropdown(Map<String, dynamic> service) {
    final value = _normalizeServiceDurationMinutes(service['duration']);
    service['duration'] = _formatServiceDuration(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        items: _serviceDurationOptions
            .map(
              (minutes) => DropdownMenuItem(
                value: minutes,
                child: Text(_formatServiceDuration(minutes)),
              ),
            )
            .toList(),
        onChanged: (minutes) {
          setState(() {
            service['duration'] = _formatServiceDuration(minutes ?? 30);
          });
        },
        decoration: _dropdownDecoration('时长'),
      ),
    );
  }

  String _normalizePrice(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? '¥' : '¥$digits';
  }

  int _normalizeServiceDurationMinutes(dynamic value) {
    final match = RegExp(r'\d+').firstMatch(value?.toString() ?? '');
    final raw = int.tryParse(match?.group(0) ?? '') ?? 30;
    final minutes = raw <= 3 ? raw * 60 : raw;
    final rounded = ((minutes / 30).round() * 30).clamp(30, 180);
    return _serviceDurationOptions.contains(rounded) ? rounded : 30;
  }

  String _formatServiceDuration(int minutes) {
    return '$minutes分钟';
  }

  Widget _buildStaffRoleDropdown(Map<String, dynamic> profile) {
    final currentRole = profile['role']?.toString() ?? '';
    final value = _staffRoleOptions.contains(currentRole)
        ? currentRole
        : _staffRoleOptions.first;
    profile['role'] = value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: _staffRoleOptions
            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
            .toList(),
        onChanged: (role) {
          setState(() => profile['role'] = role ?? _staffRoleOptions.first);
        },
        decoration: _dropdownDecoration('职位'),
      ),
    );
  }

  Widget _buildExperienceDropdown(Map<String, dynamic> profile) {
    final value = _normalizeExperienceYear(profile['experience']);
    profile['experience'] = '$value年';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        items: _experienceYearOptions
            .map((year) => DropdownMenuItem(value: year, child: Text('$year年')))
            .toList(),
        onChanged: (year) {
          setState(() => profile['experience'] = '${year ?? 1}年');
        },
        decoration: _dropdownDecoration('经验'),
      ),
    );
  }

  int _normalizeExperienceYear(dynamic value) {
    final match = RegExp(r'\d+').firstMatch(value?.toString() ?? '');
    final year = int.tryParse(match?.group(0) ?? '') ?? 1;
    return year.clamp(1, 30);
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.accentBeige),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryPink),
      ),
    );
  }

  Widget _buildCoverImagesUploader() {
    return Column(
      children: [
        _buildImageUploader(
          imageUrl: _coverImage(),
          title: '封面图',
          emptyText: '尚未上传封面图，为了更好的展示效果请上传16:9的图片',
          uploadedText: '已上传封面图，为了更好的展示效果请上传16:9的图片',
          isUploading: _isUploadingCover,
          onUpload: _uploadCoverImage,
          aspectRatio: 16 / 9,
        ),
        _buildPromoImagesUploader(),
      ],
    );
  }

  Widget _buildPromoImagesUploader() {
    final images = _promoImages();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '推广图',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      images.isEmpty
                          ? '尚未上传推广图，为了更好的展示效果请上传16:9的图片'
                          : '已上传 ${images.length}/20 张推广图，为了更好的展示效果请上传16:9的图片',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isUploadingCover || images.length >= 20
                    ? null
                    : _uploadPromoImages,
                icon: _isUploadingCover
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploadingCover ? '上传中' : '上传图片'),
              ),
            ],
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: images.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final nextImages = [...images];
                    final image = nextImages.removeAt(oldIndex);
                    nextImages.insert(newIndex, image);
                    _setPromoImages(nextImages);
                  });
                },
                itemBuilder: (context, index) {
                  final imageUrl = images[index];
                  return Padding(
                    key: ValueKey(imageUrl),
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 92,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: AppTheme.bgCream,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      final nextImages = [...images]
                                        ..removeAt(index);
                                      _setPromoImages(nextImages);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '推广图 ${index + 1}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageUploader({
    required String imageUrl,
    required String title,
    required String emptyText,
    required String uploadedText,
    required bool isUploading,
    required VoidCallback onUpload,
    required double aspectRatio,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                width: double.infinity,
                color: AppTheme.bgCream,
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.image,
                        color: AppTheme.primaryPink,
                        size: 64,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 48,
                            ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imageUrl.isEmpty ? emptyText : uploadedText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: isUploading ? null : onUpload,
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: const Text('上传'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNestedCard({
    required String title,
    required VoidCallback onDelete,
    required List<Widget> children,
    List<Widget> headerActions = const [],
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...headerActions,
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.redAccent,
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    dynamic value,
    ValueChanged<String> onChanged, {
    int? maxLines = 1,
    bool expands = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        maxLines: maxLines,
        expands: expands,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppTheme.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accentBeige),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryPink),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey[600])),
    );
  }
}
