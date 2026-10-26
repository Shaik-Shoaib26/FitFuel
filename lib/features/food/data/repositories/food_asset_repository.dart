import '../../domain/entities/food_entity.dart';

class RecipeIngredient {
  final String name;
  final double baseAmount;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.baseAmount,
    required this.unit,
  });

  RecipeIngredient scale(double multiplier) {
    return RecipeIngredient(
      name: name,
      baseAmount: baseAmount * multiplier,
      unit: unit,
    );
  }
}

class RecipeDetails {
  final String foodId;
  final String foodName;
  final String dietType; // vegetarian, nonVegetarian, vegan
  final String cuisine;
  final String difficulty;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int totalTimeMinutes;
  final double baseServings;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;

  const RecipeDetails({
    required this.foodId,
    required this.foodName,
    required this.dietType,
    required this.cuisine,
    required this.difficulty,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.totalTimeMinutes,
    required this.baseServings,
    required this.ingredients,
    required this.instructions,
  });

  RecipeDetails scale(double multiplier) {
    return RecipeDetails(
      foodId: foodId,
      foodName: foodName,
      dietType: dietType,
      cuisine: cuisine,
      difficulty: difficulty,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      totalTimeMinutes: totalTimeMinutes,
      baseServings: baseServings * multiplier,
      ingredients: ingredients.map((i) => i.scale(multiplier)).toList(),
      instructions: instructions,
    );
  }
}

class FoodAssetRepository {
  static final FoodAssetRepository instance = FoodAssetRepository._internal();

  FoodAssetRepository._internal();

  // Mapping foodId -> Food Image Asset
  static const Map<String, String> _imageMappings = {
    'predefined_idli': 'assets/images/foods/idli.png',
    'predefined_dosa': 'assets/images/foods/dosa.png',
    'predefined_masala_dosa': 'assets/images/foods/masala_dosa.png',
    'predefined_veg_biryani': 'assets/images/foods/veg_biryani.png',
    'predefined_chicken_biryani': 'assets/images/foods/chicken_biryani.png',
    'predefined_egg_biryani': 'assets/images/foods/egg_biryani.png',
    'predefined_mutton_biryani': 'assets/images/foods/mutton_biryani.png',
    'predefined_dal_tadka': 'assets/images/foods/dal_tadka.png',
    'predefined_paneer_bhurji': 'assets/images/foods/paneer_bhurji.png',
    'predefined_poha': 'assets/images/foods/poha.png',
    'predefined_chicken_tikka': 'assets/images/foods/chicken_tikka.png',
    'predefined_palak_paneer': 'assets/images/foods/palak_paneer.png',
    'predefined_paneer_tikka': 'assets/images/foods/paneer_tikka.png',
    'predefined_upma': 'assets/images/foods/upma.png',
    'predefined_rava_upma': 'assets/images/foods/rava_upma.png',
    'predefined_pongal': 'assets/images/foods/pongal.png',
    'predefined_chole_masala': 'assets/images/foods/chole_masala.png',
    'predefined_veg_pulao': 'assets/images/foods/veg_pulao.png',
    'predefined_curd_rice': 'assets/images/foods/curd_rice.png',
    'predefined_sambar': 'assets/images/foods/sambar.png',
    'predefined_chicken_curry': 'assets/images/foods/chicken_curry.png',
    'predefined_tandoori_chicken': 'assets/images/foods/tandoori_chicken.png',
    'predefined_egg_bhurji': 'assets/images/foods/egg_bhurji.png',
    'predefined_egg_omelette': 'assets/images/foods/egg_omelette.png',
    'predefined_fish_curry': 'assets/images/foods/fish_curry.png',
    'predefined_fish_fry': 'assets/images/foods/fish_fry.png',
    'predefined_mutton_curry': 'assets/images/foods/mutton_curry.png',
  };

  static Map<String, RecipeDetails> get recipes => _recipes;

