import 'package:flutter/material.dart';

void main() {
  runApp(const MediTrackerApp());
}

/// Application entry point.
///
/// Deliberately minimal: the theme comes from the design token layer in Story
/// 1.2, routing and the composition root from `lib/app/`, and the first real
/// screen from Story 1.3. Nothing here should outlive those stories.
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
