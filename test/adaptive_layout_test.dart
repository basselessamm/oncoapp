import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/widgets/adaptive_layout.dart';
import 'package:onco_repurpose_ai/widgets/animated_entrance.dart';

void main() {
  group('AdaptiveCardGrid', () {
    testWidgets('renders single column on narrow mobile viewport',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveCardGrid(
              itemCount: 4,
              itemBuilder: (context, index) => Text('Item $index'),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('renders multi-column on wide desktop viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveCardGrid(
              itemCount: 6,
              itemBuilder: (context, index) => Text('Item $index'),
            ),
          ),
        ),
      );

      // On 1200px width, 3 items per row should be laid out in a Row
      expect(find.byType(Row), findsWidgets);
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 5'), findsOneWidget);
    });
  });

  group('AnimatedEntrance', () {
    testWidgets('bypasses animation when disableAnimations is true',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: AnimatedEntrance(
                child: Text('Instant Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Instant Content'), findsOneWidget);
    });
  });
}
