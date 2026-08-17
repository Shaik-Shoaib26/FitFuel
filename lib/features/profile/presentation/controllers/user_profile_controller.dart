import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/utils/tdee_calculator.dart';
import '../../domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../providers/profile_providers.dart';

abstract class UserProfileState {
  const UserProfileState();
}

class UserProfileInitialState extends UserProfileState {
  const UserProfileInitialState();
}

class UserProfileLoadingState extends UserProfileState {
  const UserProfileLoadingState();
}

class UserProfileLoadedState extends UserProfileState {
  final UserProfileEntity profile;
  const UserProfileLoadedState(this.profile);
}

class UserProfileErrorState extends UserProfileState {
  final String message;
  const UserProfileErrorState(this.message);
}

class UserProfileController extends StateNotifier<UserProfileState> {
  final IProfileRepository _repository;

  UserProfileController(this._repository) : super(const UserProfileInitialState());

  Future<void> loadProfile(String uid) async {
    state = const UserProfileLoadingState();
    try {
      LoggerService.info('UserProfileController: Loading profile for UID: $uid');
      final profile = await _repository.getProfile(uid);
      if (profile != null) {
        state = UserProfileLoadedState(profile);
      } else {
        state = const UserProfileErrorState('User profile not found in Firestore.');
      }
    } on Failure catch (e) {
      LoggerService.error('UserProfileController error loading profile: ${e.message}');
      state = UserProfileErrorState(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('UserProfileController unexpected error loading profile', e, stackTrace);
      state = const UserProfileErrorState('Unexpected error loading profile.');
    }
  }

  Future<bool> updateProfile(UserProfileEntity profile) async {
    state = const UserProfileLoadingState();
    try {
      LoggerService.info('UserProfileController: Updating profile for UID: ${profile.uid}');
      await _repository.updateProfile(profile);

      // Automatically recalculate and save goals if profile is complete
      if (profile.age != null &&
          profile.gender != null &&
          profile.height != null &&
          profile.weight != null &&
          profile.activityLevel != null &&
          profile.fitnessGoal != null) {
        
        final bmr = TDEECalculator.calculateBMR(
          weightKg: profile.weight!,
          heightCm: profile.height!,
          age: profile.age!,
          gender: profile.gender!,
        );

        final tdee = TDEECalculator.calculateTDEE(
          bmr: bmr,
          activityLevel: profile.activityLevel!,
        );

        final calories = TDEECalculator.calculateCalorieTarget(
          tdee: tdee,
          goal: profile.fitnessGoal!,
        );

        final macros = TDEECalculator.calculateMacroTargets(
          calorieTarget: calories,
          weightKg: profile.weight!,
        );

        final goals = NutritionGoalsEntity(
          userId: profile.uid,
          dailyCalorieTarget: calories,
          proteinTargetGrams: macros['proteinGrams'] ?? 150.0,
          carbsTargetGrams: macros['carbsGrams'] ?? 200.0,
          fatTargetGrams: macros['fatGrams'] ?? 65.0,
          updatedAt: DateTime.now(),
        );

        LoggerService.info('UserProfileController: Recalculated daily target: $calories kcal. Saving goals.');
        await _repository.saveGoals(profile.uid, goals);
      }

      state = UserProfileLoadedState(profile);
      return true;
    } on Failure catch (e) {
      LoggerService.error('UserProfileController error updating profile: ${e.message}');
      state = UserProfileErrorState(e.message);
      return false;
    } catch (e, stackTrace) {
      LoggerService.error('UserProfileController unexpected error updating profile', e, stackTrace);
      state = const UserProfileErrorState('Unexpected error updating profile.');
      return false;
    }
  }
}

final userProfileControllerProvider =
    StateNotifierProvider<UserProfileController, UserProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return UserProfileController(repository);
});
