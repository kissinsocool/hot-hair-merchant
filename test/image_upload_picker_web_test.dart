// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

@TestOn('browser')
library;

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/merchant/data/image_upload_picker_web.dart';

void main() {
  test('file input stays attached while the picker is open', () async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      final input = html.FileUploadInputElement();
      var wasAttachedWhenOpened = false;

      await waitForFileSelection(
        input,
        openPicker: () {
          wasAttachedWhenOpened = html.document.body?.contains(input) == true;
          input.dispatchEvent(html.Event('change'));
        },
      ).timeout(const Duration(milliseconds: 100));

      expect(wasAttachedWhenOpened, isTrue);
      expect(html.document.body?.contains(input), isFalse);
    }
  });

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

  test('a large high-entropy image is processed asynchronously', () async {
    const width = 2600;
    const height = 2200;
    final canvas = html.CanvasElement(width: width, height: height);
    final pixels = canvas.context2D.createImageData(width, height);
    var value = 1;
    for (var index = 0; index < pixels.data.length; index += 4) {
      value = (value * 1664525 + 1013904223) & 0xffffffff;
      pixels.data[index] = value & 0xff;
      pixels.data[index + 1] = (value >> 8) & 0xff;
      pixels.data[index + 2] = (value >> 16) & 0xff;
      pixels.data[index + 3] = 0xff;
    }
    canvas.context2D.putImageData(pixels, 0, 0);
    final bytes = base64Decode(
      canvas.toDataUrl('image/jpeg', 0.85).split(',').last,
    );
    expect(bytes.length, greaterThan(3 * 1024 * 1024));
    final file = html.File(
      [bytes],
      'new-large-image.jpg',
      {'type': 'image/jpeg'},
    );

    for (var attempt = 0; attempt < 10; attempt += 1) {
      final image = await pickedImageFromFileForUpload(
        file,
      ).timeout(const Duration(seconds: 30));

      expect(image.width, 1920);
      expect(image.height, 1625);
    }
  });
}
