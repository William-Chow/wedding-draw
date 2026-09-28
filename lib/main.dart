import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/audio/sound_effects.dart';
import 'src/draw/draw_controller.dart';
import 'src/settings/draw_storage.dart';
import 'src/ui/draw_page.dart';
import 'src/ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_robotoLicense);
  final storage = await DrawStorage.open();
  final sounds = AudioPlayersSoundEffects()..preload();
  runApp(
    WeddingDrawApp(
      controller: DrawController(storage: storage),
      sounds: sounds,
    ),
  );
}

Stream<LicenseEntry> _robotoLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/Roboto-LICENSE.txt');
  yield LicenseEntryWithLineBreaks(const ['Roboto'], text);
}

class WeddingDrawApp extends StatelessWidget {
  const WeddingDrawApp({
    super.key,
    required this.controller,
    required this.sounds,
  });

  final DrawController controller;
  final SoundEffects sounds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wedding Draw',
      debugShowCheckedModeBanner: false,
      theme: buildWeddingTheme(),
      home: DrawPage(controller: controller, sounds: sounds),
    );
  }
}

/// Light Material 3 theme in rose and champagne.
ThemeData buildWeddingTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: WeddingPalette.rose,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(surface: WeddingPalette.ivory);
  // Roboto is bundled (see pubspec.yaml), so the web build works offline.
  final base = ThemeData(colorScheme: colorScheme, fontFamily: 'Roboto');
  return base.copyWith(
    scaffoldBackgroundColor: WeddingPalette.ivory,
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: WeddingPalette.gold.withValues(alpha: 0.45)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
    ),
    dividerTheme: DividerThemeData(
      color: WeddingPalette.gold.withValues(alpha: 0.35),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
