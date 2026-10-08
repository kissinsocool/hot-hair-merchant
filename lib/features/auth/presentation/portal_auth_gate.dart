import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/merchant_auth_repository.dart';
import '../data/merchant_session_store.dart';
import 'merchant_login_screen.dart';

class PortalAuthGate extends StatefulWidget {
  const PortalAuthGate({
    super.key,
    required this.role,
    required this.homeBuilder,
  });

  final PortalRole role;
  final Widget Function(
    MerchantSession session,
    VoidCallback onLogout,
    ValueChanged<MerchantSession> onSessionChanged,
  )
  homeBuilder;

  @override
  State<PortalAuthGate> createState() => _PortalAuthGateState();
}

class _PortalAuthGateState extends State<PortalAuthGate> {
  late final MerchantAuthRepository _repository;
  bool _isLoading = true;
  MerchantSession? _session;

  @override
  void initState() {
    super.initState();
    _repository = MerchantAuthRepository(role: widget.role);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    var session = await _repository.restoreSession();
    if (session != null &&
        (session.user['role'] == 'admin') !=
            (widget.role == PortalRole.admin)) {
      await _repository.logout();
      session = null;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _repository.logout();
    if (mounted) setState(() => _session = null);
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
        role: widget.role,
        onLoggedIn: (session) => setState(() => _session = session),
      );
    }
    return widget.homeBuilder(
      _session!,
      _logout,
      (session) => setState(() => _session = session),
    );
  }
}
