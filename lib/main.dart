import 'package:flutter/material.dart';

void main() {
  runApp(const MediTrackerApp());
}

/// Application entry point.
///
/// Deliberately minimal. Story 1.2 shipped the design tokens as values only —
/// `MTColors`, `MTTypography`, `MTRadius`, `MTSpacing` — and deliberately no
/// theme. Building a `ThemeData` from them, along with routing and the
/// composition root in `lib/app/`, is Story 1.3's, as is the first real screen.
/// Nothing here should outlive those stories.
class MediTrackerApp extends StatelessWidget {
  const MediTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MediTracker',
      home: Scaffold(
        body: Center(child: Text('MediTracker')),
      ),
    );
  }
}
