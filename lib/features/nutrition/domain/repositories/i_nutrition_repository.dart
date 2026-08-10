import '../entities/nutrition_record_entity.dart';

abstract class INutritionRepository {
  Future<void> addRecord(String uid, NutritionRecordEntity record);
  Future<List<NutritionRecordEntity>> getRecords(String uid);
  Stream<List<NutritionRecordEntity>> streamRecords(String uid);
  Future<void> updateRecord(String uid, NutritionRecordEntity record);
  Future<void> deleteRecord(String uid, String recordId);
}
