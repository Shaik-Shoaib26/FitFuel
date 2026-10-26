// ignore_for_file: avoid_print, prefer_const_declarations
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/data/food_image_manifest.dart';

void main() {
  group('Phase 35.7.1 Real Food Image Coverage Expansion Audit', () {
    final foods = PredefinedFoodData.foods;
    final manifest = FoodImageManifest.manifest;

    test('1. Full Food Catalog Audit & Verification', () {
      expect(foods.length, 238, reason: 'Food catalog must contain exactly 238 items');
      expect(manifest.length, 238, reason: 'Manifest must contain exactly 238 items');

      final urlToFoods = <String, List<String>>{};
      int emptyCount = 0;
      int verifiedCount = 0;

      for (final food in foods) {
        final entry = manifest[food.id];
        expect(entry, isNotNull, reason: 'Every catalog food must have a manifest entry');
        final url = entry!.imagePathOrUrl.trim();
        if (url.isEmpty) {
          emptyCount++;
        } else {
          verifiedCount++;
          urlToFoods.putIfAbsent(url, () => []).add('${food.id} (${food.name})');
        }
      }

      print('\n======================================================');
      print('FITFUEL — PHASE 35.7.1 FOOD IMAGE AUDIT RESULTS');
      print('======================================================');
      print('Total Foods: ${foods.length}');
      print('Verified Real Food Photos: $verifiedCount');
      print('Branded Fallbacks: $emptyCount');
      print('Duplicate URL Groups: ${urlToFoods.values.where((l) => l.length > 1).length}');
      print('Coverage: ${(verifiedCount / foods.length * 100).toStringAsFixed(1)}%');
      print('======================================================\n');

      expect(verifiedCount, 163, reason: 'Target authentic photography coverage (163 foods)');
      expect(emptyCount, 75, reason: 'Safely using FitFuel branded fallback (75 foods)');

      // Duplicate groups must strictly be approved culinary aliases
      final duplicateGroups = urlToFoods.entries.where((e) => e.value.length > 1).toList();
      expect(duplicateGroups.length, 8, reason: 'Only 8 approved culinary alias duplicate groups allowed');
      for (final group in duplicateGroups) {
        expect(group.value.length <= 3, isTrue, reason: 'Every approved alias duplicate group has <= 3 foods');
      }
    });

    test('2. Strict Truthfulness: Authentic Foods Resolve to Verified Photos', () {
      // Expanded authentic photography
      expect(FoodImageResolver.resolve('Idli'), 'assets/images/foods/idli.webp');
      expect(FoodImageResolver.resolve('predefined_idli'), 'assets/images/foods/idli.webp');
      expect(FoodImageResolver.resolve('Upma'), 'assets/images/foods/upma.webp');
      expect(FoodImageResolver.resolve('Poha'), 'assets/images/foods/poha.webp');
      expect(FoodImageResolver.resolve('Chapati'), 'assets/images/foods/chapati.webp');
      expect(FoodImageResolver.resolve('Tandoori Roti'), 'assets/images/foods/roti.webp');
      expect(FoodImageResolver.resolve('Poori'), 'assets/images/foods/poori.webp');
      expect(FoodImageResolver.resolve('Aloo Paratha'), 'assets/images/foods/aloo_paratha.webp');
      expect(FoodImageResolver.resolve('Steamed Shrimp'), 'assets/images/foods/steamed_shrimp.webp');
      expect(FoodImageResolver.resolve('Grilled Beef Sirloin Steak'), 'assets/images/foods/beef_steak.webp');
      expect(FoodImageResolver.resolve('Gulab Jamun'), 'assets/images/foods/gulab_jamun.webp');
      expect(FoodImageResolver.resolve('Kiwi Fruit'), 'assets/images/foods/kiwi.webp');
      expect(FoodImageResolver.resolve('Green Bell Pepper (Capsicum)'), 'assets/images/foods/capsicum.webp');
      expect(FoodImageResolver.resolve('Indian Curd (Dahi)'), 'assets/images/foods/curd.webp');
      expect(FoodImageResolver.resolve('Low Fat Milk (1.5% Fat)'), '');
      expect(FoodImageResolver.resolve('Pumpkin'), 'assets/images/foods/pumpkin.webp');

      // Baseline verified exact photos
      expect(
        FoodImageResolver.resolve('Broccoli'),
        'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80',
      );
      expect(
        FoodImageResolver.resolve('Chicken Biryani'),
        'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80',
      );
      expect(
        FoodImageResolver.resolve('Paneer Tikka'),
        'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=600&q=80',
      );
      expect(
        FoodImageResolver.resolve('Samosa'),
        'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
      );
    });

    test('3. Indian Food Disambiguation (No Visual Interchanging)', () {
      // Idli != Dhokla
      final idli = FoodImageResolver.resolve('Idli');
      final dhokla = FoodImageResolver.resolve('Dhokla');
      expect(idli, isNotEmpty);
      expect(dhokla, isNotEmpty);
      expect(idli != dhokla, isTrue);

      // Poha != Upma
      final poha = FoodImageResolver.resolve('Poha');
      final upma = FoodImageResolver.resolve('Upma');
      expect(poha, isNotEmpty);
      expect(upma, isNotEmpty);
      expect(poha != upma, isTrue);

      // Chapati != Poori
      final chapati = FoodImageResolver.resolve('Chapati');
      final poori = FoodImageResolver.resolve('Poori');
      expect(chapati, isNotEmpty);
      expect(poori, isNotEmpty);
      expect(chapati != poori, isTrue);

      // Plain Dosa != Uttapam
      final dosa = FoodImageResolver.resolve('Plain Dosa');
      final uttapam = FoodImageResolver.resolve('Uttapam');
      expect(dosa, isNotEmpty);
      expect(uttapam, isNotEmpty);
      expect(dosa != uttapam, isTrue);

      // Chole != Rajma != Palak Paneer
      final chole = FoodImageResolver.resolve('Chole Masala (Chickpeas)');
      final rajma = FoodImageResolver.resolve('Rajma Curry (Kidney Beans)');
      final palakPaneer = FoodImageResolver.resolve('Palak Paneer');
      expect(chole, isNotEmpty);
      expect(rajma, isNotEmpty);
      expect(palakPaneer, isNotEmpty);
      expect(chole != rajma, isTrue);
      expect(chole != palakPaneer, isTrue);
      expect(rajma != palakPaneer, isTrue);
    });

    test('4. Fallback Integrity: Remaining & Custom Foods Safely Fall Back', () {
      expect(FoodImageResolver.resolve('Mineral Water'), '');
      expect(FoodImageResolver.resolve('Fresh Coconut Meat'), '');
      expect(FoodImageResolver.resolve('Chaas (Indian Buttermilk)'), '');
      expect(FoodImageResolver.resolve('Unknown Random Food'), '');
      expect(FoodImageResolver.resolve('Homemade Chicken Biryani 500g'), '');
      expect(FoodImageResolver.resolve(''), '');
      expect(FoodImageResolver.resolve(null), '');
    });
  });
}
