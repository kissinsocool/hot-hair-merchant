import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/order_repository.dart';
import '../../booking/domain/booking_order.dart';

class MerchantOrderAppealDialog extends StatefulWidget {
  const MerchantOrderAppealDialog({
    super.key,
    required this.order,
    required this.repository,
  });

  final BookingOrder order;
  final OrderRepository repository;

  @override
  State<MerchantOrderAppealDialog> createState() =>
      _MerchantOrderAppealDialogState();
}

class _MerchantOrderAppealDialogState extends State<MerchantOrderAppealDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _reason = 'no_show';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.submitMerchantAppeal(
        widget.order.id,
        reason: _reason,
        description: _description.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appeal = widget.order.merchantAppeal;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(appeal == null ? '订单申诉' : '申诉详情'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: appeal == null
                ? Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('订单仍为已完成。请说明实际情况，提交平台核实处理。'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _reason,
                          decoration: const InputDecoration(labelText: '申诉类型'),
                          items: const [
                            DropdownMenuItem(
                              value: 'no_show',
                              child: Text('用户未到店'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('其他情况'),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _reason = value!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('merchant-appeal-description'),
                          controller: _description,
                          enabled: !_saving,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: '情况说明',
                            hintText: '请详细说明未到店或其他需要申诉的情况',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '请填写情况说明'
                              : null,
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(switch (appeal['decision']) {
                        'approved' => '审核通过',
                        'rejected' => '未通过',
                        _ => appeal['status'] == 'handled' ? '已处理' : '等待平台处理',
                      }),
                      const SizedBox(height: 12),
                      Text(
                        '申诉类型：${appeal['reason'] == 'no_show' ? '用户未到店' : '其他情况'}',
                      ),
                      const SizedBox(height: 12),
                      Text(appeal['description']?.toString() ?? ''),
                      if (appeal['response'] != null) ...[
                        const SizedBox(height: 16),
                        const Text('平台处理意见'),
                        const SizedBox(height: 8),
                        Text(appeal['response'].toString()),
                      ],
                    ],
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(appeal == null ? '取消' : '关闭'),
          ),
          if (appeal == null)
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? '提交中…' : '提交申诉'),
            ),
        ],
      ),
    );
  }
}
