import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';

void main() {
  group('FoodImageResolver Tests', () {
    // 1. Network image path returns directly
    test('Network image path returns directly', () {
      final resolved = FoodImageResolver.resolve('https://images.unsplash.com/photo-1589301760014-d929f3979dbc');
      expect(resolved, 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc');
    });

    // 2. Food name normalization maps to Unsplash URL
    test('Food name normalization maps to Unsplash URL', () {
      final resolved = FoodImageResolver.resolve('Chicken Biryani');
      expect(resolved, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80');
    });

    // 3. Paneer Tikka resolves correctly to Unsplash
    test('Paneer Tikka resolves correctly to Unsplash', () {
      final resolved = FoodImageResolver.resolve('Paneer Tikka');
      expect(resolved, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=600&q=80');
    });

    // 4. Chicken Tikka resolves correctly to Unsplash
    test('Chicken Tikka resolves correctly to Unsplash', () {
      final resolved = FoodImageResolver.resolve('Chicken Tikka');
      expect(resolved, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=600&q=80');
    });

    // 5. Tandoori Chicken resolves correctly to Unsplash
    test('Tandoori Chicken resolves correctly to Unsplash', () {
      final resolved = FoodImageResolver.resolve('Tandoori Chicken');
      expect(resolved, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=600&q=80');
    });

    // 6. Mutton Biryani resolves correctly to Unsplash
    test('Mutton Biryani resolves correctly to Unsplash', () {
      final resolved = FoodImageResolver.resolve('Mutton Biryani');
      expect(resolved, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80');
    });

    // 7. Missing image returns safe fallback
    test('Missing image/empty string returns empty string', () {
      final resolved = FoodImageResolver.resolve('');
      expect(resolved, '');

      final resolvedNull = FoodImageResolver.resolve(null);
      expect(resolvedNull, '');
    });

    // 8. Different foods never resolve to the same unrelated image
    test('Different foods never resolve to the same unrelated image', () {
      final p1 = FoodImageResolver.resolve('Paneer Tikka');
      final p2 = FoodImageResolver.resolve('Mutton Biryani');
      expect(p1 != p2, isTrue);
    });
  });
}
