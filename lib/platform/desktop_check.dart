import 'dart:io' show Platform;

bool isDesktopPlatform() =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;
