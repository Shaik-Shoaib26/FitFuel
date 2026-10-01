class RecommendationReasonEntity {
  final String title;
  final String description;
  final int scoreContribution;

  const RecommendationReasonEntity({
    required this.title,
    required this.description,
    required this.scoreContribution,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationReasonEntity &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description &&
          scoreContribution == other.scoreContribution;

  @override
  int get hashCode =>
      title.hashCode ^ description.hashCode ^ scoreContribution.hashCode;
}
