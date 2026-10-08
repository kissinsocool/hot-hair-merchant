import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/auth/data/merchant_session_store.dart';
import 'features/auth/presentation/portal_auth_gate.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hot Pepper Admin',
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
        role: PortalRole.admin,
        homeBuilder: (_, onLogout, _) =>
            AdminDashboardScreen(onLogout: onLogout),
      ),
    );
  }
}
