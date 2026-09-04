// Smoke test for the root widget.
//
// Deliberately minimal: it asserts that lib/main.dart builds and renders,
// nothing about what it renders. Story 1.2 owns the design tokens, and the
// composition root — including ProviderScope — belongs to the story that
// introduces the first provider. Wrapping the app in a ProviderScope here
// would place a piece of that story's wiring in a test, where nothing points
// at it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/main.dart';

void main() {
  testWidgets('MediTrackerApp builds and renders without error', (
    tester,
  ) async {
    await tester.pumpWidget(const MediTrackerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
