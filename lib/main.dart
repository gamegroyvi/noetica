import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'platform/desktop_check.dart';
import 'services/analytics_service.dart';
import 'services/notifications.dart';
import 'services/pomodoro_service.dart';
import 'services/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (isDesktopPlatform()) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting('ru', null);
  // Fire-and-forget: notification setup should never block the app.
  unawaited(NotificationsService.instance.init());
  // Tray icon + close-to-tray on desktop. Must run after binding init so
  // window_manager can talk to the platform channel.
  unawaited(TrayService.instance.init());
  // Pomodoro keeps ticking even when the sheet is closed so phase
  // transitions and OS-level notifications fire reliably.
  unawaited(PomodoroService.instance.init());
  AnalyticsService.instance.track(AnalyticsEvents.appOpened, {
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
  });
  runApp(const ProviderScope(child: NoeticaApp()));
}
