import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/fitfuel_card.dart';
import '../domain/appearance_repository.dart';
import 'appearance_controller.dart';

class AppearanceSettingsCard extends ConsumerWidget {
  const AppearanceSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    final selected = appearance.valueOrNull ?? AppearanceMode.light;
    return FitFuelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Choose a theme for this device. System follows your device setting.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final mode in AppearanceMode.values)
            ChoiceChip(
              label: Text(switch (mode) {
                AppearanceMode.system => 'System',
                AppearanceMode.light => 'Light',
                AppearanceMode.dark => 'Dark',
              }),
              selected: selected == mode,
              onSelected: appearance.isLoading
                  ? null
                  : (_) async {
                      final saved = await ref
                          .read(appearanceControllerProvider.notifier)
                          .setMode(mode);
                      if (!saved && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Could not save appearance. Please try again.')),
                        );
                      }
                    },
            ),
        ]),
        if (appearance.hasError)
          TextButton(
            onPressed: () => ref.invalidate(appearanceControllerProvider),
            child: const Text('Retry loading appearance'),
          ),
      ]),
    );
  }
}
