class GroceryCategoryEntity {
  static const List<String> categories = [
    'Fruits',
    'Vegetables',
    'Grains',
    'Pulses',
    'Dairy',
    'Eggs',
    'Meat',
    'Seafood',
    'Snacks',
    'Nuts & Seeds',
    'Spices',
    'Oils',
    'Beverages',
    'Other'
  ];

  static String fromFoodCategory(String foodCategory) {
    final lower = foodCategory.toLowerCase().trim();
    if (lower.contains('fruit')) return 'Fruits';
    if (lower.contains('vegetable') || lower.contains('veg')) return 'Vegetables';
    if (lower.contains('grain') || lower.contains('rice') || lower.contains('bread') || lower.contains('oats') || lower.contains('roti')) return 'Grains';
    if (lower.contains('pulse') || lower.contains('dal') || lower.contains('lentil') || lower.contains('chana') || lower.contains('bean')) return 'Pulses';
    if (lower.contains('dairy') || lower.contains('milk') || lower.contains('curd') || lower.contains('yogurt') || lower.contains('cheese') || lower.contains('paneer')) return 'Dairy';
    if (lower.contains('egg')) return 'Eggs';
    if (lower.contains('meat') || lower.contains('chicken') || lower.contains('beef') || lower.contains('mutton') || lower.contains('turkey')) return 'Meat';
    if (lower.contains('seafood') || lower.contains('fish') || lower.contains('salmon') || lower.contains('shrimp')) return 'Seafood';
    if (lower.contains('snack') || lower.contains('biscuit') || lower.contains('poha') || lower.contains('upma') || lower.contains('idli') || lower.contains('dosa')) return 'Snacks';
    if (lower.contains('nut') || lower.contains('seed') || lower.contains('almond') || lower.contains('walnut') || lower.contains('chia')) return 'Nuts & Seeds';
    if (lower.contains('spice') || lower.contains('turmeric') || lower.contains('pepper') || lower.contains('cumin') || lower.contains('salt') || lower.contains('chili')) return 'Spices';
    if (lower.contains('oil') || lower.contains('butter') || lower.contains('ghee')) return 'Oils';
    if (lower.contains('beverage') || lower.contains('drink') || lower.contains('tea') || lower.contains('coffee') || lower.contains('juice') || lower.contains('water')) return 'Beverages';
    return 'Other';
  }

  static String getEmoji(String category) {
    switch (category) {
      case 'Fruits':
        return '🍎';
      case 'Vegetables':
        return '🥬';
      case 'Grains':
        return '🌾';
      case 'Pulses':
        return '🍲';
      case 'Dairy':
        return '🥛';
      case 'Eggs':
        return '🥚';
      case 'Meat':
        return '🍗';
      case 'Seafood':
        return '🐟';
      case 'Snacks':
        return '🍪';
      case 'Nuts & Seeds':
        return '🥜';
      case 'Spices':
        return '🌶️';
      case 'Oils':
        return '🛢️';
      case 'Beverages':
        return '🥤';
      default:
        return '📦';
    }
  }
}
