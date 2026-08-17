import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyReportState {
  final String selectedView; // 'completed' | 'previous' | 'preview'

  const WeeklyReportState({
    this.selectedView = 'completed',
  });

  WeeklyReportState copyWith({
    String? selectedView,
  }) {
    return WeeklyReportState(
      selectedView: selectedView ?? this.selectedView,
    );
  }
}

class WeeklyReportController extends StateNotifier<WeeklyReportState> {
  WeeklyReportController() : super(const WeeklyReportState());

  void setView(String view) {
    state = state.copyWith(selectedView: view);
  }
}

final weeklyReportControllerProvider =
    StateNotifierProvider<WeeklyReportController, WeeklyReportState>((ref) {
  return WeeklyReportController();
});
