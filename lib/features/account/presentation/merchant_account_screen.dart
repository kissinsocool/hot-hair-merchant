import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_width.dart';
import '../../auth/data/merchant_session_store.dart';
import '../../merchant/data/image_upload_picker.dart';
import '../data/merchant_account_repository.dart';

class MerchantAccountScreen extends StatefulWidget {
  const MerchantAccountScreen({
    super.key,
    required this.session,
    required this.onSessionChanged,
    this.repository,
  });

  final MerchantSession session;
  final ValueChanged<MerchantSession> onSessionChanged;
  final MerchantAccountRepository? repository;

  @override
  State<MerchantAccountScreen> createState() => _MerchantAccountScreenState();
}

class _MerchantAccountScreenState extends State<MerchantAccountScreen> {
  late final MerchantAccountRepository _repository =
      widget.repository ?? MerchantAccountRepository();
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
  String _licenseFileName = '';
  String _licenseBase64Data = '';

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

  Future<void> _pickDocument(
    String label,
    void Function(PickedImage image) onPicked,
  ) async {
    PickedImage? pickedImage;
    try {
      pickedImage = await pickImageForUpload();
    } catch (e) {
      if (!mounted) return;
      _showMessage('$e');
      return;
    }
    if (pickedImage == null) return;
    final selectedImage = pickedImage;

    setState(() => _isUploadingLicense = true);
    try {
      if (!mounted) return;
      setState(() {
        onPicked(selectedImage);
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('$label上传失败');
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
      final qualification = await _repository.submitQualification(
        licenseUrl: _licenseUrl,
        fileName: _licenseFileName,
        base64Data: _licenseBase64Data,
      );
      if (!mounted) return;
      setState(() {
        _qualification = qualification;
        _licenseUrl = qualification['licenseUrl']?.toString() ?? _licenseUrl;
        _licenseFileName = '';
        _licenseBase64Data = '';
      });
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
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: PageWidth(
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
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        value: _changePassword,
                        onChanged: (value) =>
                            setState(() => _changePassword = value),
                        title: const Text('修改登录密码'),
                        contentPadding: EdgeInsets.zero,
                      ),
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
                _DocumentUploadCard(
                  title: '营业执照',
                  hint: '请上传清晰、完整的营业执照图片',
                  imageUrl: _licenseUrl,
                  icon: Icons.assignment_outlined,
                  isUploading: _isUploadingLicense,
                  onUpload: () => _pickDocument('营业执照', (image) {
                    _licenseUrl = image.base64Data;
                    _licenseFileName = image.fileName;
                    _licenseBase64Data = image.base64Data;
                  }),
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
                FilledButton.icon(
                  onPressed: _isUploadingLicense ? null : _submitQualification,
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
                  label: const Text('提交营业执照审核'),
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

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.title,
    required this.hint,
    required this.imageUrl,
    required this.icon,
    required this.isUploading,
    required this.onUpload,
  });

  final String title;
  final String hint;
  final String imageUrl;
  final IconData icon;
  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 160,
              color: AppTheme.white,
              child: imageUrl.isEmpty
                  ? Center(
                      child: Icon(icon, size: 48, color: AppTheme.textDark),
                    )
                  : imageUrl.startsWith('data:')
                  ? Image.memory(
                      base64Decode(imageUrl.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isUploading ? null : onUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(imageUrl.isEmpty ? '上传$title' : '重新上传'),
          ),
        ],
      ),
    );
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
