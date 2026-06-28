import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/merchant_auth_repository.dart';
import '../data/merchant_session_store.dart';

class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({
    super.key,
    required this.repository,
    required this.onLoggedIn,
  });

  final MerchantAuthRepository repository;
  final ValueChanged<MerchantSession> onLoggedIn;

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'merchant');
  final _passwordController = TextEditingController(text: '123456');

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isAdminLogin = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final session = await widget.repository.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        admin: _isAdminLogin,
      );
      if (!mounted) return;
      widget.onLoggedIn(session);
    } on DioException catch (e) {
      if (!mounted) return;
      final statusCode = e.response?.statusCode;
      setState(() {
        _errorMessage = statusCode == 401 || statusCode == 403
            ? '账号或密码错误'
            : '无法连接服务器，请检查网络或接口地址';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '登录失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentBeige),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront,
                      color: AppTheme.primaryPink,
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '商家登录',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '登录后管理店铺信息、理发师和订单',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.storefront_outlined),
                          label: Text('商家'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.admin_panel_settings_outlined),
                          label: Text('后台'),
                        ),
                      ],
                      selected: {_isAdminLogin},
                      onSelectionChanged: (selection) {
                        final isAdmin = selection.first;
                        setState(() {
                          _isAdminLogin = isAdmin;
                          _usernameController.text = isAdmin
                              ? 'admin'
                              : 'merchant';
                          _passwordController.text = isAdmin
                              ? 'admin123456'
                              : '123456';
                          _errorMessage = '';
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: '账号',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入账号';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _inputDecoration(
                        label: '密码',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请输入密码';
                        return null;
                      },
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: const Text('登录'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
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
}
