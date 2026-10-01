import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    if (ref.read(networkStatusProvider).value == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Internet connection is required for this action.')));
      return;
    }
    final formKey = GlobalKey<FormState>();
    var password = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: SingleChildScrollView(
            child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'This action is permanent and cannot be undone. Enter your password to confirm deletion.'),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: const InputDecoration(
                  labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter your password'
                  : null,
            ),
          ]),
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.stateError),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(password: password);
    if (!context.mounted || success) return;
    final state = ref.read(authControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state is AuthUiStateError
          ? state.message
          : 'Failed to delete account.'),
      backgroundColor: AppColors.stateError,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = ref.watch(authControllerProvider) is AuthUiStateLoading;
    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Account')),
      body: AdaptivePageLayout(
          maxWidth: 800,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: AppConstants.spaceMd),
                FitFuelCard(
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sign Out'),
                    subtitle: const Text('Sign out from this device'),
                    enabled: !busy,
                    onTap: busy
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signOut(),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLg),
                // Danger Zone
                Container(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.stateError.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                    color: AppColors.stateError.withValues(alpha: 0.05),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            size: 20,
                            color: AppColors.stateError,
                          ),
                          const SizedBox(width: AppConstants.spaceSm),
                          Text(
                            'Danger Zone',
                            style: AppTypography.heading3(isDark: isDark)
                                .copyWith(
                              color: AppColors.stateError,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      FitFuelCard(
                        child: ListTile(
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            color: AppColors.stateError,
                          ),
                          title: const Text('Delete Account'),
                          subtitle: const Text(
                              'Permanently delete your account and all associated data.'),
                          enabled: !busy,
                          onTap: busy
                              ? null
                              : () => _confirmDeleteAccount(context, ref),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    );
  }
}
