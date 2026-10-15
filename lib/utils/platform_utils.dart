import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformUtils {
  /// Returns true if running on a desktop operating system (macOS, Windows, Linux).
  static bool get isDesktopOS =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Returns true if the current layout should use the desktop PC experience.
  /// This checks either the OS or a wide display width (>= 850px).
  static bool isDesktop(BuildContext context) {
    if (isDesktopOS) return true;
    return MediaQuery.of(context).size.width >= 850;
  }
}
