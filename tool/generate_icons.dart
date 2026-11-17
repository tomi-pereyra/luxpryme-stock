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

  // Proportions for centered, modern bold "L" (scaled down slightly for better margins)
  // Height: 540px, Stroke: 130px
  // x: [327, 697] (center = 512)
  // y: [242, 782] (center = 512)
  fillRect(appIcon, x1: 327, y1: 242, x2: 457, y2: 782, color: whiteColor);
  fillRect(appIcon, x1: 327, y1: 652, x2: 697, y2: 782, color: whiteColor);

  // Subtle rounded corner smoothing on outer tips
  fillCircle(appIcon, x: 392, y: 258, radius: 16, color: whiteColor);
  fillCircle(appIcon, x: 681, y: 717, radius: 16, color: whiteColor);

  final appIconBytes = encodePng(appIcon);
  File('assets/icon/app_icon.png').writeAsBytesSync(appIconBytes);
  print('assets/icon/app_icon.png generated (${appIconBytes.length} bytes)');

  // =========================================================================
  // 2. GENERATE adaptive_foreground.png (1024x1024 with transparent background)
  // Tuned for Android 16% inset so the "L" fits comfortably within the circle safe-zone
  // =========================================================================
  final fgIcon = Image(width: size, height: size, numChannels: 4);
  fill(fgIcon, color: transparentColor);

  // Proportions: 620px height, 150px stroke (decreased slightly from 740px)
  // x: [287, 737] (center = 512)
  // y: [202, 822] (center = 512)
  fillRect(fgIcon, x1: 287, y1: 202, x2: 437, y2: 822, color: whiteColor);
  fillRect(fgIcon, x1: 287, y1: 672, x2: 737, y2: 822, color: whiteColor);

  // Subtle rounded corner smoothing on outer tips
  fillCircle(fgIcon, x: 362, y: 220, radius: 18, color: whiteColor);
  fillCircle(fgIcon, x: 717, y: 747, radius: 18, color: whiteColor);

  final fgBytes = encodePng(fgIcon);
  File('assets/icon/adaptive_foreground.png').writeAsBytesSync(fgBytes);
  print('assets/icon/adaptive_foreground.png generated (${fgBytes.length} bytes)');
}
