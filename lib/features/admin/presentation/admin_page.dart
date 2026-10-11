import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';

/// Common lifecycle for the ten independently loaded admin pages.
abstract class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.repository,
    required this.onLogout,
    required this.active,
    required this.refreshVersion,
    required this.onChanged,
  });

  final AdminRepository repository;
  final VoidCallback onLogout;
  final bool active;
  final int refreshVersion;
  final VoidCallback onChanged;
}

abstract class AdminPageState<P extends AdminPage, T> extends State<P> {
  T? data;
  Object? _error;
  bool _loading = false;
  int _request = 0;
  int? _loadedVersion;
  int? _loadingVersion;

  AdminRepository get repository => widget.repository;
  Future<T> loadData();
  Widget buildContent(BuildContext context);

  @override
  void initState() {
    super.initState();
    if (widget.active) reload();
  }

  @override
  void didUpdateWidget(covariant P oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.refreshVersion != widget.refreshVersion) &&
        (_loadedVersion != widget.refreshVersion || data == null) &&
        (!_loading || _loadingVersion != widget.refreshVersion)) {
      reload();
    }
  }

  Future<void> reload() async {
    final request = ++_request;
    final version = widget.refreshVersion;
    _loadingVersion = version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await loadData();
      if (!mounted || request != _request) return;
      setState(() {
        data = result;
        _loadedVersion = version;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      if (isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() => _error = error);
      if (data != null) showError(error, fallback: '刷新失败，请重试');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> refreshAfterMutation() async {
    if (!mounted) return;
    widget.onChanged();
    await reload();
  }

  void updateData(T saved) {
    if (!mounted) return;
    // A completed save supersedes any earlier refresh still in flight.
    _request++;
    setState(() {
      data = saved;
      _loading = false;
      _error = null;
      _loadedVersion = widget.refreshVersion;
    });
  }

  bool isUnauthorized(Object error) =>
      error is DioException && error.response?.statusCode == 401;

  void showError(Object error, {String? fallback}) {
    if (!mounted) return;
    if (isUnauthorized(error)) {
      widget.onLogout();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userFacingApiError(error, fallback: fallback ?? '保存失败，请检查填写内容后重试'),
        ),
      ),
    );
  }

  Future<String> rejectReason(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '驳回原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      if (_error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userFacingApiError(_error!, fallback: '加载失败，请重试')),
              const SizedBox(height: 12),
              FilledButton(onPressed: reload, child: const Text('重新加载')),
            ],
          ),
        );
      }
      if (!_loading) return const SizedBox.shrink();
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPink),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: buildContent(context)),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(color: AppTheme.primaryPink),
          ),
      ],
    );
  }
}
