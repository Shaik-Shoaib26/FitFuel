import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/sync/sync_status.dart';
import '../../domain/entities/weight_record_entity.dart';

class WeightRecordModel {
  final String id;
  final double weight;
  final DateTime recordedAt;
  final SyncStatus syncStatus;

  const WeightRecordModel({
    required this.id,
    required this.weight,
    required this.recordedAt,
    this.syncStatus = SyncStatus.synced,
  });

  factory WeightRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final recordedAtData = data['recordedAt'];
    DateTime parsedRecordedAt = DateTime.now();
    if (recordedAtData is Timestamp) {
      parsedRecordedAt = recordedAtData.toDate();
    } else if (recordedAtData is String) {
      parsedRecordedAt = DateTime.tryParse(recordedAtData) ?? DateTime.now();
    }

    return WeightRecordModel(
      id: doc.id,
      weight: (data['weight'] as num? ?? 0.0).toDouble(),
      recordedAt: parsedRecordedAt,
      syncStatus: doc.metadata.hasPendingWrites ? SyncStatus.pending : SyncStatus.synced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'weight': weight,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  factory WeightRecordModel.fromEntity(WeightRecordEntity entity) {
    return WeightRecordModel(
      id: entity.id,
      weight: entity.weight,
      recordedAt: entity.recordedAt,
      syncStatus: entity.syncStatus,
    );
  }

  WeightRecordEntity toEntity() {
    return WeightRecordEntity(
      id: id,
      weight: weight,
      recordedAt: recordedAt,
      syncStatus: syncStatus,
    );
  }
}
