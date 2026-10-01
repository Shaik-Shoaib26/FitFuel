import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../appearance/presentation/appearance_settings_card.dart';
import '../../../profile/presentation/widgets/edit_goals_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FitFuelAppBar(title: Text('Settings')),
        body: AdaptivePageLayout(
            maxWidth: 800,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DestinationCard(
                  title: 'Health Profile & Goals',
                  description:
                      'Body metrics, activity, dietary preferences and nutrition targets.',
                  icon: Icons.tune,
                  onTap: () => context.push('/settings/goals')),
              DestinationCard(
                  title: 'Preferences',
                  description: 'Appearance and preferences for this device.',
                  icon: Icons.palette_outlined,
                  onTap: () => context.push('/settings/preferences')),
              DestinationCard(
                  title: 'Reminders',
                  description:
                      'Configure your existing daily routine reminders.',
                  icon: Icons.notifications_outlined,
                  onTap: () => context.push('/settings/reminders')),
              DestinationCard(
                  title: 'Account',
                  description: 'Sign out or manage account deletion.',
                  icon: Icons.manage_accounts_outlined,
                  onTap: () => context.push('/settings/account')),
            ])),
      );
}

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: FitFuelAppBar(title: Text('Preferences')),
        body: AdaptivePageLayout(
            maxWidth: 800,
            child: SingleChildScrollView(
                padding: EdgeInsets.all(16), child: AppearanceSettingsCard())),
      );
}

class GoalsSettingsScreen extends ConsumerWidget {
  const GoalsSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateStreamProvider).value?.uid;
    return Scaffold(
        appBar: const FitFuelAppBar(title: Text('Health Profile & Goals')),
        body: AdaptivePageLayout(
            maxWidth: 800,
            child: uid == null
                ? const Center(child: CircularProgressIndicator())
                : EditGoalsSheet(uid: uid)));
  }
}
