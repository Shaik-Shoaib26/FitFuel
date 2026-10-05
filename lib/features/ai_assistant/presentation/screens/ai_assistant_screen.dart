import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../nutrition/presentation/widgets/food_form_sheet.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../domain/entities/chat_message.dart';
import '../controllers/ai_assistant_controller.dart';
import '../providers/ai_assistant_providers.dart';
import '../../../food/data/datasources/predefined_food_data.dart';
import '../../../food/presentation/widgets/food_image.dart';
import '../../../reminders/presentation/providers/reminders_providers.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  const AiAssistantScreen({super.key, this.initialPrompt});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _messageController.text = widget.initialPrompt!;
    }
  }

  final List<String> _suggestedChips = [
    'What should I eat today?',
    'How am I doing?',
    'What should I improve?',
    'Give me a high protein meal',
    'How is my hydration?',
  ];

  @override
  void didUpdateWidget(covariant AiAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prompt = widget.initialPrompt;
    if (prompt != null &&
        prompt.isNotEmpty &&
        prompt != oldWidget.initialPrompt) {
      final draft = _messageController.text;
      _messageController.text =
          draft.trim().isEmpty ? prompt : '$draft\n\n$prompt';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final networkStatus =
        ref.read(networkStatusProvider).value ?? NetworkStatus.online;
    if (networkStatus == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection is required for this action.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authUserUid = ref.read(authStateStreamProvider).value?.uid;
    if (authUserUid == null) return;

    final todayRecords = ref.read(nutritionStreamProvider).value ?? [];
    final goals = ref.read(nutritionGoalsStreamProvider).value;
    final healthRecords = ref.read(healthStreamProvider).value ?? [];
    final weightHistory = ref.read(weightHistoryStreamProvider).value ?? [];

    final filteredToday =
        NutritionCalculator.filterByDay(todayRecords, DateTime.now());
    final todayStr = DateTime.now().toString().split(' ').first;
    final todayHealth =
        healthRecords.where((r) => r.date == todayStr).firstOrNull;

    final profile = ref.read(currentProfileStreamProvider).value;
    final mealPlan = ref.read(mealPlannerControllerProvider).value;

    final dailyRoutine = ref.read(dailyRoutineProvider);

    final groceryList = ref.read(currentGroceryListProvider).value;
    final pantryItems = ref.read(pantryProvider).value ?? [];

    ref.read(aiAssistantControllerProvider.notifier).sendMessage(
          prompt: text,
          todayRecords: filteredToday,
          historyRecords: todayRecords,
          goals: goals,
          todayHealth: todayHealth,
          historyHealth: healthRecords,
          profile: profile,
          weightHistory: weightHistory,
          mealPlan: mealPlan,
          dailyRoutine: dailyRoutine,
          groceryItems: groceryList?.items ?? [],
          pantryItems: pantryItems,
        );

    _messageController.clear();
    _scrollToBottom();
  }

  void _showFoodForm(
      BuildContext context, String uid, NutritionRecordEntity record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodFormSheet(uid: uid, existingRecord: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(aiAssistantControllerProvider);
    final authUserUid = ref.watch(authStateStreamProvider).value?.uid;
    final isLoading = chatState is AiAssistantLoading;
    final networkStatus =
        ref.watch(networkStatusProvider).value ?? NetworkStatus.online;
    final isOffline = networkStatus == NetworkStatus.offline;

    // Trigger scrolling when new replies land
    ref.listen(aiAssistantControllerProvider, (prev, next) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: FitFuelAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FitFuel AI Assistant', style: TextStyle(fontSize: 16)),
            Text(
              isOffline
                  ? 'Offline'
                  : (chatState.providerUsed == 'Gemini'
                      ? 'Online'
                      : 'Offline guidance'),
              style: TextStyle(
                fontSize: 11,
                color: isOffline
                    ? Colors.red
                    : (chatState.providerUsed == 'Gemini'
                        ? Colors.green
                        : Colors.orange),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Chat History',
            onPressed: () {
              ref.read(aiAssistantControllerProvider.notifier).clearHistory();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedBox(
          key: const ValueKey('ai-workspace'),
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: Colors.red.withAlpha(30),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'FitFuel AI requires an internet connection.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Chat messages list
              Expanded(
                child: chatState.messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppConstants.spaceMd),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          return _buildMessageBubble(
                              message, isDark, authUserUid);
                        },
                      ),
              ),

              // Loading / Thinking indicator
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: _BouncingDotsIndicator(),
                ),

              // Error display card
              if (chatState is AiAssistantError)
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: AppColors.stateError.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusControl),
                      border: Border.all(
                        color: AppColors.stateError.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      chatState.message,
                      style: const TextStyle(
                          color: AppColors.stateError, fontSize: 12),
                    ),
                  ),
                ),

              // Suggested prompt chips row
              if (!isLoading && !isOffline) _buildSuggestedChipsRow(isDark),

              // Chat input control panel
              _buildInputPanel(isDark, isLoading || isOffline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkPrimaryContainer : AppColors.softSage,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.emeraldGreen.withValues(alpha: 0.4) : AppColors.mintGreen,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.eco_rounded,
                      size: 40,
                      color: AppColors.primaryLeafGreen,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Text(
                  'FitFuel AI',
                  style: AppTypography.heading1(isDark: isDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'Your personal health and nutrition assistant',
                  style: AppTypography.bodyMedium(isDark: isDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Wrap(
                  spacing: AppConstants.spaceSm,
                  runSpacing: AppConstants.spaceSm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final prompt in _suggestedChips)
                      _buildPromptChip(prompt),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _messageController.text = prompt,
      borderRadius: BorderRadius.circular(AppConstants.radiusControl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPrimaryContainer : const Color(0xFFDCF5E5),
          borderRadius: BorderRadius.circular(AppConstants.radiusControl),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFB8EAD1),
          ),
        ),
        child: Text(
          prompt,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.mintGreen : AppColors.primaryLeafGreen,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      ChatMessage message, bool isDark, String? authUserUid) {
    final isUser = message.sender == MessageSender.user;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser
        ? (isDark ? const Color(0xFF163A24) : AppColors.softSage)
        : (isDark ? AppColors.darkBgSurface : AppColors.pureWhite);

    final textColor = isUser
        ? (isDark ? Colors.white : AppColors.primaryText)
        : (isDark ? Colors.white : AppColors.primaryText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                bottomRight: isUser ? Radius.zero : const Radius.circular(16),
              ),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorderSubtle
                    : (isUser ? const Color(0xFFCBE5D2) : const Color(0xFFDDE7DF)),
                width: 1.0,
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
            ),
          ),

          // Coaching Action Cards if text has priority statements
          if (!isUser) ...[
            if (_buildCoachingCard(message.text, isDark) != null)
              _buildCoachingCard(message.text, isDark)!,
          ],

          // Food recommendation card integration
          if (!isUser &&
              message.suggestedFoods != null &&
              message.suggestedFoods!.isNotEmpty) ...[
            ...message.suggestedFoods!.map((food) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: _buildFoodRecommendationCard(food, isDark, authUserUid),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget? _buildCoachingCard(String text, bool isDark) {
    if (!text.contains('**') ||
        (!text.contains('priority') && !text.contains('checklist'))) {
      return null;
    }

    final lines = text.split('\n\n');
    final cards = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      IconData icon = Icons.info_outline;
      Color accentColor = AppColors.primary500;
      String title = 'Coaching Tip';

      if (line.contains('Protein')) {
        icon = Icons.restaurant_rounded;
        accentColor = Colors.orange;
        title = 'Protein Goal Priority';
      } else if (line.contains('Hydration')) {
        icon = Icons.water_drop_rounded;
        accentColor = Colors.blue;
        title = 'Hydration Goal Priority';
      } else if (line.contains('Exercise')) {
        icon = Icons.fitness_center_rounded;
        accentColor = Colors.green;
        title = 'Exercise Goal Priority';
      } else if (line.contains('Habits')) {
        icon = Icons.check_circle_rounded;
        accentColor = Colors.purple;
        title = 'Habit Checklist Focus';
      } else {
        continue;
      }

      // Clean title from description
      final cleanText = line.replaceAll(RegExp(r'\*\*.*?\*\*:\s*'), '');

      cards.add(
        Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: BorderSide(
                color: accentColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accentColor, size: 24),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cleanText,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (cards.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(children: cards),
    );
  }

  Widget _buildFoodRecommendationCard(
      dynamic food, bool isDark, String? authUserUid) {
    final foodName = food.foodName ?? '';
    final matchedFood = food.foodName != null
        ? (PredefinedFoodData.foods
                .where((f) => f.name.toLowerCase() == foodName.toLowerCase())
                .firstOrNull
                ?.toEntity() ??
            PredefinedFoodData.foods
                .where((f) =>
                    foodName.toLowerCase().contains(f.name.toLowerCase()))
                .firstOrNull
                ?.toEntity())
        : null;

    final finalFood = matchedFood ??
        FoodEntity(
          id: 'temp',
          name: foodName,
          category: 'Protein',
          servingSize: food.servingSize,
          servingUnit: 'g',
          calories: food.calories,
          protein: food.protein,
          carbohydrates: food.carbohydrates,
          fats: food.fats,
          fiber: 0,
          sugar: food.sugar,
          sodium: 0,
        );

    List<Widget> badges = [];
    if (finalFood.isIndian) {
      badges.add(_buildCardBadge('Indian', Colors.orange));
    }
    if (finalFood.isVegan) {
      badges.add(_buildCardBadge('Vegan', Colors.green));
    } else if (finalFood.isVegetarian) {
      badges.add(_buildCardBadge('Veg', Colors.green));
    } else if (finalFood.id != 'temp') {
      badges.add(_buildCardBadge('Non-Veg', Colors.red));
    }
    for (final tag in finalFood.dietaryTags.take(1)) {
      badges.add(_buildCardBadge(tag, Colors.blue));
    }

    return FitFuelCard(
      margin: const EdgeInsets.only(top: AppConstants.spaceSm),
      border: const BorderSide(color: AppColors.primary500, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FoodImage(
                  food: finalFood, width: 44, height: 44, borderRadius: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finalFood.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, children: badges),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroIndicator('Cals',
                  '${food.calories.toStringAsFixed(0)} kcal', Colors.grey),
              _buildMacroIndicator('Protein',
                  '${food.protein.toStringAsFixed(1)}g', Colors.orange),
              _buildMacroIndicator('Carbs',
                  '${food.carbohydrates.toStringAsFixed(1)}g', Colors.blue),
              _buildMacroIndicator(
                  'Fats', '${food.fats.toStringAsFixed(1)}g', Colors.green),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: authUserUid == null
                  ? null
                  : () {
                      _showFoodForm(context, authUserUid, food);
                    },
              icon: const Icon(Icons.add_rounded, size: 14),
              label:
                  const Text('Add to Food Log', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMacroIndicator(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildSuggestedChipsRow(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
        itemCount: _suggestedChips.length,
        itemBuilder: (context, index) {
          final prompt = _suggestedChips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(
                prompt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.mintGreen : AppColors.primaryLeafGreen,
                ),
              ),
              backgroundColor: isDark ? AppColors.darkPrimaryContainer : const Color(0xFFDCF5E5),
              side: BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFB8EAD1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusControl),
              ),
              onPressed: () => _sendMessage(prompt),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputPanel(bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      color: isDark ? AppColors.darkBgSurface : AppColors.appCanvas,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFDDE7DF),
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask FitFuel AI about your targets...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryLeafGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              tooltip: 'Send message',
              onPressed:
                  isLoading ? null : () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDotsIndicator extends StatefulWidget {
  const _BouncingDotsIndicator();

  @override
  State<_BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<_BouncingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'FitFuel AI is thinking',
          style: AppTypography.caption(isDark: isDark).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double progress = _controller.value;
            int dotCount = (progress * 4).floor() % 4; // 0, 1, 2, or 3 dots
            String dots = '.' * dotCount + ' ' * (3 - dotCount);
            return Text(
              dots,
              style: AppTypography.caption(isDark: isDark).copyWith(
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ],
    );
  }
}
