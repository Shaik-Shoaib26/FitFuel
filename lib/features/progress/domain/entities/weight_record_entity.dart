class WeightRecordEntity {
  final String id;
  final double weight;
  final DateTime recordedAt;

  const WeightRecordEntity({
    required this.id,
    required this.weight,
    required this.recordedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightRecordEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          weight == other.weight &&
          recordedAt == other.recordedAt;

  @override
  int get hashCode => id.hashCode ^ weight.hashCode ^ recordedAt.hashCode;
}
