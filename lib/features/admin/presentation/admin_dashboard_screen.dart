import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';
import 'pages/admin_ad_page.dart';
import 'pages/admin_complaints_page.dart';
import 'pages/admin_coupon_campaign_page.dart';
import 'pages/admin_merchants_page.dart';
import 'pages/admin_overview_page.dart';
import 'pages/admin_reviews_page.dart';
import 'pages/admin_salon_posts_page.dart';
import 'pages/admin_service_promotions_page.dart';
import 'pages/admin_support_messages_page.dart';
import 'pages/admin_users_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onLogout,
    this.repository,
  });
  final VoidCallback onLogout;
  final AdminRepository? repository;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AdminRepository _repository;
  late final TabController _tabs;
  final _refreshVersions = List.filled(10, 0);
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminRepository();
    _tabs = TabController(length: 10, vsync: this);
    _tabs.addListener(_selectTab);
  }

  void _selectTab() {
    if (_selected == _tabs.index) return;
    setState(() => _selected = _tabs.index);
  }

  void _invalidateOtherPages(int source) {
    // Refresh pages that consume the same mutated records when next opened.
    final dependents = switch (source) {
      1 => [0, 5], // Merchant accounts and service promotions share merchants.
      2 => [0, 6], // Complaints include user information.
      3 => [6], // Reviews and complaints share user images.
      5 => [1],
      _ => const <int>[],
    };
    setState(() {
      for (final i in dependents) {
        _refreshVersions[i]++;
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bgCream,
    appBar: AppBar(
      title: const Text('后台管理'),
      backgroundColor: AppTheme.white,
      foregroundColor: AppTheme.textDark,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _refreshVersions[_selected]++),
        ),
        IconButton(
          tooltip: '退出',
          icon: const Icon(Icons.logout),
          onPressed: widget.onLogout,
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined), text: '概览'),
          Tab(icon: Icon(Icons.storefront_outlined), text: '商家账号'),
          Tab(icon: Icon(Icons.people_outline), text: '客户端用户'),
          Tab(icon: Icon(Icons.rate_review_outlined), text: '评论管理'),
          Tab(icon: Icon(Icons.dynamic_feed_outlined), text: '动态审核'),
          Tab(icon: Icon(Icons.auto_awesome_outlined), text: '套餐推广'),
          Tab(icon: Icon(Icons.report_outlined), text: '投诉管理'),
          Tab(icon: Icon(Icons.support_agent_outlined), text: '客服消息'),
          Tab(icon: Icon(Icons.campaign_outlined), text: '广告位'),
          Tab(icon: Icon(Icons.local_activity_outlined), text: '活动管理'),
        ],
      ),
    ),

    body: IndexedStack(
      index: _selected,
      children:
          [
                AdminOverviewPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 0,
                  refreshVersion: _refreshVersions[0],
                  onChanged: () => _invalidateOtherPages(0),
                ),
                AdminMerchantsPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 1,
                  refreshVersion: _refreshVersions[1],
                  onChanged: () => _invalidateOtherPages(1),
                ),
                AdminUsersPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 2,
                  refreshVersion: _refreshVersions[2],
                  onChanged: () => _invalidateOtherPages(2),
                ),
                AdminReviewsPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 3,
                  refreshVersion: _refreshVersions[3],
                  onChanged: () => _invalidateOtherPages(3),
                ),
                AdminSalonPostsPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 4,
                  refreshVersion: _refreshVersions[4],
                  onChanged: () => _invalidateOtherPages(4),
                ),
                AdminServicePromotionsPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 5,
                  refreshVersion: _refreshVersions[5],
                  onChanged: () => _invalidateOtherPages(5),
                ),
                AdminComplaintsPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 6,
                  refreshVersion: _refreshVersions[6],
                  onChanged: () => _invalidateOtherPages(6),
                ),
                AdminSupportMessagesPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 7,
                  refreshVersion: _refreshVersions[7],
                  onChanged: () => _invalidateOtherPages(7),
                ),
                AdminAdPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 8,
                  refreshVersion: _refreshVersions[8],
                  onChanged: () => _invalidateOtherPages(8),
                ),
                AdminCouponCampaignPage(
                  repository: _repository,
                  onLogout: widget.onLogout,
                  active: _selected == 9,
                  refreshVersion: _refreshVersions[9],
                  onChanged: () => _invalidateOtherPages(9),
                ),
              ]
              .asMap()
              .entries
              .map(
                (entry) => TickerMode(
                  enabled: entry.key == _selected,
                  child: entry.value,
                ),
              )
              .toList(),
    ),
  );
}
