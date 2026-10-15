String publicThumbnailUrl(String url, {int width = 720}) {
  const mediaBase = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: 'https://media.hothaircc.cn',
  );
  final media = Uri.tryParse(mediaBase);
  final image = Uri.tryParse(url);
  if (media == null ||
      image == null ||
      image.scheme != media.scheme ||
      image.host != media.host ||
      image.port != media.port ||
      !image.path.startsWith(
        '${media.path.replaceFirst(RegExp(r'/+$'), '')}/',
      ) ||
      image.hasQuery ||
      image.hasFragment ||
      !RegExp(
        r'\.(jpe?g|png|webp)$',
        caseSensitive: false,
      ).hasMatch(image.path)) {
    return url;
  }
  return '$url?x-oss-process=image/resize,w_$width/quality,q_75';
}
