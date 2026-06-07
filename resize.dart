import 'dart:io';
import 'package:image/image.dart';

void main() {
  final imagePath = 'assets/icon.png';
  final bytes = File(imagePath).readAsBytesSync();
  final originalImage = decodeImage(bytes);
  if (originalImage == null) {
    print('Failed to decode');
    return;
  }
  
  // Create a 1024x1024 canvas
  final paddedImage = Image(width: 1024, height: 1024);
  
  // Resize original to 700x700
  final resized = copyResize(originalImage, width: 700, height: 700);
  
  // Draw it in the center
  compositeImage(paddedImage, resized, dstX: 162, dstY: 162);
  
  File(imagePath).writeAsBytesSync(encodePng(paddedImage));
  print('Icon resized successfully!');
}
