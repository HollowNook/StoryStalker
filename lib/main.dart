// main.dart
//
// Adds window positioning so your top taskbar doesn't cover the app.
// Keeps your existing SQLite FFI + settings load flow intact.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/book_list.dart';
import 'state/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite fix (Windows/macOS/Linux)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Desktop window positioning
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1100, 780),
      minimumSize: Size(900, 650),
      center: false, // we want a deliberate offset, not center
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    // Apply options, then move it down a bit before showing.
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // Open slightly down from the top so a top-docked taskbar won’t cover AppBar.
      await windowManager.setPosition(const Offset(50, 90));
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Load persisted settings (theme mode, etc.)
  final settings = AppSettingsController();
  await settings.load();

  runApp(StoryStalkerApp(settings: settings));
}

class StoryStalkerApp extends StatelessWidget {
  const StoryStalkerApp({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.teal;

    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Story Stalker',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,

          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            scaffoldBackgroundColor: const Color(0xFFFDF7F5),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: seed,
              foregroundColor: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.black54),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: const Color(0xFF0E1414),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: seed,
              foregroundColor: Colors.black,
            ),
            iconTheme: const IconThemeData(color: Colors.white70),
          ),

          home: BookListScreen(settings: settings),
        );
      },
    );
  }
}
