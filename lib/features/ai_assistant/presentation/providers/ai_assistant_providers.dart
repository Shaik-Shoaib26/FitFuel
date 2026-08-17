import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_nutrition_repository_impl.dart';
import '../../domain/repositories/ai_nutrition_repository.dart';
import '../controllers/ai_assistant_controller.dart';

final aiRepositoryProvider = Provider<IAiNutritionRepository>((ref) {
  return AiNutritionRepositoryImpl();
});

final aiAssistantControllerProvider = StateNotifierProvider<AiAssistantController, AiAssistantState>((ref) {
  final repository = ref.watch(aiRepositoryProvider);
  return AiAssistantController(repository);
});
