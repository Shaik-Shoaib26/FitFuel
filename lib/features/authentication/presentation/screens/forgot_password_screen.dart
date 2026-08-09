import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onResetSubmitted() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    await controller.sendPasswordResetEmail(email: _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUiState = ref.watch(authControllerProvider);
    final isLoading = authUiState is AuthUiStateLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: GlassmorphicContainer(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary100,
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 36,
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                    Text(
                      'Reset Your Password',
                      style: AppTypography.displayMedium(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.spaceXs),
                    Text(
                      'Enter your email address and we will send you instructions to reset your password.',
                      style: AppTypography.bodyMedium(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Success Feedback Banner
                    if (authUiState is AuthUiStateSuccess && authUiState.successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.stateSuccess.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          border: Border.all(color: AppColors.stateSuccess.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.stateSuccess, size: 20),
                            const SizedBox(width: AppConstants.spaceSm),
                            Expanded(
                              child: Text(
                                authUiState.successMessage!,
                                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                  color: AppColors.stateSuccess,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                    ],

                    // Error Feedback Banner
                    if (authUiState is AuthUiStateError) ...[
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.stateError.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          border: Border.all(color: AppColors.stateError.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.stateError, size: 20),
                            const SizedBox(width: AppConstants.spaceSm),
                            Expanded(
                              child: Text(
                                authUiState.message,
                                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                  color: AppColors.stateError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                    ],

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Send Reset Link CTA Button
                    FitFuelButton(
                      label: 'Send Reset Link',
                      onPressed: isLoading ? null : _onResetSubmitted,
                      isLoading: isLoading,
                      icon: Icons.send_rounded,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Back to Login
                    Center(
                      child: TextButton(
                        onPressed: isLoading ? null : () => context.go(AppRoutes.login),
                        child: Text(
                          'Back to Sign In',
                          style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                            color: isDark ? AppColors.primary400 : AppColors.primary500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
