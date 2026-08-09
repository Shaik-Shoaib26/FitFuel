import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final authUiState = ref.watch(authControllerProvider);
    final isLoading = authUiState is AuthUiStateLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitFuel Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: isLoading
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassmorphicContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary100,
                          child: Text(
                            user?.email.isNotEmpty == true ? user!.email[0].toUpperCase() : 'U',
                            style: AppTypography.heading2(isDark: false),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'FitFuel User',
                                style: AppTypography.heading2(isDark: isDark),
                              ),
                              Text(
                                user?.email ?? 'No email provided',
                                style: AppTypography.bodySmall(isDark: isDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppConstants.spaceLg),
                    Text(
                      'Authenticated Identity (Firebase UID):',
                      style: AppTypography.caption(isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      user?.uid ?? 'Unauthenticated',
                      style: AppTypography.bodySmall(isDark: isDark).copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.primary400 : AppColors.primary500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),

              GlassmorphicContainer(
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 48,
                      color: AppColors.primary500,
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                    Text(
                      'Firebase Authentication Active',
                      style: AppTypography.heading3(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    Text(
                      'Session token is restored automatically on app launch. Data isolation for UID [${user?.uid ?? ""}] is enforced.',
                      style: AppTypography.bodyMedium(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              FitFuelButton(
                label: 'Sign Out',
                type: FitFuelButtonType.secondary,
                onPressed: isLoading
                    ? null
                    : () async {
                        await ref.read(authControllerProvider.notifier).signOut();
                      },
                isLoading: isLoading,
                icon: Icons.logout_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
