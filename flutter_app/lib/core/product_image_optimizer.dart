import 'dart:typed_data';

import 'package:image/image.dart' as image;

class OptimizedProductImage {
  const OptimizedProductImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String format;
}

/// Optimizes product-catalog images only. It is intentionally not used for
/// payment proofs or identity evidence, whose bytes must remain private and
/// unmodified for review/audit purposes.
OptimizedProductImage optimizeProductImage(
  Uint8List source, {
  int maxDimension = 1600,
  int quality = 82,
}) {
  if (source.isEmpty) throw const FormatException('الصورة فارغة.');
  if (maxDimension < 320 || maxDimension > 4096) {
    throw ArgumentError.value(
      maxDimension,
      'maxDimension',
      'must be between 320 and 4096',
    );
  }
  if (quality < 50 || quality > 95) {
    throw ArgumentError.value(quality, 'quality', 'must be between 50 and 95');
  }
  image.Image? decoded;
  try {
    decoded = image.decodeImage(source);
  } on Object {
    throw const FormatException('تعذر قراءة صورة المنتج.');
  }
  if (decoded == null) throw const FormatException('تعذر قراءة صورة المنتج.');
  final oriented = image.bakeOrientation(decoded);
  final longestSide = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final target = longestSide > maxDimension
      ? image.copyResize(
          oriented,
          width: oriented.width >= oriented.height
              ? maxDimension
              : (oriented.width * maxDimension / oriented.height).round(),
          height: oriented.height >= oriented.width
              ? maxDimension
              : (oriented.height * maxDimension / oriented.width).round(),
          interpolation: image.Interpolation.cubic,
        )
      : oriented;
  return OptimizedProductImage(
    bytes: Uint8List.fromList(image.encodeJpg(target, quality: quality)),
    width: target.width,
    height: target.height,
    format: 'jpeg',
  );
}
