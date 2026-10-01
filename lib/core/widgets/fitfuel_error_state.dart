import 'package:flutter/material.dart';
import '../errors/failures.dart';
import 'fitfuel_empty_state.dart';

class FitFuelErrorState extends StatelessWidget {
  final dynamic error;
  final VoidCallback onRetry;

  /// Explicitly supplied, user-facing copy; never pass raw backend details here.
  final String? messageOverride, titleOverride;
  const FitFuelErrorState(
      {super.key,
      required this.error,
      required this.onRetry,
      this.messageOverride,
      this.titleOverride});
  @override
  Widget build(BuildContext context) {
    final description = error.toString().toLowerCase();
    final offline = error is NetworkFailure ||
        description.contains('offline') ||
        description.contains('network') ||
        description.contains('socket');
    final message = messageOverride ??
        (error is AuthFailure
            ? 'Please sign in again.'
            : FailureMapper.map(
                error is Failure ? error.runtimeType.toString() : error,
                isOffline: offline));
    return Semantics(
        liveRegion: true,
        child: FitFuelEmptyState(
            icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
            title: titleOverride ??
                (offline ? 'Connection Error' : 'Something Went Wrong'),
            description: message,
            actionLabel: 'Retry',
            onActionPressed: onRetry));
  }
}
