import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = 'assets/kardo-logo.png';
  final outputPath = 'assets/assets/images/kardo_logo.png';

  final bytes = File(inputPath).readAsBytesSync();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Error: Could not decode image');
    return;
  }

  // Set padding ratio to 15% (logo takes up 70% of the canvas size)
  final paddingRatio = 0.15;
  final width = image.width;
  final height = image.height;

  final newWidth = (width * (1 - 2 * paddingRatio)).toInt();
  final newHeight = (height * (1 - 2 * paddingRatio)).toInt();

  // Resize the logo to be smaller
  final resizedImage = img.copyResize(image, width: newWidth, height: newHeight, interpolation: img.Interpolation.cubic);

  // Create a new solid white canvas
  final canvas = img.Image(width: width, height: height);
  canvas.clear(img.ColorRgb8(255, 255, 255)); // Fill with white background

  // Calculate coordinates to center the resized image
  final offsetX = (width - newWidth) ~/ 2;
  final offsetY = (height - newHeight) ~/ 2;

  // Paste the resized image onto the canvas
  img.compositeImage(canvas, resizedImage, dstX: offsetX, dstY: offsetY);

  // Encode to PNG and save
  final pngBytes = img.encodePng(canvas);
  File(outputPath).writeAsBytesSync(pngBytes);

  print('Successfully added padding and saved to $outputPath');
}
