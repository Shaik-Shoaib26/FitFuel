import 'package:flutter_test/flutter_test.dart';
import 'package:openvocab_device_benchmark/main.dart';

void main() {
  testWidgets('OpenVocabDeviceBenchmarkApp renders header and gallery controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OpenVocabDeviceBenchmarkApp());
    expect(find.textContaining('Samsung Open-Vocab Benchmark'), findsOneWidget);
    expect(find.text('Choose Image (Gallery)'), findsOneWidget);
  });
}
