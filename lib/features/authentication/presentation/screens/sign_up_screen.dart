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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignUpSubmitted() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUiState = ref.watch(authControllerProvider);
    final isLoading = authUiState is AuthUiStateLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
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
                    Text(
                      'Join FitFuel',
                      style: AppTypography.displayMedium(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.spaceXs),
                    Text(
                      'Start your effortless AI nutrition journey',
                      style: AppTypography.bodyMedium(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Error Banner
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

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

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
                    const SizedBox(height: AppConstants.spaceMd),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Create Account CTA Button
                    FitFuelButton(
                      label: 'Create Account',
                      onPressed: isLoading ? null : _onSignUpSubmitted,
                      isLoading: isLoading,
                      icon: Icons.person_add_rounded,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Switch to Sign In
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: AppTypography.bodyMedium(isDark: isDark),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : () => context.go(AppRoutes.login),
                          child: Text(
                            'Sign In',
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
    );
  }
}
