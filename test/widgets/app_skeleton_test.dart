import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/app_skeleton.dart';

void main() {
  testWidgets('animates a grouped skeleton with one accessible loading label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppSkeletonCard(showAvatar: true, lineCount: 3)),
      ),
    );

    expect(find.byType(AppSkeletonShimmer), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.bySemanticsLabel('Loading content'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a static placeholder when reduced motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: AppSkeletonCard()),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.bySemanticsLabel('Loading content'), findsOneWidget);
  });

  testWidgets(
    'dashboard skeleton remains bounded on compact and wide screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final size in <Size>[const Size(360, 640), const Size(1200, 800)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AppSkeletonPage(showMetrics: true, itemCount: 3),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppSkeletonPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
