// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

@TestOn('browser')
library;

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/merchant/data/image_upload_picker_web.dart';

void main() {
  test(
    'file selection catches a change fired while the picker closes',
    () async {
      final input = html.FileUploadInputElement();

      await waitForFileSelection(
        input,
        openPicker: () => input.dispatchEvent(html.Event('change')),
      ).timeout(const Duration(milliseconds: 100));
    },
  );

  test('invalid image reports an error instead of hanging', () async {
    final file = html.File(
      [
        <int>[0, 1, 2, 3],
      ],
      'broken.jpg',
      {'type': 'image/jpeg'},
    );

    await expectLater(
      pickedImageFromFileForUpload(file),
      throwsA(isA<ImageUploadDecodeException>()),
    );
  });

  test('the first read of every new image completes', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    for (var index = 0; index < 20; index += 1) {
      final file = html.File(
        [bytes],
        'new-image-$index.png',
        {'type': 'image/png'},
      );
      final image = await pickedImageFromFileForUpload(
        file,
      ).timeout(const Duration(seconds: 1));

      expect(image.width, 1);
      expect(image.height, 1);
    }
  });

  test('the first read of a large image completes without retrying', () async {
    final canvas = html.CanvasElement(width: 4000, height: 3000);
    canvas.context2D.fillStyle = '#ff69b4';
    canvas.context2D.fillRect(0, 0, canvas.width!, canvas.height!);
    final bytes = base64Decode(
      canvas.toDataUrl('image/jpeg', 0.9).split(',').last,
    );
    final file = html.File(
      [bytes],
      'new-large-image.jpg',
      {'type': 'image/jpeg'},
    );

    final image = await pickedImageFromFileForUpload(
      file,
    ).timeout(const Duration(seconds: 10));

    expect(image.width, 1920);
    expect(image.height, 1440);
  });
}
