import 'package:flutter/material.dart';

import '../passenger_widgets/passenger_ui.dart';

class MapTextStyles {
  const MapTextStyles._();

  static TextStyle get title => TextStyle(
    fontSize: 16,
    color: PassengerUi.title,
    fontWeight: FontWeight.w800,
  );

  static TextStyle get body =>
      TextStyle(fontSize: 14, color: PassengerUi.body, height: 1.4);

  static TextStyle get value => TextStyle(
    fontSize: 14,
    color: PassengerUi.title,
    fontWeight: FontWeight.w700,
  );
}
