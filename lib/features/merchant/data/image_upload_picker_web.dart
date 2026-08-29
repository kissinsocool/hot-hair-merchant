// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

const int _maxImageBytes = 5 * 1024 * 1024;
const int _maxImageSide = 1920;
const double _imageQuality = 0.8;
const String _acceptedImageTypes = 'image/jpeg,image/png,image/webp';

class ImageUploadTooLargeException implements Exception {
  const ImageUploadTooLargeException();

  @override
  String toString() => '图片压缩后仍超过5MB，请换一张更小的图片';
}

class ImageUploadDecodeException implements Exception {
  const ImageUploadDecodeException();

  @override
  String toString() => '图片读取失败，请上传有效的JPG、PNG或WebP图片；如果图片尺寸过大，请先压缩后重试';
}

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
    ..accept = _acceptedImageTypes
    ..multiple = false;

  await waitForFileSelection(input);

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  return pickedImageFromFileForUpload(file);
}

Future<List<PickedImage>> pickImagesForUpload({int limit = 5}) async {
  final input = html.FileUploadInputElement()
    ..accept = _acceptedImageTypes
    ..multiple = true;

  await waitForFileSelection(input);

  final files = input.files;
  if (files == null || files.isEmpty) return [];

  final pickedImages = <PickedImage>[];
  for (final file in files.take(limit)) {
    pickedImages.add(await pickedImageFromFileForUpload(file));
  }

  return pickedImages;
}

Future<void> waitForFileSelection(
  html.FileUploadInputElement input, {
  void Function()? openPicker,
}) async {
  final changed = input.onChange.first;
  (openPicker ?? input.click)();
  await changed;
}

Future<PickedImage> pickedImageFromFileForUpload(html.File file) async {
  final sourceUrl = html.Url.createObjectUrl(file);
  try {
    final sourceImage = html.ImageElement(src: sourceUrl);
    try {
      await sourceImage.decode();
    } catch (_) {
      throw const ImageUploadDecodeException();
    }

    final sourceWidth = sourceImage.naturalWidth;
    final sourceHeight = sourceImage.naturalHeight;
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      throw const ImageUploadDecodeException();
    }

    final scale =
        _maxImageSide /
        [sourceWidth, sourceHeight].reduce((a, b) => a > b ? a : b);
    final width = scale < 1 ? (sourceWidth * scale).round() : sourceWidth;
    final height = scale < 1 ? (sourceHeight * scale).round() : sourceHeight;
    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImageScaled(sourceImage, 0, 0, width, height);

    final dataUrl = canvas.toDataUrl('image/jpeg', _imageQuality);
    if (_dataUrlBytes(dataUrl) > _maxImageBytes) {
      throw const ImageUploadTooLargeException();
    }

    return PickedImage(
      fileName: '${file.name.replaceFirst(RegExp(r'\.[^.]*$'), '')}.jpg',
      base64Data: dataUrl,
      width: width,
      height: height,
    );
  } finally {
    html.Url.revokeObjectUrl(sourceUrl);
  }
}

int _dataUrlBytes(String dataUrl) {
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex == -1) return dataUrl.length;
  final base64Length = dataUrl.length - commaIndex - 1;
  return (base64Length * 3 / 4).ceil();
}
