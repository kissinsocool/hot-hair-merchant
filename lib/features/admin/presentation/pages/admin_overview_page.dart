import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking_order.dart';
import '../admin_orders_summary_screen.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminOverviewPage extends AdminPage {
  const AdminOverviewPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState
    extends AdminPageState<AdminOverviewPage, Map<String, dynamic>> {
  Timer? _refreshTimer;
  bool _openingNewOrders = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!widget.active ||
          _openingNewOrders ||
          _polling ||
          data == null ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _polling = true;
      try {
        await reload();
      } finally {
        _polling = false;
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Future<Map<String, dynamic>> loadData() async {
    return repository.fetchOverview();
  }

  @override
  Widget buildContent(BuildContext context) => _OverviewTab(
    overview: data!,
    onViewOrders: _showOrders,
    onViewNewOrders:
        !_openingNewOrders && data!['bookingsSnapshotBefore'] is String
        ? _showNewOrders
        : null,
  );

  Future<void> _showNewOrders() async {
    if (_openingNewOrders) return;
    setState(() => _openingNewOrders = true);
    try {
      final overview = await repository.fetchOverview();
      if (!mounted) return;
      updateData(overview);
      final before = overview['bookingsSnapshotBefore'] as String;
      final results = await Future.wait([
        repository.fetchNewBookings(before),
        repository.fetchMerchants(),
        repository.fetchUsers(),
      ]);
      if (!mounted) return;
      Future<void>? viewed;
      final route = MaterialPageRoute<void>(
        builder: (_) => AdminOrdersSummaryScreen(
          title: '今日新预约订单',
          orders: results[0] as List<BookingOrder>,
          merchants: results[1] as List<Map<String, dynamic>>,
          users: results[2] as List<Map<String, dynamic>>,
        ),
      );
      final closed = Navigator.of(context).push(route);
      void markWhenVisible(AnimationStatus status) {
        if (status == AnimationStatus.completed &&
            viewed == null &&
            mounted &&
            route.isCurrent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && route.isCurrent && viewed == null) {
              viewed = _markNewBookingsViewed(before);
            }
          });
        }
      }

      final animation = route.animation!;
      animation.addStatusListener(markWhenVisible);
      if (animation.isCompleted) {
        markWhenVisible(AnimationStatus.completed);
      }
      await closed;
      animation.removeStatusListener(markWhenVisible);
      await viewed;
      if (mounted) await reload();
    } catch (error) {
      showError(error, fallback: '今日新订单加载失败，请重试');
    } finally {
      if (mounted) setState(() => _openingNewOrders = false);
    }
  }

  Future<void> _markNewBookingsViewed(String before) async {
    try {
      await repository.markNewBookingsViewed(before);
    } catch (error) {
      showError(error, fallback: '已查看状态保存失败，请稍后重试');
    }
  }

  Future<void> _showOrders() async {
    try {
      final results = await Future.wait([
        repository.fetchBookings(),
        repository.fetchMerchants(),
        repository.fetchUsers(),
      ]);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminOrdersSummaryScreen(
            orders: results[0] as List<BookingOrder>,
            merchants: results[1] as List<Map<String, dynamic>>,
            users: results[2] as List<Map<String, dynamic>>,
          ),
        ),
      );
    } catch (error) {
      showError(error);
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.overview,
    required this.onViewOrders,
    required this.onViewNewOrders,
  });

  final Map<String, dynamic> overview;
  final VoidCallback onViewOrders;
  final VoidCallback? onViewNewOrders;

  @override
  Widget build(BuildContext context) {
    final funnel = Map<String, dynamic>.from(overview['funnel'] as Map? ?? {});
    final counts = Map<String, dynamic>.from(funnel['counts'] as Map? ?? {});
    final items = [
      ('今日新订单', overview['todayBookingCount'], ''),
      (
        '昨日门店点击',
        counts['salon_detail_click'],
        '转化率 ${funnel['salonDetailClickRate'] ?? 0}%',
      ),
      (
        '昨日首页曝光',
        counts['home_exposure'],
        '昨日新增用户 ${overview['yesterdayNewClientCount'] ?? 0}',
      ),
      (
        '昨日提交预约',
        counts['booking_submitted'],
        '转化率 ${funnel['bookingSubmissionRate'] ?? 0}%',
      ),
      ('昨日开始预约', counts['booking_started'], ''),
      ('商家账号', overview['merchantCount'], ''),
      ('客户端用户', overview['clientCount'], ''),
      ('店铺数量', overview['salonCount'], ''),
      ('全部订单', overview['bookingCount'], ''),
      ('待处理订单', overview['pendingCount'], ''),
      ('预约成功订单', overview['acceptedCount'], ''),
    ];

    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: MediaQuery.of(context).size.width > 760 ? 3 : 2,
      childAspectRatio: 1.8,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        for (final item in items)
          InkWell(
            onTap: switch (item.$1) {
              '全部订单' => onViewOrders,
              '今日新订单' => onViewNewOrders,
              _ => null,
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: adminPanelDecoration(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.$1, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text(
                        '${item.$2 ?? 0}',
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.$3.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                  if (item.$1 == '今日新订单' &&
                      (overview['unviewedBookingCount'] as num? ?? 0) > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Semantics(
                        label: '${overview['unviewedBookingCount']}个未查看的新订单',
                        child: Badge.count(
                          count: (overview['unviewedBookingCount'] as num)
                              .toInt(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
