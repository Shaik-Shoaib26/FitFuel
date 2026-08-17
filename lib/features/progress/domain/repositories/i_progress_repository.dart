import '../entities/weight_record_entity.dart';

abstract class IProgressRepository {
  Future<void> addWeight(String uid, double weight, DateTime recordedAt);
  Future<List<WeightRecordEntity>> getWeightHistory(String uid);
  Stream<List<WeightRecordEntity>> streamWeightHistory(String uid);
}
