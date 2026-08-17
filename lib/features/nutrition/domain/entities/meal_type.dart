/// Canonical meal type enum for FitFuel.
///
/// This is the SINGLE SOURCE OF TRUTH for all meal type values
/// across the entire application. Every dropdown, form, planner,
/// and logger must use these values.
enum MealType {
  breakfast('Breakfast'),
  morningSnack('Morning Snack'),
  lunch('Lunch'),
  eveningSnack('Evening Snack'),
  dinner('Dinner');

  /// The display label for this meal type (e.g., 'Evening Snack').
  final String displayName;

  const MealType(this.displayName);

  /// Returns the ordered list of all display names.
  static List<String> get displayNames =>
      MealType.values.map((t) => t.displayName).toList();

  /// Parses a string into a [MealType].
  ///
  /// Matches case-insensitively against [displayName].
  /// Falls back to the legacy value 'Snack' by mapping it to
  /// [MealType.eveningSnack]. Returns [fallback] if no match.
  static MealType fromString(String value, {MealType fallback = MealType.breakfast}) {
    final lower = value.trim().toLowerCase();
    for (final type in MealType.values) {
      if (type.displayName.toLowerCase() == lower) {
        return type;
      }
    }
    // Legacy compatibility: old logs stored 'Snack' instead of
    // 'Morning Snack' or 'Evening Snack'.
    if (lower == 'snack' || lower == 'snacks') {
      return MealType.eveningSnack;
    }
    return fallback;
  }

  /// Returns true if [value] is a recognized meal type string.
  static bool isValid(String value) {
    final lower = value.trim().toLowerCase();
    return MealType.values.any((t) => t.displayName.toLowerCase() == lower) ||
        lower == 'snack' ||
        lower == 'snacks';
  }

  /// Validates and normalizes a meal type string.
  ///
  /// If [value] matches a known meal type, returns its canonical
  /// display name. Otherwise returns 'Breakfast'.
  static String normalize(String value) {
    return fromString(value).displayName;
  }
}