  // Mapping foodId -> Unique Recipe Details
  static final Map<String, RecipeDetails> _recipes = {
    'predefined_idli': const RecipeDetails(
      foodId: 'predefined_idli',
      foodName: 'Idli',
      dietType: 'vegan',
      cuisine: 'South Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Rice & Urad Dal Batter', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Water for Steaming', baseAmount: 500.0, unit: 'ml'),
        RecipeIngredient(name: 'Oil (for greasing)', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Grease the idli moulds with a drop of oil.',
        'Pour batter into each mould slot gently.',
        'Steam in a closed pot or pressure cooker for 10-12 minutes.',
        'Let it cool briefly, de-mould with a spoon, and serve hot.',
      ],
    ),
    'predefined_dosa': const RecipeDetails(
      foodId: 'predefined_dosa',
      foodName: 'Plain Dosa',
      dietType: 'vegan',
      cuisine: 'South Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 10,
      cookTimeMinutes: 5,
      totalTimeMinutes: 15,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Dosa Fermented Batter', baseAmount: 120.0, unit: 'g'),
        RecipeIngredient(name: 'Ghee or Oil', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Water (for consistency)', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Heat a non-stick tawa on medium high.',
        'Pour a ladleful of batter in the center.',
        'Spread in a circular motion to make it thin and crispy.',
        'Drizzle oil/ghee around the edges.',
        'Cook until golden brown, fold, and serve immediately.',
      ],
    ),
    'predefined_masala_dosa': const RecipeDetails(
      foodId: 'predefined_masala_dosa',
      foodName: 'Masala Dosa',
      dietType: 'vegetarian',
      cuisine: 'South Indian',
      difficulty: 'Hard',
      prepTimeMinutes: 15,
      cookTimeMinutes: 10,
      totalTimeMinutes: 25,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Dosa Fermented Batter', baseAmount: 120.0, unit: 'g'),
        RecipeIngredient(name: 'Potato Masala Stuffing', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Ghee or Butter', baseAmount: 2.0, unit: 'tsp'),
      ],
      instructions: [
        'Pour dosa batter onto a hot tawa and spread circularly.',
        'Add butter/ghee and cook until base is crispy.',
        'Place potato stuffing in the center.',
        'Fold the dosa over the stuffing and serve hot with chutney.',
      ],
    ),
    'predefined_veg_biryani': const RecipeDetails(
      foodId: 'predefined_veg_biryani',
      foodName: 'Vegetable Biryani',
      dietType: 'vegetarian',
      cuisine: 'Indian Mughlai',
      difficulty: 'Hard',
      prepTimeMinutes: 20,
      cookTimeMinutes: 30,
      totalTimeMinutes: 50,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Basmati Rice', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Mixed Vegetables (Carrot, Peas, Beans)', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt/Curd', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Biryani Spices & Saffron', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Parboil Basmati rice with whole spices.',
        'Cook vegetables with yogurt and biryani masala spices.',
        'Layer the cooked vegetables and parboiled rice in a heavy pot.',
        'Seal and cook on low heat (Dum) for 20 minutes.',
      ],
    ),
    'predefined_chicken_biryani': const RecipeDetails(
      foodId: 'predefined_chicken_biryani',
      foodName: 'Chicken Biryani',
      dietType: 'nonVegetarian',
      cuisine: 'Indian Mughlai',
      difficulty: 'Hard',
      prepTimeMinutes: 30,
      cookTimeMinutes: 30,
      totalTimeMinutes: 60,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Basmati Rice', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Marinated Chicken Pieces', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt/Curd', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Ghee & Biryani Spices', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Marinate chicken pieces in curd, spices, ginger, and garlic.',
        'Wash and boil Basmati rice until 70% cooked.',
        'Sear marinated chicken in ghee inside a heavy pot.',
        'Layer the semi-cooked rice on top, garnish with fried onions, and cook on Dum.',
      ],
    ),
    'predefined_egg_biryani': const RecipeDetails(
      foodId: 'predefined_egg_biryani',
      foodName: 'Egg Biryani',
      dietType: 'vegetarian',
      cuisine: 'Indian Mughlai',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 20,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Basmati Rice', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Boiled Eggs', baseAmount: 2.0, unit: 'eggs'),
        RecipeIngredient(name: 'Onions & Biryani Spices', baseAmount: 1.0, unit: 'cup'),
        RecipeIngredient(name: 'Yogurt/Curd', baseAmount: 40.0, unit: 'g'),
      ],
      instructions: [
        'Hard boil eggs, shell them, and poke tiny holes.',
        'Sauté eggs with spices and onions.',
        'Layer parboiled rice with eggs and gravy.',
        'Dum cook for 15 minutes before serving.',
      ],
    ),
    'predefined_mutton_biryani': const RecipeDetails(
      foodId: 'predefined_mutton_biryani',
      foodName: 'Mutton Biryani',
      dietType: 'nonVegetarian',
      cuisine: 'Indian Hyderabadi',
      difficulty: 'Hard',
      prepTimeMinutes: 40,
      cookTimeMinutes: 50,
      totalTimeMinutes: 90,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Basmati Rice', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Tender Mutton Pieces', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt & Spices', baseAmount: 60.0, unit: 'g'),
        RecipeIngredient(name: 'Ghee & Fried Onions', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Marinate mutton for at least 2 hours to tenderize.',
        'Cook mutton in a pressure cooker with spices until tender.',
        'Assemble layers of cooked mutton and Basmati rice.',
        'Dum cook for 25 minutes.',
      ],
    ),
    'predefined_dal_tadka': const RecipeDetails(
      foodId: 'predefined_dal_tadka',
      foodName: 'Dal Tadka',
      dietType: 'vegetarian',
      cuisine: 'North Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Toor Dal (Arhar)', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Ghee or Oil', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Garlic, Cumin, Mustard Seeds', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Dried Red Chillies & Hing', baseAmount: 2.0, unit: 'pcs'),
      ],
      instructions: [
        'Boil yellow lentils (toor dal) with turmeric and salt.',
        'Heat ghee in a small tadka pan.',
        'Fry garlic, cumin, mustard seeds, and red chillies.',
        'Pour hot tempering over the cooked dal and garnish with coriander.',
      ],
    ),
    'predefined_paneer_bhurji': const RecipeDetails(
      foodId: 'predefined_paneer_bhurji',
      foodName: 'Paneer Bhurji',
      dietType: 'vegetarian',
      cuisine: 'North Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 10,
      totalTimeMinutes: 20,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Fresh Paneer (Crumpled)', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Onion & Tomato (Chopped)', baseAmount: 1.0, unit: 'cup'),
        RecipeIngredient(name: 'Green Chillies & Ginger', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Spices (Turmeric, Chilli Powder)', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Sauté onions, ginger, and green chillies in oil.',
        'Add tomatoes and cook until soft.',
        'Add spices followed by crumbled fresh paneer.',
        'Cook on low for 3-4 minutes, garnish, and serve.',
      ],
    ),
    'predefined_poha': const RecipeDetails(
      foodId: 'predefined_poha',
      foodName: 'Poha',
      dietType: 'vegan',
      cuisine: 'West Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 10,
      totalTimeMinutes: 20,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Flattened Rice (Poha)', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Peanuts', baseAmount: 1.5, unit: 'tbsp'),
        RecipeIngredient(name: 'Onions & Green Chillies', baseAmount: 0.5, unit: 'cup'),
        RecipeIngredient(name: 'Mustard Seeds & Curry Leaves', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Rinse poha in a colander until soft, set aside.',
        'Heat oil, fry peanuts until crunchy, remove and keep aside.',
        'Tadka mustard seeds, green chillies, curry leaves, and onions.',
        'Mix in turmeric, poha, peanuts, and salt. Warm through.',
      ],
    ),
    'predefined_chicken_tikka': const RecipeDetails(
      foodId: 'predefined_chicken_tikka',
      foodName: 'Chicken Tikka',
      dietType: 'nonVegetarian',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Chicken Breast Cubes', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt/Curd', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Ginger & Garlic Paste', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Tikka Masala Spices', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Lemon Juice', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Marinate chicken cubes with yogurt, spices, ginger-garlic paste, and lemon juice.',
        'Skewer the chicken pieces.',
        'Grill or roast in an oven/tandoor at 200°C for 15 minutes.',
        'Baste with oil/butter occasionally and serve hot.',
      ],
    ),
    'predefined_palak_paneer': const RecipeDetails(
      foodId: 'predefined_palak_paneer',
      foodName: 'Palak Paneer',
      dietType: 'vegetarian',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 15,
      totalTimeMinutes: 30,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Fresh Spinach (Palak)', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Paneer Cubes', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Onions & Tomato Puree', baseAmount: 0.5, unit: 'cup'),
        RecipeIngredient(name: 'Garlic & Garam Masala', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Blanch spinach leaves and blend into a smooth puree.',
        'Sauté onions, ginger, and garlic in oil.',
        'Add tomato puree and spices, cook until oil separates.',
        'Pour in spinach puree, paneer cubes, and simmer for 5 minutes.',
      ],
    ),
    'predefined_paneer_tikka': const RecipeDetails(
      foodId: 'predefined_paneer_tikka',
      foodName: 'Paneer Tikka',
      dietType: 'vegetarian',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Paneer Cubes', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Bell Peppers & Onions', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt/Curd', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Tikka Spices & Lemon', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Mix yogurt with tikka spices and lemon juice in a bowl.',
        'Gently fold in paneer cubes, onions, and bell pepper pieces.',
        'Skewer alternating paneer and vegetables.',
        'Grill in a pan or oven for 12-15 minutes until charred.',
      ],
    ),
    'predefined_upma': const RecipeDetails(
      foodId: 'predefined_upma',
      foodName: 'Upma',
      dietType: 'vegetarian',
      cuisine: 'South Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 15,
      totalTimeMinutes: 20,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Semolina (Rava)', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Onions & Green Chillies', baseAmount: 0.5, unit: 'cup'),
        RecipeIngredient(name: 'Ghee or Oil', baseAmount: 1.5, unit: 'tbsp'),
        RecipeIngredient(name: 'Mustard Seeds & Curry Leaves', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Dry roast semolina on medium flame until fragrant.',
        'Heat oil/ghee and sauté mustard seeds, dal, chillies, and onions.',
        'Add 2.5 cups of water and salt, bring to a boil.',
        'Slowly pour in roasted semolina, stirring constantly to prevent lumps. Simmer.',
      ],
    ),
    'predefined_pongal': const RecipeDetails(
      foodId: 'predefined_pongal',
      foodName: 'Ven Pongal',
      dietType: 'vegetarian',
      cuisine: 'South Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Rice', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Yellow Moong Dal', baseAmount: 40.0, unit: 'g'),
        RecipeIngredient(name: 'Ghee', baseAmount: 2.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Black Pepper & Cumin', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Pressure cook rice and moong dal together with turmeric and 4 cups of water.',
        'Heat ghee, fry pepper, cumin, ginger, and curry leaves.',
        'Pour this tempering over the mashed rice-dal mix.',
        'Stir well and serve hot with coconut chutney.',
      ],
    ),
    'predefined_chole_masala': const RecipeDetails(
      foodId: 'predefined_chole_masala',
      foodName: 'Chole Masala',
      dietType: 'vegan',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 25,
      totalTimeMinutes: 40,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Soaked Chickpeas', baseAmount: 120.0, unit: 'g'),
        RecipeIngredient(name: 'Onion & Tomato Puree', baseAmount: 1.0, unit: 'cup'),
        RecipeIngredient(name: 'Chole Masala Spices', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Ginger Garlic Paste', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Pressure cook soaked chickpeas until soft.',
        'Sauté onions and ginger-garlic paste in a pot.',
        'Add tomato puree and cook with chole spices.',
        'Mix in chickpeas, cook on simmer for 15 minutes.',
      ],
    ),
    'predefined_veg_pulao': const RecipeDetails(
      foodId: 'predefined_veg_pulao',
      foodName: 'Vegetable Pulao',
      dietType: 'vegetarian',
      cuisine: 'North Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Basmati Rice', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Assorted Vegetables', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Whole Biryani Spices', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Ghee', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Heat ghee and fry bay leaf, cloves, cardamom, and cinnamon.',
        'Add chopped vegetables and sauté for 3 minutes.',
        'Add washed rice, double the water volume, and salt.',
        'Cover and cook until rice grains are fluffy.',
      ],
    ),
    'predefined_curd_rice': const RecipeDetails(
      foodId: 'predefined_curd_rice',
      foodName: 'Curd Rice',
      dietType: 'vegetarian',
      cuisine: 'South Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 5,
      totalTimeMinutes: 15,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Boiled Soft Rice', baseAmount: 120.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt/Curd', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Milk (optional for freshness)', baseAmount: 2.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Mustard, Chillies & Curry Leaves', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Mash hot boiled rice and let it cool.',
        'Mix with curd, salt, and milk.',
        'Prepare tadka with mustard seeds, green chillies, curry leaves, and pour over rice.',
        'Serve chilled.',
      ],
    ),
    'predefined_sambar': const RecipeDetails(
      foodId: 'predefined_sambar',
      foodName: 'Sambar',
      dietType: 'vegan',
      cuisine: 'South Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 25,
      totalTimeMinutes: 40,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Toor Dal', baseAmount: 60.0, unit: 'g'),
        RecipeIngredient(name: 'Mixed Sambar Vegetables', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Tamarind Pulp', baseAmount: 1.5, unit: 'tbsp'),
        RecipeIngredient(name: 'Sambar Powder', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Cook toor dal in pressure cooker until soft.',
        'Boil vegetables in tamarind water with sambar powder.',
        'Mix in the mashed dal and simmer for 10 minutes.',
        'Temper with mustard, curry leaves, and hing in oil.',
      ],
    ),
    'predefined_chicken_curry': const RecipeDetails(
      foodId: 'predefined_chicken_curry',
      foodName: 'Home Style Chicken Curry',
      dietType: 'nonVegetarian',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 30,
      totalTimeMinutes: 45,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Chicken Pieces', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Onions & Tomatoes (Finely chopped)', baseAmount: 1.5, unit: 'cup'),
        RecipeIngredient(name: 'Indian Curry Spices', baseAmount: 1.5, unit: 'tbsp'),
        RecipeIngredient(name: 'Ginger & Garlic Paste', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Sauté chopped onions, ginger, and garlic paste until golden.',
        'Add tomatoes and dry spices, cook until tomato is mushy.',
        'Add chicken pieces, roast for 5 minutes, then add 1 cup water.',
        'Simmer covered until chicken is tender.',
      ],
    ),
    'predefined_tandoori_chicken': const RecipeDetails(
      foodId: 'predefined_tandoori_chicken',
      foodName: 'Tandoori Chicken',
      dietType: 'nonVegetarian',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 20,
      cookTimeMinutes: 20,
      totalTimeMinutes: 40,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Chicken Drumsticks', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Yogurt', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Kashmiri Chili Powder', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Garlic and Lemon Juice', baseAmount: 1.5, unit: 'tsp'),
      ],
      instructions: [
        'Make deep cuts in chicken drumsticks.',
        'Marinate in lime juice, salt, yogurt, and spices.',
        'Bake or grill at 220°C for 20 minutes.',
        'Brush with butter and serve hot with mint chutney.',
      ],
    ),
    'predefined_egg_bhurji': const RecipeDetails(
      foodId: 'predefined_egg_bhurji',
      foodName: 'Egg Bhurji',
      dietType: 'vegetarian',
      cuisine: 'North Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      totalTimeMinutes: 15,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Eggs (Whisked)', baseAmount: 2.0, unit: 'eggs'),
        RecipeIngredient(name: 'Onions and Tomatoes (Diced)', baseAmount: 0.5, unit: 'cup'),
        RecipeIngredient(name: 'Green Chillies & Coriander', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Spices', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Sauté onions, green chillies, and ginger in a pan.',
        'Add tomatoes and cook for 2 minutes.',
        'Pour whisked eggs, salt, and spices.',
        'Stir continuously to scramble eggs on medium heat until cooked.',
      ],
    ),
    'predefined_egg_omelette': const RecipeDetails(
      foodId: 'predefined_egg_omelette',
      foodName: 'Egg Omelette',
      dietType: 'vegetarian',
      cuisine: 'Indian Fusion',
      difficulty: 'Easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 5,
      totalTimeMinutes: 10,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Eggs', baseAmount: 2.0, unit: 'eggs'),
        RecipeIngredient(name: 'Onion & Green Chili (Finely chopped)', baseAmount: 2.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Butter or Oil', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Beat eggs with onions, chillies, salt, and pepper.',
        'Melt butter in a skillet on medium-low.',
        'Pour egg mix, swirl, cook until set on bottom.',
        'Flip omelette and cook remaining side for 1 minute.',
      ],
    ),
    'predefined_fish_curry': const RecipeDetails(
      foodId: 'predefined_fish_curry',
      foodName: 'Indian Fish Curry',
      dietType: 'nonVegetarian',
      cuisine: 'Indian Goan',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 20,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Fish Fillets (Kingfish/Surmai)', baseAmount: 180.0, unit: 'g'),
        RecipeIngredient(name: 'Coconut Milk', baseAmount: 100.0, unit: 'ml'),
        RecipeIngredient(name: 'Curry Spices & Kokum', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Tamarind Pulp', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Sauté onion paste, ginger, garlic, and Goan spices.',
        'Pour in tamarind pulp, coconut milk, and bring to boil.',
        'Add marinated fish fillets gently.',
        'Simmer for 8-10 minutes until fish is cooked. Serve with white rice.',
      ],
    ),
    'predefined_fish_fry': const RecipeDetails(
      foodId: 'predefined_fish_fry',
      foodName: 'Masala Fish Fry',
      dietType: 'nonVegetarian',
      cuisine: 'Indian Coastal',
      difficulty: 'Medium',
      prepTimeMinutes: 15,
      cookTimeMinutes: 10,
      totalTimeMinutes: 25,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Fish Steaks', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Red Chili & Turmeric Paste', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Semolina (for coating)', baseAmount: 2.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Coconut Oil', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Rub fish steaks with lemon juice, turmeric, salt, and red chili paste.',
        'Coat the fish lightly with dry semolina (rava).',
        'Shallow fry in hot coconut oil on both sides.',
        'Drain on paper towel and serve with lemon wedges.',
      ],
    ),
    'predefined_mutton_curry': const RecipeDetails(
      foodId: 'predefined_mutton_curry',
      foodName: 'Indian Mutton Curry',
      dietType: 'nonVegetarian',
      cuisine: 'North Indian',
      difficulty: 'Hard',
      prepTimeMinutes: 20,
      cookTimeMinutes: 45,
      totalTimeMinutes: 65,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Mutton Pieces', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Onion Puree', baseAmount: 1.0, unit: 'cup'),
        RecipeIngredient(name: 'Garam Masala and Whole Spices', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Yogurt', baseAmount: 40.0, unit: 'g'),
      ],
      instructions: [
        'Brown onions and whole spices in a pressure cooker.',
        'Add mutton pieces and fry (Bhuna) until meat changes color.',
        'Add ginger-garlic paste, tomatoes, and yogurt. Cook until oil separates.',
        'Pressure cook with 1 cup water for 15-20 minutes.',
      ],
    ),
    'predefined_oats': const RecipeDetails(
      foodId: 'predefined_oats',
      foodName: 'Oats (Rolled)',
      dietType: 'vegan',
      cuisine: 'Healthy Breakfast',
      difficulty: 'Easy',
      prepTimeMinutes: 2,
      cookTimeMinutes: 5,
      totalTimeMinutes: 7,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Rolled Oats', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Water or Milk', baseAmount: 200.0, unit: 'ml'),
        RecipeIngredient(name: 'Cinnamon Powder (optional)', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Fresh Berries or Sliced Banana (optional)', baseAmount: 30.0, unit: 'g'),
      ],
      instructions: [
        'Combine rolled oats and water or milk in a small saucepan over medium heat.',
        'Bring to a gentle simmer, stirring occasionally to prevent sticking.',
        'Cook for 3-5 minutes until the oats reach your desired creamy consistency.',
        'Remove from heat, transfer to a bowl, and top with fresh berries or cinnamon.',
      ],
    ),
    'predefined_canned_tuna': const RecipeDetails(
      foodId: 'predefined_canned_tuna',
      foodName: 'Canned Tuna (In Water)',
      dietType: 'nonVegetarian',
      cuisine: 'Healthy Quick Meal',
      difficulty: 'Easy',
      prepTimeMinutes: 3,
      cookTimeMinutes: 0,
      totalTimeMinutes: 3,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Canned Chunk Light Tuna (in water)', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Fresh Lemon Juice', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Cracked Black Pepper & Sea Salt', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Chopped Parsley or Celery', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Open the tuna can and thoroughly drain excess water using the lid or a strainer.',
        'Transfer the flaked tuna to a clean mixing bowl.',
        'Drizzle with fresh lemon juice and season with cracked black pepper and a pinch of sea salt.',
        'Toss gently with a fork and serve immediately over crisp salad greens or whole grain crackers.',
      ],
    ),
    'predefined_protein_bar': const RecipeDetails(
      foodId: 'predefined_protein_bar',
      foodName: 'Double Chocolate Protein Bar',
      dietType: 'vegetarian',
      cuisine: 'Fitness Snack',
      difficulty: 'Easy',
      prepTimeMinutes: 1,
      cookTimeMinutes: 0,
      totalTimeMinutes: 1,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Double Chocolate Protein Bar', baseAmount: 60.0, unit: 'g'),
        RecipeIngredient(name: 'Fresh Cold Water (for hydration)', baseAmount: 250.0, unit: 'ml'),
      ],
      instructions: [
        'Unwrap the double chocolate protein bar from its protective packaging.',
        'For an indulgent warm treat, microwave on a microwave-safe plate for 8-10 seconds until soft.',
        'Cut into bite-sized pieces if desired and enjoy as a convenient pre-workout or post-workout snack.',
      ],
    ),
    'predefined_whey_protein_shake': const RecipeDetails(
      foodId: 'predefined_whey_protein_shake',
      foodName: 'Whey Protein Shake',
      dietType: 'vegetarian',
      cuisine: 'Fitness Drink',
      difficulty: 'Easy',
      prepTimeMinutes: 2,
      cookTimeMinutes: 0,
      totalTimeMinutes: 2,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Whey Protein Powder', baseAmount: 30.0, unit: 'g'),
        RecipeIngredient(name: 'Cold Water or Low-Fat Milk', baseAmount: 250.0, unit: 'ml'),
        RecipeIngredient(name: 'Ice Cubes (optional)', baseAmount: 3.0, unit: 'pcs'),
      ],
      instructions: [
        'Pour 250ml of cold water or low-fat milk into a clean shaker bottle first to prevent clumping.',
        'Add one rounded scoop (30g) of whey protein powder on top of the liquid.',
        'Drop in ice cubes if desired, secure the shaker lid tightly, and shake vigorously for 20-30 seconds.',
        'Consume immediately post-workout or between meals for optimal protein absorption.',
      ],
    ),
    'predefined_egg_white_omelette': const RecipeDetails(
      foodId: 'predefined_egg_white_omelette',
      foodName: 'Egg White Omelette',
      dietType: 'nonVegetarian',
      cuisine: 'Fitness Breakfast',
      difficulty: 'Easy',
      prepTimeMinutes: 3,
      cookTimeMinutes: 5,
      totalTimeMinutes: 8,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Egg Whites (from 3-4 eggs)', baseAmount: 120.0, unit: 'g'),
        RecipeIngredient(name: 'Finely Chopped Spinach & Bell Peppers', baseAmount: 30.0, unit: 'g'),
        RecipeIngredient(name: 'Olive Oil or Cooking Spray', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Black Pepper & Sea Salt', baseAmount: 1.0, unit: 'pinch'),
      ],
      instructions: [
        'Separate egg whites into a bowl and whisk vigorously until lightly frothy.',
        'Heat a non-stick skillet over medium-low heat and lightly coat with cooking spray or olive oil.',
        'Pour whisked egg whites into the skillet and let the edges set undisturbed for 1-2 minutes.',
        'Evenly scatter chopped spinach, bell peppers, salt, and pepper across the surface.',
        'Gently fold the omelette in half using a silicone spatula and slide onto a warm plate to serve.',
      ],
    ),
    'predefined_low_fat_paneer': const RecipeDetails(
      foodId: 'predefined_low_fat_paneer',
      foodName: 'Low-Fat Paneer',
      dietType: 'vegetarian',
      cuisine: 'Indian Healthy',
      difficulty: 'Easy',
      prepTimeMinutes: 2,
      cookTimeMinutes: 4,
      totalTimeMinutes: 6,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Low-Fat Paneer Block', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Olive Oil Cooking Spray', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Chaat Masala or Crushed Black Pepper', baseAmount: 1.0, unit: 'pinch'),
        RecipeIngredient(name: 'Fresh Lemon Juice', baseAmount: 1.0, unit: 'tsp'),
      ],
      instructions: [
        'Cut the low-fat paneer block into 1-inch bite-sized cubes.',
        'Heat a non-stick pan over medium heat and lightly mist with cooking spray.',
        'Sear the paneer cubes gently for 1-2 minutes per side until lightly golden around the edges, or enjoy fresh and unheated.',
        'Transfer to a plate, dust with a pinch of chaat masala or black pepper, drizzle with lemon juice, and serve as a high-protein addition to your meal.',
      ],
    ),
    'predefined_chicken_salad': const RecipeDetails(
      foodId: 'predefined_chicken_salad',
      foodName: 'Healthy Chicken Salad',
      dietType: 'nonVegetarian',
      cuisine: 'Healthy Fitness',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 10,
      totalTimeMinutes: 20,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Boneless Skinless Chicken Breast (Cooked/Grilled)', baseAmount: 120.0, unit: 'g'),
        RecipeIngredient(name: 'Mixed Salad Greens (Romaine & Lettuce)', baseAmount: 60.0, unit: 'g'),
        RecipeIngredient(name: 'Diced Cucumber & Cherry Tomatoes', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Extra Virgin Olive Oil & Lemon Dressing', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Cracked Black Pepper & Sea Salt', baseAmount: 1.0, unit: 'pinch'),
      ],
      instructions: [
        'Grill or boil chicken breast with a pinch of salt and pepper until thoroughly cooked (internal temp 165°F / 74°C), then slice into strips.',
        'Wash and spin dry mixed salad greens, cucumber, and cherry tomatoes, then arrange in a wide salad bowl.',
        'Top the fresh vegetable base with the sliced warm or chilled chicken breast strips.',
        'Whisk fresh lemon juice, olive oil, and black pepper together in a small ramekin.',
        'Drizzle dressing evenly across the salad, toss gently, and serve immediately.',
      ],
    ),
    'predefined_couscous': const RecipeDetails(
      foodId: 'predefined_couscous',
      foodName: 'Couscous (Dry)',
      dietType: 'vegan',
      cuisine: 'Mediterranean',
      difficulty: 'Easy',
      prepTimeMinutes: 2,
      cookTimeMinutes: 5,
      totalTimeMinutes: 7,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Dry Couscous Grains', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Boiling Water or Vegetable Broth', baseAmount: 125.0, unit: 'ml'),
        RecipeIngredient(name: 'Extra Virgin Olive Oil', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Fine Sea Salt', baseAmount: 1.0, unit: 'pinch'),
      ],
      instructions: [
        'Measure dry couscous grains and place into a heatproof ceramic or glass bowl.',
        'Bring water or low-sodium vegetable broth to a rolling boil with olive oil and a pinch of salt.',
        'Pour the boiling liquid directly over the dry couscous, ensuring all grains are evenly submerged.',
        'Immediately cover tightly with a plate or lid and let stand undisturbed for 5 minutes to steam.',
        'Remove lid and fluff gently with a fork to separate the fluffy couscous grains before serving.',
      ],
    ),
    'predefined_protein_smoothie': const RecipeDetails(
      foodId: 'predefined_protein_smoothie',
      foodName: 'Banana Protein Smoothie',
      dietType: 'vegetarian',
      cuisine: 'Fitness Drink',
      difficulty: 'Easy',
      prepTimeMinutes: 3,
      cookTimeMinutes: 0,
      totalTimeMinutes: 3,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Ripe Banana (Fresh or Frozen)', baseAmount: 1.0, unit: 'medium'),
        RecipeIngredient(name: 'Whey or Plant Protein Powder (Vanilla)', baseAmount: 25.0, unit: 'g'),
        RecipeIngredient(name: 'Low-Fat Milk or Unsweetened Almond Milk', baseAmount: 200.0, unit: 'ml'),
        RecipeIngredient(name: 'Ice Cubes', baseAmount: 4.0, unit: 'pcs'),
        RecipeIngredient(name: 'Ground Cinnamon (optional)', baseAmount: 1.0, unit: 'pinch'),
      ],
      instructions: [
        'Peel and slice the ripe banana into manageable pieces.',
        'Add low-fat milk (or water) to the blender pitcher first to ensure smooth blending.',
        'Add sliced banana, protein powder, cinnamon, and ice cubes on top.',
        'Blend on high speed for 45-60 seconds until thick, frothy, and completely homogeneous.',
        'Pour immediately into a chilled glass and serve as a nutrient-packed pre-workout or post-workout shake.',
      ],
    ),
    'predefined_oats_bran': const RecipeDetails(
      foodId: 'predefined_oats_bran',
      foodName: 'Oats Bran',
      dietType: 'vegan',
      cuisine: 'Healthy Breakfast',
      difficulty: 'Easy',
      prepTimeMinutes: 2,
      cookTimeMinutes: 4,
      totalTimeMinutes: 6,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Raw Oat Bran', baseAmount: 50.0, unit: 'g'),
        RecipeIngredient(name: 'Water or Low-Fat Milk', baseAmount: 200.0, unit: 'ml'),
        RecipeIngredient(name: 'Ground Cinnamon', baseAmount: 1.0, unit: 'pinch'),
        RecipeIngredient(name: 'Sea Salt', baseAmount: 1.0, unit: 'pinch'),
      ],
      instructions: [
        'Combine raw oat bran, pinch of salt, and water or low-fat milk in a small saucepan.',
        'Bring the mixture to a gentle boil over medium heat, stirring continuously with a wooden spoon.',
        'Reduce heat to low and simmer for 2-3 minutes, stirring constantly until thick and creamy.',
        'Remove saucepan from heat and stir in a pinch of ground cinnamon.',
        'Transfer hot oat bran cereal to a bowl, let cool for 1 minute, and serve warm.',
      ],
    ),
    'predefined_almond_butter': const RecipeDetails(
      foodId: 'predefined_almond_butter',
      foodName: 'Almond Butter Pure',
      dietType: 'vegan',
      cuisine: 'Healthy Pantry',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      totalTimeMinutes: 25,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Raw Almonds', baseAmount: 300.0, unit: 'g'),
        RecipeIngredient(name: 'Sea Salt', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Neutral Oil (optional, if needed)', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Preheat oven to 160°C (320°F). Spread almonds on a baking sheet in a single layer.',
        'Roast almonds for 10-12 minutes until fragrant and lightly golden. Cool completely.',
        'Transfer cooled almonds to a high-speed blender or food processor.',
        'Blend on low speed until crumbly, then increase to high. Scrape sides every 30 seconds.',
        'Continue blending 10-15 minutes until natural oils release and butter becomes smooth.',
        'Add salt and optional oil only if needed for consistency. Blend briefly.',
        'Transfer to a clean jar. Store at room temperature up to 2 weeks or refrigerate longer.',
      ],
    ),
    'predefined_aloo_gobi': const RecipeDetails(
      foodId: 'predefined_aloo_gobi',
      foodName: 'Aloo Gobi',
      dietType: 'vegan',
      cuisine: 'North Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Potato (cubed)', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Cauliflower (florets)', baseAmount: 150.0, unit: 'g'),
        RecipeIngredient(name: 'Onion (chopped)', baseAmount: 1.0, unit: 'medium'),
        RecipeIngredient(name: 'Tomato (chopped)', baseAmount: 1.0, unit: 'medium'),
        RecipeIngredient(name: 'Ginger-Garlic Paste', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Turmeric Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Cumin Seeds', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Coriander Powder', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Garam Masala', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Salt', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Cooking Oil', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Heat oil in a pan. Add cumin seeds and let them splutter.',
        'Add chopped onions and sauté until golden brown.',
        'Add ginger-garlic paste and cook for 1 minute until raw smell disappears.',
        'Add tomatoes, turmeric, coriander powder, and salt. Cook until tomatoes break down.',
        'Add potato cubes and cauliflower florets. Mix well to coat with spices.',
        'Cover and cook on medium-low heat for 15-20 minutes, stirring occasionally.',
        'Sprinkle garam masala, mix gently, and cook uncovered for 2 minutes.',
        'Garnish with fresh coriander and serve hot with roti or rice.',
      ],
    ),
    'predefined_aloo_methi': const RecipeDetails(
      foodId: 'predefined_aloo_methi',
      foodName: 'Aloo Methi',
      dietType: 'vegan',
      cuisine: 'North Indian',
      difficulty: 'Easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Potato (cubed)', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Fresh Methi/Fenugreek Leaves (chopped)', baseAmount: 100.0, unit: 'g'),
        RecipeIngredient(name: 'Cumin Seeds', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Turmeric Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Red Chili Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Ginger-Garlic Paste (optional)', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Salt', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Cooking Oil', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Clean and chop methi leaves. Sprinkle salt, massage, and set aside for 10 minutes. Squeeze out excess water.',
        'Heat oil in a pan. Add cumin seeds and let them splutter.',
        'Add ginger-garlic paste (if using) and sauté for 30 seconds.',
        'Add potato cubes, turmeric, red chili powder, and salt. Mix well.',
        'Cover and cook on medium heat for 10 minutes until potatoes are half-cooked.',
        'Add squeezed methi leaves. Mix thoroughly.',
        'Cook uncovered on medium heat for 10-12 minutes until potatoes are tender and moisture evaporates.',
        'Adjust salt if needed. Serve dry with roti or paratha.',
      ],
    ),
    'predefined_aloo_paratha': const RecipeDetails(
      foodId: 'predefined_aloo_paratha',
      foodName: 'Aloo Paratha',
      dietType: 'vegan',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Whole Wheat Flour', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Water (for dough)', baseAmount: 100.0, unit: 'ml'),
        RecipeIngredient(name: 'Salt (for dough)', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Boiled Potato (mashed)', baseAmount: 200.0, unit: 'g'),
        RecipeIngredient(name: 'Cumin Seeds', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Coriander Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Red Chili Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Garam Masala', baseAmount: 0.25, unit: 'tsp'),
        RecipeIngredient(name: 'Amchur/Dry Mango Powder (optional)', baseAmount: 0.25, unit: 'tsp'),
        RecipeIngredient(name: 'Salt (for filling)', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Oil/Ghee (for cooking)', baseAmount: 2.0, unit: 'tbsp'),
      ],
      instructions: [
        'Knead whole wheat flour with water and salt into a soft, pliable dough. Rest 15 minutes.',
        'Mix mashed potato with cumin, coriander powder, chili powder, garam masala, amchur, and salt.',
        'Divide dough and filling into 4-5 equal portions.',
        'Roll each dough ball into a small circle. Place filling in center, seal edges, and reshape into a ball.',
        'Gently roll out stuffed ball into a 6-7 inch circle, dusting with flour as needed.',
        'Heat a tawa on medium-high. Place paratha and cook until bubbles form.',
        'Flip, apply oil/ghee, flip again, and apply oil/ghee on other side.',
        'Press gently with spatula and cook until golden brown spots appear on both sides.',
        'Serve hot with yogurt, pickle, or butter.',
      ],
    ),
    'predefined_grilled_fish_tikka': const RecipeDetails(
      foodId: 'predefined_grilled_fish_tikka',
      foodName: 'Amritsari Fish Tikka',
      dietType: 'nonVegetarian',
      cuisine: 'North Indian',
      difficulty: 'Medium',
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      totalTimeMinutes: 35,
      baseServings: 1.0,
      ingredients: [
        RecipeIngredient(name: 'Boneless Firm Fish (cut into 1.5-inch pieces)', baseAmount: 250.0, unit: 'g'),
        RecipeIngredient(name: 'Thick Yogurt/Curd', baseAmount: 80.0, unit: 'g'),
        RecipeIngredient(name: 'Ginger-Garlic Paste', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Lemon Juice', baseAmount: 1.0, unit: 'tbsp'),
        RecipeIngredient(name: 'Turmeric Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Red Chili Powder', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Cumin Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Coriander Powder', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Garam Masala', baseAmount: 0.5, unit: 'tsp'),
        RecipeIngredient(name: 'Salt', baseAmount: 1.0, unit: 'tsp'),
        RecipeIngredient(name: 'Mustard Oil or Oil (for grilling)', baseAmount: 1.0, unit: 'tbsp'),
      ],
      instructions: [
        'Pat fish pieces dry with paper towels. Place in a mixing bowl.',
        'In a separate bowl, whisk yogurt with ginger-garlic paste, lemon juice, and all dry spices.',
        'Coat fish pieces thoroughly with the marinade. Cover and refrigerate for 30-60 minutes.',
        'Preheat grill, oven (220°C/425°F), or heavy grill pan on medium-high.',
        'Thread marinated fish pieces onto skewers or place directly on greased grill pan.',
        'Grill for 6-8 minutes per side until cooked through and edges are charred.',
        'Brush with oil/mustard oil halfway through for moisture and flavor.',
        'Remove from heat. Squeeze fresh lemon juice over pieces and serve hot with mint chutney.',
      ],
    ),
  };

  // Safe image retrieval
  String getImage(String foodId) {
    final assetPath = _imageMappings[foodId];
    if (assetPath != null && assetPath.isNotEmpty) {
      return assetPath;
    }
    // Visually neutral FitFuel food placeholder tag
    return ''; 
  }

  // Safe recipe retrieval
  RecipeDetails? getRecipe(String foodId) {
    if (_recipes.containsKey(foodId)) return _recipes[foodId];
    if (!foodId.startsWith('predefined_')) {
      final prefixed = 'predefined_$foodId';
      if (_recipes.containsKey(prefixed)) return _recipes[prefixed];
    }
    return null;
  }

  // Retrieve scaled recipe details
  RecipeDetails? getScaledRecipe(String foodId, double servingsMultiplier) {
    final baseRecipe = _recipes[foodId];
    if (baseRecipe == null) return null;
    return baseRecipe.scale(servingsMultiplier);
  }

  // Automated validation for recipe-food relationships
  Map<String, List<String>> validateDatabase(List<FoodEntity> foods) {
    final errors = <String, List<String>>{
      'duplicate_ids': [],
      'missing_images': [],
      'missing_nutrition': [],
      'duplicate_recipes': [],
      'recipe_mismatch': [],
    };

    final seenIds = <String>{};
    for (final food in foods) {
      if (seenIds.contains(food.id)) {
        errors['duplicate_ids']!.add(food.id);
      }
      seenIds.add(food.id);

      final img = getImage(food.id);
      if (img.isEmpty && food.isIndian) {
        errors['missing_images']!.add(food.id);
      }

      if (food.calories <= 0 || food.protein < 0 || food.carbohydrates < 0 || food.fats < 0) {
        errors['missing_nutrition']!.add(food.id);
      }

      final recipe = getRecipe(food.id);
      if (recipe != null && recipe.foodId != food.id) {
        errors['recipe_mismatch']!.add(food.id);
      }
    }

    return errors;
  }
}
