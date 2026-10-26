import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_image_picker_service_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/data/services/open_vocabulary_model_asset_provider_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/siglip_open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/data/services/tflite_food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_feedback_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_model_asset_provider.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';

final foodImagePickerServiceProvider =
    Provider<IFoodImagePickerService>((ref) => FoodImagePickerServiceImpl());

final foodScanRemoteDatasourceProvider =
    Provider<IFoodScanRemoteDataSource>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  return FoodScanRemoteDataSource(apiKey: apiKey);
});

final foodVisionClassifierProvider = Provider<FoodVisionClassifier>((ref) {
  return TfliteFoodVisionClassifier();
});

final openVocabularyModelAssetProviderProvider =
    Provider<OpenVocabularyModelAssetProvider>((ref) {
  return PlatformOpenVocabularyModelAssetProvider();
});

final openVocabularyFoodRecognizerProvider =
    Provider<OpenVocabularyFoodRecognizer>((ref) {
  final assetProvider = ref.watch(openVocabularyModelAssetProviderProvider);
  final recognizer = SiglipOpenVocabularyFoodRecognizer(
    assetProvider: assetProvider,
  );
  ref.onDispose(() {
    recognizer.dispose();
  });
  return recognizer;
});

final foodScanRouterConfigProvider = Provider<FoodScanRouterConfig>((ref) {
  return kDefaultFoodScanRouterConfig;
});

final globalFoodVocabularyServiceProvider =
    Provider<GlobalFoodVocabularyService>((ref) {
  return GlobalFoodVocabularyService();
});

final universalNutritionResolverProvider =
    Provider<UniversalNutritionResolver>((ref) {
  return UniversalNutritionResolver();
});

final foodFeedbackServiceProvider =
    Provider<FoodFeedbackService>((ref) {
  return FoodFeedbackService();
});

final foodScanRecognitionRouterProvider =
    Provider<FoodScanRecognitionRouter>((ref) {
  final localClassifier = ref.watch(foodVisionClassifierProvider);
  final openVocabRecognizer = ref.watch(openVocabularyFoodRecognizerProvider);
  final remote = ref.watch(foodScanRemoteDatasourceProvider);
  final config = ref.watch(foodScanRouterConfigProvider);
  final resolver = ref.watch(universalNutritionResolverProvider);
  return FoodScanRecognitionRouter(
    localClassifier: localClassifier,
    openVocabularyRecognizer: openVocabRecognizer,
    remoteDataSource: remote,
    config: config,
    universalNutritionResolver: resolver,
  );
});

final foodScanRepositoryProvider = Provider<IFoodScanRepository>((ref) {
  final remote = ref.watch(foodScanRemoteDatasourceProvider);
  final router = ref.watch(foodScanRecognitionRouterProvider);
  return FoodScanRepositoryImpl(
    remoteDataSource: remote,
    router: router,
  );
});

final foodScanControllerProvider =
    StateNotifierProvider.autoDispose<FoodScanController, FoodScanState>((ref) {
  final repository = ref.watch(foodScanRepositoryProvider);
  final picker = ref.watch(foodImagePickerServiceProvider);
  final resolver = ref.watch(universalNutritionResolverProvider);
  final vocabulary = ref.watch(globalFoodVocabularyServiceProvider);
  final feedback = ref.watch(foodFeedbackServiceProvider);
  return FoodScanController(
    repository: repository,
    imagePickerService: picker,
    universalNutritionResolver: resolver,
    globalFoodVocabularyService: vocabulary,
    foodFeedbackService: feedback,
  );
});
