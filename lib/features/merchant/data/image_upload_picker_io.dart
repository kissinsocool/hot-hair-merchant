import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

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
  final image = await _picker.pickImage(source: ImageSource.gallery);
  if (image == null) return null;

  return _pickedImageFromXFile(image);
}

Future<List<PickedImage>> pickImagesForUpload({int limit = 5}) async {
  final images = await _picker.pickMultiImage();
  final pickedImages = <PickedImage>[];
  for (final image in images.take(limit)) {
    pickedImages.add(await _pickedImageFromXFile(image));
  }

  return pickedImages;
}

Future<PickedImage> _pickedImageFromXFile(XFile image) async {
  final bytes = await image.readAsBytes();
  final dimensions = await _decodeImageDimensions(bytes);
  final mimeType = image.mimeType ?? _inferMimeType(image.name);
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

String _inferMimeType(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.png')) return 'image/png';
  if (lowerName.endsWith('.gif')) return 'image/gif';
  if (lowerName.endsWith('.webp')) return 'image/webp';
  if (lowerName.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
