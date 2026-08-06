import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pitchcup/main.dart';

void main() {
  testWidgets('PitchCup app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PitchCupApp()));
    await tester.pump();
    expect(find.byType(PitchCupApp), findsOneWidget);
  });
}
