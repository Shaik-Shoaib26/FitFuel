import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 35.3I.1 — Native and Web Branding Asset Verification', () {
    test('Web favicon and manifest icons exist with non-zero size', () {
      final favicon = File('web/favicon.png');
      expect(favicon.existsSync(), isTrue);
      expect(favicon.lengthSync(), greaterThan(100));

      final icon192 = File('web/icons/Icon-192.png');
      expect(icon192.existsSync(), isTrue);
      expect(icon192.lengthSync(), greaterThan(500));

      final icon512 = File('web/icons/Icon-512.png');
      expect(icon512.existsSync(), isTrue);
      expect(icon512.lengthSync(), greaterThan(1000));

      final maskable192 = File('web/icons/Icon-maskable-192.png');
      expect(maskable192.existsSync(), isTrue);
      expect(maskable192.lengthSync(), greaterThan(500));

      final maskable512 = File('web/icons/Icon-maskable-512.png');
      expect(maskable512.existsSync(), isTrue);
      expect(maskable512.lengthSync(), greaterThan(1000));
    });

    test('Android launcher mipmap icons exist with non-zero size', () {
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final icon = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(icon.existsSync(), isTrue, reason: 'Missing mipmap-$density/ic_launcher.png');
        expect(icon.lengthSync(), greaterThan(100));
      }
    });

    test('iOS AppIcon assets exist with non-zero size', () {
      final icons = [
        'Icon-App-20x20@1x.png',
        'Icon-App-20x20@2x.png',
        'Icon-App-20x20@3x.png',
        'Icon-App-29x29@1x.png',
        'Icon-App-29x29@2x.png',
        'Icon-App-29x29@3x.png',
        'Icon-App-40x40@1x.png',
        'Icon-App-40x40@2x.png',
        'Icon-App-40x40@3x.png',
        'Icon-App-60x60@2x.png',
        'Icon-App-60x60@3x.png',
        'Icon-App-76x76@1x.png',
        'Icon-App-76x76@2x.png',
        'Icon-App-83.5x83.5@2x.png',
        'Icon-App-1024x1024@1x.png',
      ];
      for (final name in icons) {
        final icon = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/$name');
        expect(icon.existsSync(), isTrue, reason: 'Missing iOS AppIcon $name');
        expect(icon.lengthSync(), greaterThan(50));
      }
    });

    test('Native Android launch background references brand color', () {
      final launchBg = File('android/app/src/main/res/drawable/launch_background.xml');
      expect(launchBg.existsSync(), isTrue);
      final content = launchBg.readAsStringSync();
      expect(content.contains('@color/fitfuel_primary'), isTrue);
    });
  });
}
