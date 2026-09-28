import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wedding_draw/src/settings/draw_settings.dart';
import 'package:wedding_draw/src/settings/draw_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DrawStorage> openStorage([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return DrawStorage.open();
  }

  /// Simulates an app restart: prefs are reloaded from the platform store.
  Future<DrawStorage> reopen() {
    SharedPreferences.resetStatic();
    return DrawStorage.open();
  }

  group('DrawStorage', () {
    test('returns defaults when nothing has been saved', () async {
      final storage = await openStorage();

      expect(storage.loadSettings(), const DrawSettings());
      expect(storage.loadWinners(), isEmpty);
      expect(storage.loadMuted(), isFalse);
    });

    test('settings, winners and mute survive a restart', () async {
      final storage = await openStorage();
      const settings = DrawSettings(
        title: 'William & Anna',
        min: 10,
        max: 350,
        allowRepeats: true,
      );

      await storage.saveSettings(settings);
      await storage.saveWinners([42, 7, 350]);
      await storage.saveMuted(true);

      final restarted = await reopen();
      expect(restarted.loadSettings(), settings);
      expect(restarted.loadWinners(), [42, 7, 350]);
      expect(restarted.loadMuted(), isTrue);
    });

    test('an empty winners list is saved too', () async {
      final storage = await openStorage({
        DrawStorage.winnersKey: ['1', '2'],
      });

      await storage.saveWinners([]);

      expect((await reopen()).loadWinners(), isEmpty);
    });

    test('ignores malformed values', () async {
      final storage = await openStorage({
        DrawStorage.titleKey: 'Ada & Grace',
        DrawStorage.minKey: 'not a number',
        DrawStorage.maxKey: 50,
        DrawStorage.allowRepeatsKey: 'yes',
        DrawStorage.winnersKey: ['3', 'x', '-1', '100000', '7'],
        DrawStorage.mutedKey: 1,
      });

      expect(
        storage.loadSettings(),
        const DrawSettings(title: 'Ada & Grace', min: 1, max: 50),
      );
      expect(storage.loadWinners(), [3, 7]);
      expect(storage.loadMuted(), isFalse);
    });

    test(
      'falls back to the default range when the saved one is invalid',
      () async {
        final storage = await openStorage({
          DrawStorage.minKey: 30,
          DrawStorage.maxKey: 20,
          DrawStorage.allowRepeatsKey: true,
        });

        final settings = storage.loadSettings();

        expect(settings.min, const DrawSettings().min);
        expect(settings.max, const DrawSettings().max);
        expect(settings.allowRepeats, isTrue);
      },
    );

    test('ignores winners saved with the wrong type', () async {
      final storage = await openStorage({DrawStorage.winnersKey: '1,2,3'});

      expect(storage.loadWinners(), isEmpty);
    });

    test('in-memory storage loads defaults and saves nothing', () async {
      final storage = DrawStorage.inMemory();

      await storage.saveSettings(const DrawSettings(max: 10));
      await storage.saveWinners([1]);
      await storage.saveMuted(true);

      expect(storage.loadSettings(), const DrawSettings());
      expect(storage.loadWinners(), isEmpty);
      expect(storage.loadMuted(), isFalse);
    });
  });
}
