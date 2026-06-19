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
  return null;
}

Future<List<PickedImage>> pickImagesForUpload({
  int limit = 5,
}) async {
  return [];
}
