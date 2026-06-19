// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class PickedImage {
  const PickedImage({
    required this.fileName,
    required this.base64Data,
    required this.width,
    required this.height,
  });

  final String fileName;
  final String base64Data;
  final int width;
  final int height;
}

Future<PickedImage?> pickImageForUpload() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  input.click();
  await input.onChange.first;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoad.first;

  final result = reader.result;
  if (result is! String) return null;

  return _pickedImageFromDataUrl(file.name, result);
}

Future<List<PickedImage>> pickImagesForUpload({
  int limit = 5,
}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = true;

  input.click();
  await input.onChange.first;

  final files = input.files;
  if (files == null || files.isEmpty) return [];

  final pickedImages = <PickedImage>[];
  for (final file in files.take(limit)) {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    final result = reader.result;
    if (result is String) {
      pickedImages.add(await _pickedImageFromDataUrl(file.name, result));
    }
  }

  return pickedImages;
}

Future<PickedImage> _pickedImageFromDataUrl(
  String fileName,
  String dataUrl,
) async {
  final sourceImage = html.ImageElement(src: dataUrl);
  await sourceImage.onLoad.first;

  final sourceWidth = sourceImage.naturalWidth;
  final sourceHeight = sourceImage.naturalHeight;
  return PickedImage(
    fileName: fileName,
    base64Data: dataUrl,
    width: sourceWidth,
    height: sourceHeight,
  );
}
