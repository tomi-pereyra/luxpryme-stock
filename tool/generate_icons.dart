// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'dart:io';
import 'package:image/image.dart';

void main() {
  const int size = 1024;
  final blueColor = ColorRgba8(25, 118, 210, 255); // #1976D2 Official Luxpryme Blue
  final whiteColor = ColorRgba8(255, 255, 255, 255); // Pure White
  final transparentColor = ColorRgba8(0, 0, 0, 0);

  // =========================================================================
  // 1. GENERATE app_icon.png (Full 1024x1024 solid background for Windows & Legacy Android)
  // Background fills 100% of space, no transparent borders or margins.
  // =========================================================================
  final appIcon = Image(width: size, height: size, numChannels: 4);
  fill(appIcon, color: blueColor);

  // Proportions for centered, modern bold "L" (620px height, 150px stroke)
  // x: [287, 737] (center = 512)
  // y: [202, 822] (center = 512)
  fillRect(appIcon, x1: 287, y1: 202, x2: 437, y2: 822, color: whiteColor);
  fillRect(appIcon, x1: 287, y1: 672, x2: 737, y2: 822, color: whiteColor);

  // Subtle rounded corner smoothing on outer tips
  fillCircle(appIcon, x: 362, y: 220, radius: 18, color: whiteColor);
  fillCircle(appIcon, x: 717, y: 747, radius: 18, color: whiteColor);

  final appIconBytes = encodePng(appIcon);
  File('assets/icon/app_icon.png').writeAsBytesSync(appIconBytes);
  print('assets/icon/app_icon.png generated (${appIconBytes.length} bytes)');

  // =========================================================================
  // 2. GENERATE adaptive_foreground.png (1024x1024 with transparent background)
  // Tuned for Android 16% inset so the "L" fits the 72dp safe-zone perfectly!
  // =========================================================================
  final fgIcon = Image(width: size, height: size, numChannels: 4);
  fill(fgIcon, color: transparentColor);

  // Proportions: 740px height, 176px stroke
  // x: [244, 780] (center = 512)
  // y: [142, 882] (center = 512)
  fillRect(fgIcon, x1: 244, y1: 142, x2: 420, y2: 882, color: whiteColor);
  fillRect(fgIcon, x1: 244, y1: 706, x2: 780, y2: 882, color: whiteColor);

  // Subtle rounded corner smoothing on outer tips
  fillCircle(fgIcon, x: 332, y: 162, radius: 20, color: whiteColor);
  fillCircle(fgIcon, x: 758, y: 794, radius: 20, color: whiteColor);

  final fgBytes = encodePng(fgIcon);
  File('assets/icon/adaptive_foreground.png').writeAsBytesSync(fgBytes);
  print('assets/icon/adaptive_foreground.png generated (${fgBytes.length} bytes)');
}
