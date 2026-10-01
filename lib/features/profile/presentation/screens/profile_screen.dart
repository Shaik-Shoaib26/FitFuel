import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = ref.watch(authStateStreamProvider).value;
    final profileAsync = ref.watch(currentProfileStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('My Health Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            final displayName = (profile?.displayName != null &&
                    profile!.displayName!.isNotEmpty)
                ? profile.displayName!
                : (authUser?.displayName ?? 'FitFuel User');
            final email =
                profile?.email ?? authUser?.email ?? 'user@fitfuel.app';
            final initial =
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F';

            final age =
                profile?.age != null ? '${profile!.age} yrs' : 'Not set';
            final gender = (profile?.gender ?? 'Not set').toUpperCase();
            final height = profile?.height != null
                ? '${profile!.height!.toStringAsFixed(0)} cm'
                : 'Not set';
            final weight = profile?.weight != null
                ? '${profile!.weight!.toStringAsFixed(1)} kg'
                : 'Not set';
            final activityLevel = profile?.activityLevel ?? 'Moderate Activity';
            final fitnessGoal = profile?.fitnessGoal ?? 'Maintain Weight';
            final dietaryPref = profile?.dietaryPreference ?? 'Any / None';

            final goals = goalsAsync.value;
            final calorieTarget = goals?.dailyCalorieTarget ?? 2000;
            final proteinTarget = goals?.proteinTargetGrams ?? 150.0;
            final carbsTarget = goals?.carbsTargetGrams ?? 200.0;
            final fatTarget = goals?.fatTargetGrams ?? 65.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Avatar Header Card
                  FitFuelCard(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary100,
                          child: Text(
                            initial,
                            style: AppTypography.displayMedium(isDark: false)
                                .copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        Text(
                          displayName,
                          style: AppTypography.heading1(isDark: isDark),
                        ),
                        Text(
                          email,
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary500.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primary500.withAlpha(50)),
                          ),
                          child: Text(
                            'Goal: $fitnessGoal',
                            style: const TextStyle(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceMd),

                  // Health Profile Metrics Grid Card
                  FitFuelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Body Metrics',
                          style: AppTypography.heading3(isDark: isDark),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        Row(
                          children: [
                            Expanded(
                                child: _buildMetricTile('Age', age, isDark)),
                            Expanded(
                                child:
                                    _buildMetricTile('Gender', gender, isDark)),
                          ],
                        ),
                        const Divider(height: AppConstants.spaceMd),
                        Row(
                          children: [
                            Expanded(
                                child:
                                    _buildMetricTile('Height', height, isDark)),
                            Expanded(
                                child:
                                    _buildMetricTile('Weight', weight, isDark)),
                          ],
                        ),
                        const Divider(height: AppConstants.spaceMd),
                        _buildMetricTile(
                            'Activity Level', activityLevel, isDark),
                        const SizedBox(height: AppConstants.spaceSm),
                        _buildMetricTile(
                            'Dietary Preference', dietaryPref, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceMd),

                  // Daily Nutrition Targets Breakdown Card
                  FitFuelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Macro Targets',
                          style: AppTypography.heading3(isDark: isDark),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMacroTargetCol('Calories',
                                '$calorieTarget kcal', AppColors.calories),
                            _buildMacroTargetCol(
                                'Protein',
                                '${proteinTarget.toStringAsFixed(0)}g',
                                AppColors.protein),
                            _buildMacroTargetCol(
                                'Carbs',
                                '${carbsTarget.toStringAsFixed(0)}g',
                                AppColors.carbs),
                            _buildMacroTargetCol(
                                'Fats',
                                '${fatTarget.toStringAsFixed(0)}g',
                                AppColors.fat),
                          ],
                        ),
                      ],
                    ),
                  ),
                   const SizedBox(height: AppConstants.spaceLg),

                   // Settings Navigation Section
                   const FitFuelSectionHeader(
                     title: 'Settings',
                     subtitle: 'Configure your preferences and accounts.',
                   ),
                   const SizedBox(height: AppConstants.spaceSm),
                   _buildSettingsTile(
                     context: context,
                     icon: Icons.tune,
                     title: 'Health Profile & Goals',
                     subtitle: 'Body metrics, activity and targets',
                     onTap: () => context.push('/settings/goals'),
                     isDark: isDark,
                   ),
                   const SizedBox(height: AppConstants.spaceSm),
                   _buildSettingsTile(
                     context: context,
                     icon: Icons.palette_outlined,
                     title: 'Preferences',
                     subtitle: 'Appearance and device settings',
                     onTap: () => context.push('/settings/preferences'),
                     isDark: isDark,
                   ),
                   const SizedBox(height: AppConstants.spaceSm),
                   _buildSettingsTile(
                     context: context,
                     icon: Icons.notifications_outlined,
                     title: 'Reminders',
                     subtitle: 'Daily routine and notification times',
                     onTap: () => context.push('/settings/reminders'),
                     isDark: isDark,
                   ),
                   const SizedBox(height: AppConstants.spaceSm),
                   _buildSettingsTile(
                     context: context,
                     icon: Icons.manage_accounts_outlined,
                     title: 'Account',
                     subtitle: 'Sign out and account management',
                     onTap: () => context.push('/settings/account'),
                     isDark: isDark,
                   ),
                 ],
               ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading profile: $err')),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroTargetCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceSm),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorderSubtle
                : AppColors.lightBorderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
