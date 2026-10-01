import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../progress/domain/utils/progress_calculator.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/health_record_entity.dart';
import '../../domain/utils/wellness_calculator.dart';
import '../controllers/health_controller.dart';
import '../providers/health_providers.dart';
import '../widgets/activity_section.dart';
import '../widgets/habits_section.dart';
import '../widgets/health_header.dart';
import '../widgets/health_overview.dart';
import '../widgets/hydration_section.dart';
import '../widgets/wellness_section.dart';
import '../widgets/weight_summary.dart';

/// Health workspace: hydration, activity, habits, wellness and weight in one
/// scannable page. All values come from the existing health/nutrition streams
/// and the existing calculators; this screen owns presentation only.
class HealthScreen extends ConsumerStatefulWidget {
  final String? section;
  final String? action;
  const HealthScreen({super.key, this.section, this.action});
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  final _sectionKeys = {
    for (final name in ['hydration', 'exercise', 'habits', 'wellness'])
      name: GlobalKey()
  };
  String? _handledTarget;

  void _focusSection(String name, {double alignment = 0.05}) {
    final targetContext = _sectionKeys[name]?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(targetContext,
        duration: const Duration(milliseconds: 250), alignment: alignment);
  }

  void _applyTarget() {
    final target = [widget.section, widget.action].join(':');
    if (_handledTarget == target) return;
    _handledTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _sectionKeys[widget.section]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(targetContext,
            duration: const Duration(milliseconds: 200));
      }
      if (widget.section == 'exercise' && widget.action == 'add') {
        await _showAddExerciseDialog(context, ref);
        if (mounted) context.replace('/health?section=exercise');
      }
    });
  }

  bool _checkOnline(BuildContext context, WidgetRef ref) {
    if (ref.read(networkStatusProvider).value == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Internet connection is required for this action.')));
      return false;
    }
    return true;
  }

  /// Short contextual line built from the record's own numbers only.
  static String _contextMessage(HealthRecordEntity record, bool hasLoggedFood) {
    final target = record.waterTargetMl;
    if (target > 0 && record.waterIntakeMl >= target) {
      return 'Hydration target reached for today. Keep it going.';
    }
    if (target > 0 && record.waterIntakeMl > 0) {
      final remaining =
          HydrationSection.formatLitres(target - record.waterIntakeMl);
      return "You are $remaining L from today's hydration target.";
    }
    if (!hasLoggedFood) {
      return 'Nothing logged yet today. A glass of water is a good start.';
    }
    return "Log your first drink to start today's hydration progress.";
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(healthStreamProvider);
    final nutritionAsync = ref.watch(nutritionStreamProvider);

    return Scaffold(
      // FitFuelAppBar owns the leading control, exactly as it does on Home.
      appBar: const FitFuelAppBar(title: Text('Health')),
      body: AdaptivePageLayout(
        child: SafeArea(
          child: healthAsync.when(
            loading: () =>
                const FitFuelLoadingState(label: 'Loading your health data'),
            error: (error, _) => FitFuelErrorState(
              error: error,
              onRetry: () => ref.invalidate(healthStreamProvider),
            ),
            data: (records) => nutritionAsync.when(
              loading: () =>
                  const FitFuelLoadingState(label: "Loading today's nutrition"),
              error: (error, _) => FitFuelErrorState(
                error: error,
                onRetry: () => ref.invalidate(nutritionStreamProvider),
              ),
              data: (nutritionRecords) => _HealthBody(
                records: records,
                nutritionRecords: nutritionRecords,
                sectionKeys: _sectionKeys,
                focusSection: _focusSection,
                applyTarget: _applyTarget,
                checkOnline: _checkOnline,
                contextMessage: _contextMessage,
                showAddExercise: _showAddExerciseDialog,
                showWaterTarget: _showWaterTargetDialog,
                showCustomWater: _showCustomWaterDialog,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWaterTargetDialog(
      BuildContext context, WidgetRef ref, double currentTarget) {
    final controller =
        TextEditingController(text: currentTarget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Set Hydration Target'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Daily Target (ml)',
            helperText: 'Saved in millilitres, for example 2500.',
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
              ref
                  .read(healthControllerProvider.notifier)
                  .setWaterTarget(target);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Logs a user-entered amount through the existing increment path.
  Future<void> _showCustomWaterDialog(BuildContext context, WidgetRef ref) async {
    if (!_checkOnline(context, ref)) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Log Water'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (ml)',
            hintText: 'e.g. 300',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount != null && amount > 0) {
                ref
                    .read(healthControllerProvider.notifier)
                    .incrementWater(amount);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddExerciseDialog(
      BuildContext context, WidgetRef ref) async {
    if (!_checkOnline(context, ref)) return;
    final activityController = TextEditingController();
    final durationController = TextEditingController();
    final calsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Log Workout Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: activityController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Workout Name',
                hintText: 'e.g. Running',
              ),
            ),
            const SizedBox(height: AppConstants.spaceSmd),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                hintText: 'e.g. 30',
              ),
            ),
            const SizedBox(height: AppConstants.spaceSmd),
            TextField(
              controller: calsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated Calories Burned',
                hintText: 'e.g. 250',
              ),
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

/// Derived once per rebuild from the real streams, then handed to pure
/// presentation sections.
class _HealthBody extends ConsumerWidget {
  final List<HealthRecordEntity> records;
  final List<NutritionRecordEntity> nutritionRecords;
  final Map<String, GlobalKey> sectionKeys;
  final void Function(String name) focusSection;
  final void Function() applyTarget;
  final bool Function(BuildContext, WidgetRef) checkOnline;
  final String Function(HealthRecordEntity, bool) contextMessage;
  final Future<void> Function(BuildContext, WidgetRef) showAddExercise;
  final void Function(BuildContext, WidgetRef, double) showWaterTarget;
  final Future<void> Function(BuildContext, WidgetRef) showCustomWater;

  const _HealthBody({
    required this.records,
    required this.nutritionRecords,
    required this.sectionKeys,
    required this.focusSection,
    required this.applyTarget,
    required this.checkOnline,
    required this.contextMessage,
    required this.showAddExercise,
    required this.showWaterTarget,
    required this.showCustomWater,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayStr = DateTime.now().toString().split(' ').first;
    final record = WellnessCalculator.filterByDate(records, todayStr) ??
        HealthRecordEntity.empty(todayStr);

    final todayNutrition =
        NutritionCalculator.filterByDay(nutritionRecords, DateTime.now());
    final bool hasLoggedFood = todayNutrition.isNotEmpty;

    final double score = WellnessCalculator.calculateScore(
      hasLoggedFoodToday: hasLoggedFood,
      healthRecord: record,
    );

    // valueOrNull (not value): a failed stream must not rethrow during build.
    final historyAsync = ref.watch(weightHistoryStreamProvider);
    final history = historyAsync.valueOrNull ?? const <WeightRecordEntity>[];
    final profile = ref.watch(currentProfileStreamProvider).valueOrNull;
    final goals = ref.watch(nutritionGoalsStreamProvider).valueOrNull;
    // Reuses the same summary the Weight page builds, so trends never diverge.
    final weightSummary = history.isEmpty
        ? null
        : ProgressCalculator.calculateSummary(
            nutritionHistory: nutritionRecords,
            healthHistory: records,
            weightHistory: history,
            goals: goals,
            profile: profile,
            daysCount: ref.watch(progressControllerProvider).selectedRange,
          );

    applyTarget();

    final totalMinutes =
        record.exercises.fold<int>(0, (sum, exercise) => sum + exercise.duration);
    final habitsDone = record.habits.values.where((value) => value).length;
    final habitsTotal = record.habits.length;
    final waterProgress = record.waterTargetMl > 0
        ? (record.waterIntakeMl / record.waterTargetMl).clamp(0.0, 1.0)
        : 0.0;
    final waterValue = record.waterTargetMl > 0
        ? '${HydrationSection.formatLitres(record.waterIntakeMl)} / '
            '${HydrationSection.formatLitres(record.waterTargetMl)} L'
        : '${HydrationSection.formatLitres(record.waterIntakeMl)} L';

    final hydration = _labelled(
      key: sectionKeys['hydration'],
      title: 'Hydration',
      actionLabel: 'Daily target',
      onActionPressed: () => showWaterTarget(
          context, ref, record.waterTargetMl),
      child: HydrationSection(
        intakeMl: record.waterIntakeMl,
        targetMl: record.waterTargetMl,
        onAdd250: () {
          if (!checkOnline(context, ref)) return;
          ref.read(healthControllerProvider.notifier).incrementWater(250.0);
        },
        onAdd500: () {
          // The +500 ml quick add had no connectivity guard previously; kept
          // exactly as it was.
          ref.read(healthControllerProvider.notifier).incrementWater(500.0);
        },
        onAddCustom: () => showCustomWater(context, ref),
      ),
    );

    final activity = _labelled(
      key: sectionKeys['exercise'],
      title: 'Activity',
      actionLabel: 'Add activity',
      onActionPressed: () => showAddExercise(context, ref),
      child: ActivitySection(
        exercises: record.exercises,
        onAdd: () => showAddExercise(context, ref),
      ),
    );

    final habits = _labelled(
      key: sectionKeys['habits'],
      title: 'Habits',
      child: HabitsSection(
        habits: record.habits,
        onToggle: (habitName, completed) {
          if (!checkOnline(context, ref)) return;
          ref
              .read(healthControllerProvider.notifier)
              .toggleHabit(habitName, completed);
        },
      ),
    );

    final wellness = _labelled(
      key: sectionKeys['wellness'],
      title: 'Wellness',
      child: WellnessSection(
        score: score,
        nutritionValue: hasLoggedFood ? 'Logged today' : 'Not logged yet',
        hydrationValue: record.waterTargetMl > 0
            ? '${HydrationSection.formatLitres(record.waterIntakeMl)} / '
                '${HydrationSection.formatLitres(record.waterTargetMl)} L'
            : '${HydrationSection.formatLitres(record.waterIntakeMl)} L',
        activityValue: '$totalMinutes min',
        habitsValue: habitsTotal == 0 ? '—' : '$habitsDone / $habitsTotal',
        onViewInsights: () => context.go('/progress/insights/health'),
      ),
    );

    final weight = _labelled(
      title: 'Weight',
      child: WeightSummarySection(
        loading: historyAsync.isLoading,
        error: historyAsync.error,
        history: history,
        summary: weightSummary,
        onViewWeight: () => context.go('/health/weight'),
        onRetry: () => ref.invalidate(weightHistoryStreamProvider),
      ),
    );

    return SingleChildScrollView(
      key: const PageStorageKey('health-scroll'),
      padding: AdaptivePageLayout.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthHeader(contextMessage: contextMessage(record, hasLoggedFood)),
          const SizedBox(height: AppConstants.spaceLg),
          _labelled(
            title: "Today's Health",
            child: HealthOverviewSection(
              waterValue: waterValue,
              waterProgress: waterProgress,
              exerciseMinutes: totalMinutes,
              habitsDone: habitsDone,
              habitsTotal: habitsTotal,
              wellnessScore: score,
              onSelectSection: focusSection,
            ),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          LayoutBuilder(builder: (context, constraints) {
            // Desktop composition from ~740px of content width; tablets keep
            // the calm single column.
            if (constraints.maxWidth < 740) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hydration,
                  const SizedBox(height: AppConstants.spaceLg),
                  activity,
                  const SizedBox(height: AppConstants.spaceLg),
                  habits,
                  const SizedBox(height: AppConstants.spaceLg),
                  wellness,
                  const SizedBox(height: AppConstants.spaceLg),
                  weight,
                ],
              );
            }
            return Row(
              key: const ValueKey('health-desktop-columns'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hydration,
                      const SizedBox(height: AppConstants.spaceLg),
                      habits,
                      const SizedBox(height: AppConstants.spaceLg),
                      weight,
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spaceLg),
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      activity,
                      const SizedBox(height: AppConstants.spaceLg),
                      wellness,
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: AppConstants.spaceLg),
          Center(
            child: Text(
              '*Disclaimer: Wellness score statistics are approximate. Encourage seeking certified medical advice.*',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Section heading + surface, so every Health section reads alike.
  Widget _labelled({
    Key? key,
    required String title,
    String? actionLabel,
    VoidCallback? onActionPressed,
    required Widget child,
  }) =>
      Container(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FitFuelSectionHeader(
              title: title,
              actionLabel: actionLabel,
              onActionPressed: onActionPressed,
            ),
            const SizedBox(height: AppConstants.spaceSmd),
            child,
          ],
        ),
      );
}
