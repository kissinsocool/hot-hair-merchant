import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

const int _maxImageBytes = 5 * 1024 * 1024;
const double _maxImageSide = 1920;
const int _imageQuality = 80;

class ImageUploadTooLargeException implements Exception {
  const ImageUploadTooLargeException();

  @override
  String toString() => '图片压缩后仍超过5MB，请换一张更小的图片';
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

final ImagePicker _picker = ImagePicker();

Future<PickedImage?> pickImageForUpload() async {
  final image = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: _maxImageSide,
    maxHeight: _maxImageSide,
    imageQuality: _imageQuality,
  );
  if (image == null) return null;

  return _pickedImageFromXFile(image);
}

Future<List<PickedImage>> pickImagesForUpload({int limit = 5}) async {
  final images = await _picker.pickMultiImage(
    maxWidth: _maxImageSide,
    maxHeight: _maxImageSide,
    imageQuality: _imageQuality,
  );
  final pickedImages = <PickedImage>[];
  for (final image in images.take(limit)) {
    pickedImages.add(await _pickedImageFromXFile(image));
  }

  return pickedImages;
}

Future<PickedImage> _pickedImageFromXFile(XFile image) async {
  final bytes = await image.readAsBytes();
  if (bytes.length > _maxImageBytes) throw const ImageUploadTooLargeException();

  final dimensions = await _decodeImageDimensions(bytes);
  final mimeType = _inferMimeType(image.name, bytes);
  final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

  return PickedImage(
    fileName: image.name,
    base64Data: dataUrl,
    width: dimensions.width,
    height: dimensions.height,
  );
}

Future<({int width, int height})> _decodeImageDimensions(
  Uint8List bytes,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final dimensions = (width: image.width, height: image.height);
  image.dispose();
  codec.dispose();
  return dimensions;
}

String _inferMimeType(String fileName, Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }

  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.png')) return 'image/png';
  if (lowerName.endsWith('.gif')) return 'image/gif';
  if (lowerName.endsWith('.webp')) return 'image/webp';
  if (lowerName.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
