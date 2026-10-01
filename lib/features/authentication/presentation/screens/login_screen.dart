import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_identity.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignInSubmitted() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUiState = ref.watch(authControllerProvider);
    final isLoading = authUiState is AuthUiStateLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FitFuelCard(
                padding: const EdgeInsets.all(AppConstants.spaceLg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Logo & Title
                      const Align(
                        alignment: Alignment.center,
                        child: FitFuelBrandMark(size: 56),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      Text(
                        'Welcome Back',
                        style: AppTypography.displayMedium(isDark: isDark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.spaceXs),
                      Text(
                        'Sign in to track your calories & macros',
                        style: AppTypography.bodyMedium(isDark: isDark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.spaceLg),

                      // Error Message Banner
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
                      const SizedBox(height: AppConstants.spaceMd),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: Validators.validatePassword,
                      ),
                      const SizedBox(height: AppConstants.spaceSm),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : () => context.push(AppRoutes.forgotPassword),
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.bodySmall(isDark: isDark).copyWith(
                              color: isDark ? AppColors.primary400 : AppColors.primary500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      // Sign In CTA Button
                      FitFuelButton(
                        label: 'Sign In',
                        onPressed: isLoading ? null : _onSignInSubmitted,
                        isLoading: isLoading,
                        icon: Icons.login_rounded,
                      ),
                      const SizedBox(height: AppConstants.spaceLg),

                      // Create Account Switcher
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: AppTypography.bodyMedium(isDark: isDark),
                          ),
                          TextButton(
                            onPressed: isLoading ? null : () => context.push(AppRoutes.register),
                            child: Text(
                              'Create Account',
                              style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                                color: isDark ? AppColors.primary400 : AppColors.primary500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
