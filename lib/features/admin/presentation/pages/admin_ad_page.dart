import 'package:flutter/material.dart';

import '../../../../core/image/image_upload_picker.dart';
import '../../../../core/network/api_client.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminAdPage extends AdminPage {
  const AdminAdPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminAdPage> createState() => _AdminAdPageState();
}

class _AdminAdPageState
    extends AdminPageState<AdminAdPage, Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> loadData() async {
    return repository.fetchAd();
  }

  @override
  Widget buildContent(BuildContext context) =>
      _AdTab(config: data!, onSave: _saveAd);

  Future<Map<String, dynamic>> _saveAd({
    required String imageUrl,
    required String link,
    required bool enabled,
    PickedImage? image,
  }) async {
    try {
      final saved = await repository.saveAd(
        imageUrl: imageUrl,
        link: link,
        enabled: enabled,
        fileName: image?.fileName,
        base64Data: image?.base64Data,
      );
      updateData(saved);
      return saved;
    } catch (error) {
      if (mounted && isUnauthorized(error)) widget.onLogout();
      rethrow;
    }
  }
}

class _AdTab extends StatefulWidget {
  const _AdTab({required this.config, required this.onSave});

  final Map<String, dynamic> config;
  final _SaveAd onSave;

  @override
  State<_AdTab> createState() => _AdTabState();
}

class _AdTabState extends State<_AdTab> {
  late final TextEditingController _linkController;
  PickedImage? _image;
  late String _imageUrl;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.config['imageUrl']?.toString() ?? '';
    _enabled = widget.config['enabled'] != false;
    _linkController = TextEditingController(
      text: widget.config['link']?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _AdTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config == widget.config) return;
    _imageUrl = widget.config['imageUrl']?.toString() ?? '';
    _enabled = widget.config['enabled'] != false;
    _linkController.text = widget.config['link']?.toString() ?? '';
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await pickImageForUpload();
      if (image != null && mounted) setState(() => _image = image);
    } catch (error) {
      if (mounted) _showMessage('$error');
    }
  }

  Future<void> _save() async {
    final link = _linkController.text.trim();
    final uri = Uri.tryParse(link);
    final isHttps =
        uri?.scheme == 'https' &&
        uri?.host.isNotEmpty == true &&
        uri?.userInfo.isEmpty == true;
    if (!link.startsWith('/pages/') && !isHttps) {
      _showMessage('请输入 HTTPS H5 地址或 /pages/... 小程序页面路径');
      return;
    }
    if (_enabled && _image == null && _imageUrl.isEmpty) {
      _showMessage('请先上传广告图片');
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(
        imageUrl: _imageUrl,
        link: link,
        enabled: _enabled,
        image: _image,
      );
      if (!mounted) return;
      setState(() {
        _image = null;
        _imageUrl = saved['imageUrl']?.toString() ?? '';
      });
      _showMessage('广告位已保存');
    } catch (error) {
      if (!mounted) return;
      _showMessage(userFacingApiError(error, fallback: '广告保存失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: adminPanelDecoration(),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('顶部广告位', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('用于小程序首页和店铺详情页，建议上传约 5:1 的横幅图片。'),
                  const SizedBox(height: 20),
                  if (_imageUrl.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 5,
                      child: Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    ),
                  if (_imageUrl.isNotEmpty) const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.upload_outlined),
                    label: Text(_image == null ? '选择广告图片' : '重新选择图片'),
                  ),
                  if (_image != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${_image!.fileName} · ${_image!.width}×${_image!.height}',
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _linkController,
                    decoration: const InputDecoration(
                      labelText: '点击后跳转链接',
                      hintText: 'https://media.hothaircc.cn/ad/index.html',
                      helperText: '填写 HTTPS H5 地址；旧版小程序内部路径仍兼容',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示广告位'),
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _enabled = value),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? '保存中...' : '保存广告位'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _SaveAd =
    Future<Map<String, dynamic>> Function({
      required String imageUrl,
      required String link,
      required bool enabled,
      PickedImage? image,
    });
