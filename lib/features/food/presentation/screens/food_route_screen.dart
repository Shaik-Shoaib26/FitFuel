import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/food_entity.dart';
import '../providers/food_providers.dart';
import '../widgets/custom_food_form.dart';
import 'food_details_screen.dart';

final foodByIdProvider =
    FutureProvider.autoDispose.family<FoodEntity?, String>((ref, id) {
  ref.watch(authStateStreamProvider.select((state) => state.value?.uid));
  return ref.watch(foodRepositoryProvider).getFoodById(id);
});

class FoodRouteScreen extends ConsumerWidget {
  final String id;
  final bool editing;
  final bool showRecipe;
  const FoodRouteScreen(
      {super.key,
      required this.id,
      this.editing = false,
      this.showRecipe = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(foodByIdProvider(id)).when(
            data: (food) {
              if (food == null || (editing && !food.isCustom)) {
                return const Scaffold(
                    appBar: FitFuelAppBar(title: Text('Food unavailable')),
                    body: FitFuelEmptyState(
                        icon: Icons.no_food,
                        title: 'Food unavailable',
                        description:
                            'This food may have been removed or is not available to this account.'));
              }
              return editing
                  ? CustomFoodForm(existingFood: food)
                  : FoodDetailsScreen(food: food, showRecipe: showRecipe);
            },
            loading: () => const Scaffold(
                appBar: FitFuelAppBar(title: Text('Food')),
                body: Center(child: CircularProgressIndicator())),
            error: (error, _) => Scaffold(
                appBar: const FitFuelAppBar(title: Text('Food')),
                body: FitFuelErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(foodByIdProvider(id)))),
          );
}
