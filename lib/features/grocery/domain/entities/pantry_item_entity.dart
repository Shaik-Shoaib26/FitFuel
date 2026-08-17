class PantryItemEntity {
  final String id;
  final String? foodId;
  final String foodName;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final String? imageUrl;
  final DateTime addedAt;

  const PantryItemEntity({
    required this.id,
    this.foodId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    this.imageUrl,
    required this.addedAt,
  });

  String getExpiryStatus([DateTime? referenceDate]) {
    final today = referenceDate ?? DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final expiryStart = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final difference = expiryStart.difference(todayStart).inDays;

    if (difference < 0) {
      return '🔴 Expired';
    } else if (difference <= 3) {
      return '🟡 Expiring Soon';
    } else {
      return '🟢 Fresh';
    }
  }

  PantryItemEntity copyWith({
    String? id,
    String? foodId,
    String? foodName,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    String? imageUrl,
    DateTime? addedAt,
  }) {
    return PantryItemEntity(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
