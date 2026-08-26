import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:yemen_commerce/core/product_image_optimizer.dart';

void main() {
  test('downscales the longest side and emits a compact jpeg', () {
    final sourceImage = image.Image(width: 2400, height: 1200);
    image.fill(sourceImage, color: image.ColorRgb8(20, 120, 110));
    final source = Uint8List.fromList(image.encodePng(sourceImage));

    final optimized = optimizeProductImage(source, maxDimension: 1600);

    expect(optimized.format, 'jpeg');
    expect(optimized.width, 1600);
    expect(optimized.height, 800);
    expect(optimized.bytes, isNotEmpty);
  });

  test('does not upscale smaller catalog images', () {
    final sourceImage = image.Image(width: 640, height: 480);
    image.fill(sourceImage, color: image.ColorRgb8(240, 240, 240));
    final source = Uint8List.fromList(image.encodePng(sourceImage));

    final optimized = optimizeProductImage(source);

    expect(optimized.width, 640);
    expect(optimized.height, 480);
  });

  test('rejects empty or invalid image bytes', () {
    expect(
      () => optimizeProductImage(Uint8List(0)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => optimizeProductImage(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
  });

  test('enforces safe optimizer bounds', () {
    final sourceImage = image.Image(width: 20, height: 20);
    final source = Uint8List.fromList(image.encodePng(sourceImage));

    expect(
      () => optimizeProductImage(source, maxDimension: 100),
      throwsArgumentError,
    );
    expect(
      () => optimizeProductImage(source, quality: 20),
      throwsArgumentError,
    );
  });
}
