import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../domain/entities/health_record_entity.dart';
import '../../domain/repositories/i_health_repository.dart';

final healthRemoteDataSourceProvider = Provider<IHealthRemoteDataSource>((ref) {
  return HealthRemoteDataSourceImpl();
});

final healthRepositoryProvider = Provider<IHealthRepository>((ref) {
  final dataSource = ref.watch(healthRemoteDataSourceProvider);
  return HealthRepositoryImpl(dataSource);
});

final healthStreamProvider = StreamProvider<List<HealthRecordEntity>>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value([]);
  }
  final repository = ref.watch(healthRepositoryProvider);
  return repository.streamAllRecords(authUser.uid);
});

final todayHealthRecordProvider = Provider<HealthRecordEntity?>((ref) {
  final records = ref.watch(healthStreamProvider).value ?? [];
  final todayStr = DateTime.now().toString().split(' ').first; // yyyy-MM-dd
  try {
    return records.firstWhere((r) => r.date == todayStr);
  } catch (_) {
    return null;
  }
});
