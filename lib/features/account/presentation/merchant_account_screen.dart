import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/merchant_session_store.dart';
import '../../merchant/data/image_upload_picker.dart';
import '../data/merchant_account_repository.dart';

class MerchantAccountScreen extends StatefulWidget {
  const MerchantAccountScreen({
    super.key,
    required this.session,
    required this.onSessionChanged,
  });

  final MerchantSession session;
  final ValueChanged<MerchantSession> onSessionChanged;

  @override
  State<MerchantAccountScreen> createState() => _MerchantAccountScreenState();
}

class _MerchantAccountScreenState extends State<MerchantAccountScreen> {
  final MerchantAccountRepository _repository = MerchantAccountRepository();
  final _displayNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _isUploadingLicense = false;
  bool _isLoadingQualification = true;
  bool _changePassword = false;
  Map<String, dynamic> _qualification = {};
  String _licenseUrl = '';

  @override
  void initState() {
    super.initState();
    _displayNameController.text =
        widget.session.user['displayName']?.toString() ?? '';
    _loadQualification();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_changePassword &&
        _newPasswordController.text != _confirmPasswordController.text) {
      _showMessage('两次新密码不一致');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final session = await _repository.updateAccount(
        displayName: _displayNameController.text.trim(),
        currentPassword: _changePassword ? _currentPasswordController.text : '',
        newPassword: _changePassword ? _newPasswordController.text : '',
      );
      if (!mounted) return;
      widget.onSessionChanged(session);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _changePassword = false);
      _showMessage('账号信息已保存');
    } catch (_) {
      if (!mounted) return;
      _showMessage('保存失败，请检查当前密码');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadQualification() async {
    try {
      final qualification = await _repository.fetchQualification();
      if (!mounted) return;
      setState(() {
        _qualification = qualification;
        _licenseUrl = qualification['licenseUrl']?.toString() ?? '';
        _isLoadingQualification = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingQualification = false);
    }
  }

  Future<void> _pickAndUploadLicense() async {
    final pickedImage = await pickImageForUpload();
    if (pickedImage == null) return;

    setState(() => _isUploadingLicense = true);
    try {
      final url = await _repository.uploadLicenseImage(
        fileName: pickedImage.fileName,
        base64Data: pickedImage.base64Data,
      );
      if (!mounted) return;
      setState(() => _licenseUrl = url);
    } catch (_) {
      if (!mounted) return;
      _showMessage('营业执照上传失败');
    } finally {
      if (mounted) setState(() => _isUploadingLicense = false);
    }
  }

  Future<void> _submitQualification() async {
    if (_licenseUrl.isEmpty) {
      _showMessage('请先上传营业执照');
      return;
    }
    setState(() => _isUploadingLicense = true);
    try {
      final qualification = await _repository.submitQualification(_licenseUrl);
      if (!mounted) return;
      setState(() => _qualification = qualification);
      _showMessage('营业执照已提交后台审核');
    } catch (_) {
      if (!mounted) return;
      _showMessage('提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isUploadingLicense = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: const Text('账号管理'),
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoPanel(user: user),
                const SizedBox(height: 16),
                _buildQualificationPanel(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '基础信息',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: '显示名称',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: _changePassword,
                        onChanged: (value) =>
                            setState(() => _changePassword = value),
                        title: const Text('修改登录密码'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_changePassword) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '当前密码',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '新密码',
                            prefixIcon: Icon(Icons.password_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '确认新密码',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('保存账号信息'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.accentBeige),
    );
  }

  Widget _buildQualificationPanel() {
    final status = _qualification['licenseStatus']?.toString() ?? 'unsubmitted';
    final publishStatus =
        _qualification['publishStatus']?.toString() ?? 'offline';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: _isLoadingQualification
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppTheme.primaryPink),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '资质认证',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    _StatusChip(label: _licenseStatusLabel(status)),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: publishStatus == 'online' ? '已上架' : '未上架',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 220,
                    color: AppTheme.bgCream,
                    child: _licenseUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.assignment_outlined,
                              size: 54,
                              color: AppTheme.textDark,
                            ),
                          )
                        : Image.network(
                            _licenseUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(child: Icon(Icons.broken_image)),
                          ),
                  ),
                ),
                if (status == 'rejected' &&
                    (_qualification['licenseRejectReason']?.toString() ?? '')
                        .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '驳回原因：${_qualification['licenseRejectReason']}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isUploadingLicense
                          ? null
                          : _pickAndUploadLicense,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(_licenseUrl.isEmpty ? '上传营业执照' : '重新上传'),
                    ),
                    FilledButton.icon(
                      onPressed: _isUploadingLicense
                          ? null
                          : _submitQualification,
                      icon: _isUploadingLicense
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fact_check_outlined),
                      label: const Text('提交审核'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _licenseStatusLabel(String status) {
    return switch (status) {
      'pending' => '待审核',
      'approved' => '审核通过',
      'rejected' => '审核驳回',
      _ => '未提交',
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryPink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textDark,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryPink,
            child: Icon(Icons.storefront, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['displayName']?.toString() ?? '商家账号',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '账号：${user['username'] ?? '-'}  店铺ID：${user['salonId'] ?? '-'}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
