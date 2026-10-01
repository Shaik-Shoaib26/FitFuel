import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_nutrition_repository_impl.dart';
import '../../domain/repositories/ai_nutrition_repository.dart';
import '../controllers/ai_assistant_controller.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

final aiRepositoryProvider = Provider<IAiNutritionRepository>((ref) {
  return AiNutritionRepositoryImpl();
});

final aiAssistantControllerProvider = StateNotifierProvider<AiAssistantController, AiAssistantState>((ref) {
  // Watch auth UID to invalidate this controller and clear history on account changes
  ref.watch(authStateStreamProvider.select((user) => user.value?.uid));
  final repository = ref.watch(aiRepositoryProvider);
  return AiAssistantController(repository);
});
