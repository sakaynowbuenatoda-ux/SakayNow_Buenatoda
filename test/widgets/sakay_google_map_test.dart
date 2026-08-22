import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/maps/sakay_google_map.dart';

void main() {
  group('moveMapCameraTarget', () {
    test(
      'moves to the coordinate before animating the visual offset',
      () async {
        final actions = <String>[];

        await moveMapCameraTarget(
          moveToTarget: () async => actions.add('move'),
          animateTargetOffset: (offset) async {
            actions.add('offset:${offset.dx},${offset.dy}');
          },
          targetOffset: const Offset(0, 120),
        );

        expect(actions, <String>['move', 'offset:0.0,120.0']);
      },
    );

    test('does not animate an empty visual offset', () async {
      final actions = <String>[];

      await moveMapCameraTarget(
        moveToTarget: () async => actions.add('move'),
        animateTargetOffset: (_) async => actions.add('offset'),
        targetOffset: Offset.zero,
      );

      expect(actions, <String>['move']);
    });
  });
}
