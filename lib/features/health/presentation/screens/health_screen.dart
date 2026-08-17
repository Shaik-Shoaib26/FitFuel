import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/health_record_entity.dart';
import '../../domain/utils/wellness_calculator.dart';
import '../controllers/health_controller.dart';
import '../providers/health_providers.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthAsync = ref.watch(healthStreamProvider);
    final nutritionAsync = ref.watch(nutritionStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Wellness & Habits'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: healthAsync.when(
          data: (records) {
            final todayStr = DateTime.now().toString().split(' ').first;
            final record = WellnessCalculator.filterByDate(records, todayStr) ??
                HealthRecordEntity.empty(todayStr);

            return nutritionAsync.when(
              data: (nutritionRecords) {
                final todayCals = NutritionCalculator.filterByDay(nutritionRecords, DateTime.now());
                final bool hasLoggedFood = todayCals.isNotEmpty;

                final double score = WellnessCalculator.calculateScore(
                  hasLoggedFoodToday: hasLoggedFood,
                  healthRecord: record,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Wellness score header card
                      _buildScoreHeaderCard(score, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 2. Water intake tracking card
                      _buildWaterCard(context, ref, record, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 3. Exercise activity tracker card
                      _buildExerciseCard(context, ref, record, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 4. Daily Habits list card
                      _buildHabitsCard(ref, record, isDark),
                      const SizedBox(height: AppConstants.spaceLg),

                      // Professional medical disclaimer
                      Center(
                        child: Text(
                          '*Disclaimer: Wellness score statistics are approximate. Encourage seeking certified medical advice.*',
                          style: AppTypography.caption(isDark: isDark),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildErrorCard('Error loading nutrition: $error'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorCard('Error loading health: $error'),
          ),
        ),
      );
    }

  Widget _buildScoreHeaderCard(double score, bool isDark) {
    return GlassmorphicContainer(
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 8,
                  backgroundColor: AppColors.darkTextMuted.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary500),
                ),
              ),
              Text(
                score.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Wellness Score',
                  style: AppTypography.heading3(isDark: isDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'Calculated based on today\'s logged foods, hydration progress, exercises, and habits completed.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextMuted : AppColors.darkTextMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(BuildContext context, WidgetRef ref, HealthRecordEntity record, bool isDark) {
    final progressVal = record.waterTargetMl > 0 ? (record.waterIntakeMl / record.waterTargetMl) : 0.0;

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.water_drop_rounded, color: Colors.blueAccent),
                  SizedBox(width: 6),
                  Text(
                    'Hydration Tracker',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '${record.waterIntakeMl.toStringAsFixed(0)} / ${record.waterTargetMl.toStringAsFixed(0)} ml',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          LinearProgressIndicator(
            value: progressVal.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(healthControllerProvider.notifier).incrementWater(250.0);
                  },
                  child: const Text('+250 ml'),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(healthControllerProvider.notifier).incrementWater(500.0);
                  },
                  child: const Text('+500 ml'),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: () => _showWaterTargetDialog(context, ref, record.waterTargetMl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, WidgetRef ref, HealthRecordEntity record, bool isDark) {
    int totalDuration = 0;
    double totalBurned = 0.0;
    for (final ex in record.exercises) {
      totalDuration += ex.duration;
      totalBurned += ex.caloriesBurned;
    }

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_run_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 6),
                  Text(
                    'Exercise Tracker',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onPressed: () => _showAddExerciseDialog(context, ref),
              ),
            ],
          ),
          if (record.exercises.isEmpty)
            const Text(
              'No exercises logged today.',
              style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
            )
          else ...[
            Text(
              'Total: $totalDuration mins  ·  ${totalBurned.toStringAsFixed(0)} kcal burned',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ...record.exercises.map((ex) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ex.activity,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${ex.duration} mins  (${ex.caloriesBurned.toStringAsFixed(0)} kcal)',
                        style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildHabitsCard(WidgetRef ref, HealthRecordEntity record, bool isDark) {
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_box_rounded, color: AppColors.accentProtein),
              SizedBox(width: 6),
              Text(
                'Daily Habits Checklist',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          ...record.habits.entries.map((entry) => CheckboxListTile(
                title: Text(entry.key, style: const TextStyle(fontSize: 13)),
                value: entry.value,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary500,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(healthControllerProvider.notifier).toggleHabit(entry.key, val);
                  }
                },
              )),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return GlassmorphicContainer(
      child: Text(
        msg,
        style: const TextStyle(color: AppColors.stateError),
      ),
    );
  }

  void _showWaterTargetDialog(BuildContext context, WidgetRef ref, double currentTarget) {
    final controller = TextEditingController(text: currentTarget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Hydration Target'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Daily Target (ml)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final target = double.tryParse(controller.text) ?? 2500.0;
              ref.read(healthControllerProvider.notifier).setWaterTarget(target);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    final activityController = TextEditingController();
    final durationController = TextEditingController();
    final calsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Workout Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: activityController,
              decoration: const InputDecoration(labelText: 'Workout Name (e.g. Running)'),
            ),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
            ),
            TextField(
              controller: calsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Estimated Calories Burned'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final act = activityController.text.trim();
              final dur = int.tryParse(durationController.text) ?? 0;
              final cals = double.tryParse(calsController.text) ?? 0.0;

              if (act.isNotEmpty && dur > 0) {
                ref.read(healthControllerProvider.notifier).addExercise(
                      ExerciseEntity(
                        activity: act,
                        duration: dur,
                        caloriesBurned: cals,
                      ),
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
