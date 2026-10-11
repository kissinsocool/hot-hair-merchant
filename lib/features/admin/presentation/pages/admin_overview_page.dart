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
  @override
  Future<Map<String, dynamic>> loadData() async {
    return repository.fetchOverview();
  }

  @override
  Widget buildContent(BuildContext context) =>
      _OverviewTab(overview: data!, onViewOrders: _showOrders);

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
  const _OverviewTab({required this.overview, required this.onViewOrders});

  final Map<String, dynamic> overview;
  final VoidCallback onViewOrders;

  @override
  Widget build(BuildContext context) {
    final funnel = Map<String, dynamic>.from(overview['funnel'] as Map? ?? {});
    final counts = Map<String, dynamic>.from(funnel['counts'] as Map? ?? {});
    final items = [
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
            onTap: item.$1 == '全部订单' ? onViewOrders : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: adminPanelDecoration(),
              child: Column(
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
                    Text(item.$3, style: TextStyle(color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
