import 'package:flutter/material.dart';

class AnalyticsRangeSelector extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const AnalyticsRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ranges = ['7D', '30D', '90D', '1Y'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ranges.map((range) {
        final isSelected = range == selectedRange;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ChoiceChip(
            label: Text(
              range,
              style: TextStyle(
                color: isSelected ? Colors.white : null,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                onRangeChanged(range);
              }
            },
            selectedColor: theme.colorScheme.primary,
          ),
        );
      }).toList(),
    );
  }
}
