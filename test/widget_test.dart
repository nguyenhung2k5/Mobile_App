import 'package:flutter_test/flutter_test.dart';

import 'package:campus_taskhero/main.dart';

void main() {
  testWidgets('TaskHero app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskHeroApp());
    await tester.pumpAndSettle();

    expect(find.text('TaskHero'), findsOneWidget);
  });
}
