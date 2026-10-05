import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_image_picker_service_impl.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';

final foodImagePickerServiceProvider =
    Provider<IFoodImagePickerService>((ref) => FoodImagePickerServiceImpl());

final foodScanRemoteDatasourceProvider =
    Provider<IFoodScanRemoteDataSource>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  return FoodScanRemoteDataSource(apiKey: apiKey);
});

final foodScanRepositoryProvider = Provider<IFoodScanRepository>((ref) {
  final remote = ref.watch(foodScanRemoteDatasourceProvider);
  return FoodScanRepositoryImpl(remoteDataSource: remote);
});

final foodScanControllerProvider =
    StateNotifierProvider.autoDispose<FoodScanController, FoodScanState>((ref) {
  final repository = ref.watch(foodScanRepositoryProvider);
  final picker = ref.watch(foodImagePickerServiceProvider);
  return FoodScanController(
    repository: repository,
    imagePickerService: picker,
  );
});
