import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/account/presentation/merchant_account_screen.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/auth/data/merchant_auth_repository.dart';
import 'features/auth/data/merchant_session_store.dart';
import 'features/auth/presentation/merchant_login_screen.dart';
import 'features/booking/data/booking_update_stream.dart';
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
      home: const MerchantAuthGate(),
    );
  }
}

class MerchantAuthGate extends StatefulWidget {
  const MerchantAuthGate({super.key});

  @override
  State<MerchantAuthGate> createState() => _MerchantAuthGateState();
}

class _MerchantAuthGateState extends State<MerchantAuthGate> {
  final MerchantAuthRepository _repository = MerchantAuthRepository();

  bool _isLoading = true;
  MerchantSession? _session;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _repository.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _repository.logout();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgCream,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryPink),
        ),
      );
    }

    if (_session == null) {
      return MerchantLoginScreen(
        repository: _repository,
        onLoggedIn: (session) => setState(() => _session = session),
      );
    }

    if (_session!.user['role'] == 'admin') {
      return AdminDashboardScreen(onLogout: _logout);
    }

    return MerchantHomeShell(
      session: _session!,
      onLogout: _logout,
      onSessionChanged: (session) => setState(() => _session = session),
    );
  }
}

class MerchantHomeShell extends StatefulWidget {
  const MerchantHomeShell({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionChanged,
  });

  final MerchantSession session;
  final VoidCallback onLogout;
  final ValueChanged<MerchantSession> onSessionChanged;

  @override
  State<MerchantHomeShell> createState() => _MerchantHomeShellState();
}

class _MerchantHomeShellState extends State<MerchantHomeShell> {
  int _selectedIndex = 0;
  bool _hasNewOrder = false;
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;

  @override
  void initState() {
    super.initState();
    BookingUpdateStream.instance.start();
    _bookingUpdateSubscription = BookingUpdateStream.instance.stream.listen((
      event,
    ) {
      if (event['event'] != 'booking.created') return;
      if (_selectedIndex == 1) return;
      if (mounted) setState(() => _hasNewOrder = true);
    });
  }

  @override
  void dispose() {
    _bookingUpdateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const MerchantSalonScreen(),
      const MerchantOrdersScreen(),
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
            icon: _NavIconWithDot(
              icon: Icons.receipt_long_outlined,
              showDot: _hasNewOrder,
            ),
            selectedIcon: const Icon(Icons.receipt_long),
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
            if (index == 1) _hasNewOrder = false;
          });
        },
      ),
    );
  }
}

class _NavIconWithDot extends StatelessWidget {
  const _NavIconWithDot({required this.icon, required this.showDot});

  final IconData icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showDot)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
