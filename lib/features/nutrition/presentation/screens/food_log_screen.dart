import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/food_form_sheet.dart';

class FoodLogScreen extends ConsumerWidget {
  final String? recordId;
  const FoodLogScreen({super.key, this.recordId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateStreamProvider).value?.uid;
    final records = ref.watch(nutritionStreamProvider);
    final record =
        records.value?.where((item) => item.id == recordId).firstOrNull;
    Widget body;
    if (uid == null || (recordId != null && records.isLoading)) {
      body = const Center(child: CircularProgressIndicator());
    } else if (recordId != null && records.hasError) {
      body = FitFuelErrorState(
          error: records.error!,
          onRetry: () => ref.invalidate(nutritionStreamProvider));
    } else if (recordId != null && record == null) {
      body = const Center(child: Text('This food log is no longer available.'));
    } else {
      body = FoodFormSheet(uid: uid, existingRecord: record);
    }
    return Scaffold(
        appBar: FitFuelAppBar(
            title: Text(recordId == null ? 'Log Food' : 'Edit Food Log')),
        body: AdaptivePageLayout(maxWidth: 720, child: body));
  }
}
