import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives the test a tall phone-sized screen (about 390×1000 logical px).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Opens a tab of the floating bar by its label.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
}
