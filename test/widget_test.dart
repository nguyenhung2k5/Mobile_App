import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:campus_taskhero/widgets/task_card.dart';
import 'package:campus_taskhero/models/task_model.dart';

void main() {
  testWidgets('TaskCard renders task information correctly', (WidgetTester tester) async {
    final task = HeroTask(
      id: 'test_card_1',
      title: 'Mua cơm sườn trứng',
      description: 'Lấy tại canteen tầng 1 mang lên P402',
      category: TaskCategory.food,
      compensation: 20000,
      status: TaskStatus.open,
      urgency: TaskUrgency.normal,
      estimatedMinutes: 15,
      pickup: const TaskLocation(building: 'Canteen', level: 'Tầng 1'),
      delivery: const TaskLocation(building: 'Block A', level: 'P402'),
      posterName: 'Nguyen Van A',
      posterRating: 4.8,
      posterAvatarUrl: '',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: TaskCard(
            task: task,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mua cơm sườn trứng'), findsOneWidget);
    expect(find.text('20.000đ'), findsOneWidget);
  });
}
