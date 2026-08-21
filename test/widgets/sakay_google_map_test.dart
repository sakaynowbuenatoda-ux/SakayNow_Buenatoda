import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/maps/sakay_google_map.dart';

void main() {
  group('mapPaddingForCameraTargetOffset', () {
    test('uses bottom padding to raise the camera target', () {
      expect(
        mapPaddingForCameraTargetOffset(const Offset(0, 80)),
        const EdgeInsets.only(bottom: 160),
      );
    });

    test('uses the opposite edge for negative offsets', () {
      expect(
        mapPaddingForCameraTargetOffset(const Offset(-20, -30)),
        const EdgeInsets.only(left: 40, top: 60),
      );
    });

    test('keeps an unshifted target centered', () {
      expect(mapPaddingForCameraTargetOffset(Offset.zero), EdgeInsets.zero);
    });
  });
}
