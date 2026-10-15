import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/image/image_urls.dart';

class AdminReviewStatus extends StatelessWidget {
  const AdminReviewStatus({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('已通过', Colors.green),
      'rejected' => ('已驳回', Colors.red),
      _ => ('待审核', Colors.orange),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}

class AdminImageThumbnails extends StatelessWidget {
  const AdminImageThumbnails({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final urls = ((item['imageUrls'] as List?) ?? const [])
        .map((url) => url.toString())
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty) return const Text('-');

    return SizedBox(
      width: 170,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final url in urls)
            InkWell(
              onTap: () => _showPreview(context, url),
              borderRadius: BorderRadius.circular(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  publicThumbnailUrl(url, width: 240),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showPreview(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration adminPanelDecoration() {
  return BoxDecoration(
    color: AppTheme.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppTheme.accentBeige),
  );
}
