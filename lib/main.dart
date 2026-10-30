import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/account/presentation/merchant_account_screen.dart';
import 'features/auth/data/merchant_session_store.dart';
import 'features/auth/presentation/portal_auth_gate.dart';
import 'features/booking/data/order_repository.dart';
import 'features/merchant/data/merchant_salon_repository.dart';
import 'features/merchant/presentation/merchant_orders_screen.dart';
import 'features/merchant/presentation/merchant_salon_screen.dart';

void main() {
  runApp(const MerchantApp());
}

class MerchantApp extends StatelessWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hot Pepper Merchant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(0.9375)),
        child: child!,
      ),
      home: PortalAuthGate(
        role: PortalRole.merchant,
        homeBuilder: (session, onLogout, onSessionChanged) => MerchantHomeShell(
          session: session,
          onLogout: onLogout,
          onSessionChanged: onSessionChanged,
        ),
      ),
    );
  }
}

class MerchantHomeShell extends StatefulWidget {
  const MerchantHomeShell({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionChanged,
    this.orderRepository,
    this.salonRepository,
    this.enableRealtime = const bool.fromEnvironment(
      'ENABLE_REALTIME',
      defaultValue: true,
    ),
  });

  final MerchantSession session;
  final VoidCallback onLogout;
  final ValueChanged<MerchantSession> onSessionChanged;
  final OrderRepository? orderRepository;
  final MerchantSalonRepository? salonRepository;
  final bool enableRealtime;

  @override
  State<MerchantHomeShell> createState() => _MerchantHomeShellState();
}

class _MerchantHomeShellState extends State<MerchantHomeShell> {
  int _selectedIndex = 0;
  int _pendingOrderCount = 0;

  void _updatePendingOrderCount(int count) {
    if (!mounted || count == _pendingOrderCount) return;
    setState(() => _pendingOrderCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      MerchantSalonScreen(
        repository: widget.salonRepository,
        enableRealtime: widget.enableRealtime,
      ),
      MerchantOrdersScreen(
        onPendingOrderCountChanged: _updatePendingOrderCount,
        repository: widget.orderRepository,
        salonRepository: widget.salonRepository,
        enableRealtime: widget.enableRealtime,
      ),
      MerchantAccountScreen(
        session: widget.session,
        onSessionChanged: widget.onSessionChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '店铺',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: _pendingOrderCount,
              isLabelVisible: _pendingOrderCount > 0,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge.count(
              count: _pendingOrderCount,
              isLabelVisible: _pendingOrderCount > 0,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.receipt_long),
            ),
            label: '订单',
          ),
          const NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: '账号',
          ),
          const NavigationDestination(
            icon: Icon(Icons.logout),
            selectedIcon: Icon(Icons.logout),
            label: '退出',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 3) {
            widget.onLogout();
            return;
          }
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
