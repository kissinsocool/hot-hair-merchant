import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/image/image_urls.dart';

void main() {
  test('only controlled public originals receive thumbnail transformations', () {
    const original = 'https://media.hothaircc.cn/uploads/image.jpg';
    expect(
      publicThumbnailUrl(original, width: 360),
      '$original?x-oss-process=image/resize,w_360/quality,q_75',
    );
    for (final url in [
      '$original?Signature=abc%2Fdef%3D',
      'https://hothairprivate.oss-cn-beijing.aliyuncs.com/one.jpg?Signature=abc%2B',
      'https://media.hothaircc.cn.evil.example/uploads/image.jpg',
      'https://example.com/image.jpg',
      'https://media.hothaircc.cn/uploads/image.gif',
      'data:image/png;base64,AA==',
    ]) {
      expect(publicThumbnailUrl(url), url);
    }
  });
}
