class AnalyticsTrendEngine {
  static String calculateTrend({
    required List<double> values,
    double threshold = 0.0,
    bool lowerIsBetter = false,
  }) {
    if (values.length < 2) return 'Insufficient';

    final halfLength = values.length ~/ 2;
    final firstHalf = values.sublist(0, halfLength);
    final secondHalf = values.sublist(values.length - halfLength);

    if (firstHalf.isEmpty || secondHalf.isEmpty) return 'Insufficient';

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    final difference = secondAvg - firstAvg;

    if (lowerIsBetter) {
      if (difference < -threshold) {
        return 'Improving';
      } else if (difference > threshold) {
        return 'Declining';
      } else {
        return 'Stable';
      }
    } else {
      if (difference > threshold) {
        return 'Improving';
      } else if (difference < -threshold) {
        return 'Declining';
      } else {
        return 'Stable';
      }
    }
  }

  static String calculateWeightTrend({
    required double? startingWeight,
    required double? currentWeight,
    required String goal,
  }) {
    if (startingWeight == null || currentWeight == null) return 'Insufficient';

    final diff = currentWeight - startingWeight;
    final goalLower = goal.toLowerCase();

    if (goalLower.contains('lose') || goalLower.contains('reduction')) {
      // Lose weight: decreasing weight is Improving
      if (diff < -0.5) return 'Improving';
      if (diff > 0.5) return 'Declining';
      return 'Stable';
    } else if (goalLower.contains('gain') || goalLower.contains('muscle')) {
      // Gain weight/muscle: increasing weight is Improving
      if (diff > 0.5) return 'Improving';
      if (diff < -0.5) return 'Declining';
      return 'Stable';
    } else {
      // Maintain weight: small change is Stable
      if (diff.abs() <= 1.0) return 'Stable';
      return 'Declining';
    }
  }
}
