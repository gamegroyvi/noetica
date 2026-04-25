import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Wires up Windows/Linux/macOS system tray:
///   * tray icon shows up next to the clock
///   * left-clicking the icon toggles the window
///   * right-click → menu (`Открыть Noetica` / `Выйти`)
///   * intercepting the close button hides the window into the tray instead
///     of killing the process — this is what keeps `NotificationsService`'s
///     timer-based scheduler alive on Windows/Linux.
class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _ready = false;

  bool get isDesktop {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (_ready) return;
    if (!isDesktop) return;
    _ready = true;

    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);
    } catch (e) {
      debugPrint('window_manager init failed: $e');
    }

    try {
      await trayManager.setIcon(_trayIconPath());
      await trayManager.setToolTip('Noetica');
      await trayManager.setContextMenu(
        Menu(items: [
          MenuItem(key: 'open', label: 'Открыть Noetica'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Выйти'),
        ]),
      );
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('tray_manager init failed: $e');
    }
  }

  String _trayIconPath() {
    // tray_manager resolves relative paths against the Flutter assets
    // bundle (data/flutter_assets/<path> on Windows). Using the source-tree
    // path `windows/runner/resources/app_icon.ico` does NOT work at
    // runtime — that file is the EXE icon, not a Flutter asset.
    return 'assets/branding/icon_glyph.png';
  }

  // ---- TrayListener ----

  @override
  void onTrayIconMouseDown() {
    _toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'open':
        await _showWindow();
        break;
      case 'exit':
        await _exitApp();
        break;
    }
  }

  // ---- WindowListener ----

  @override
  void onWindowClose() async {
    // Hide instead of quit so the timer queue keeps firing toasts.
    final isPrevented = await windowManager.isPreventClose();
    if (isPrevented) {
      await windowManager.hide();
    }
  }

  Future<void> _toggleWindow() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
    } else {
      await _showWindow();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {}
    // As a final safety net for Windows where close() with preventClose=false
    // can still get caught by some shells.
    SystemNavigator.pop();
  }
}
