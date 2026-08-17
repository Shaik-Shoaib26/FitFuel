import '../entities/health_record_entity.dart';

abstract class IHealthRepository {
  Future<void> saveRecord(String uid, HealthRecordEntity record);
  Future<HealthRecordEntity?> getRecord(String uid, String date);
  Stream<HealthRecordEntity?> streamRecord(String uid, String date);
  Stream<List<HealthRecordEntity>> streamAllRecords(String uid);
}
