// Home -- the destination, not yet the screen.
//
// Story 1.3 needs somewhere for onboarding to land, and the story's matrix
// names it: every completing and skipping path ends on Home, and a relaunch
// after completion opens onto it directly. So the route target exists, with the
// app's own surface and type and nothing else.
//
// STORY 1.8 REPLACES THIS BODY. Home's real content is the daily plan --
// greeting, date, week strip, progress card, conditional overdue banner,
// time-grouped dose list, privacy footnote, in that fixed order -- and Story
// 1.9 adds the empty state and the first-run entry. None of it can be built
// here: there is no Medicine table until Story 1.4 and no Dose until 1.7, so
// anything drawn now would be a mock of data that does not exist.
//
// It is not a `.gitkeep` because a route needs a widget, and it is not a
// borrowed dose card because inventing Home's copy a story early is how a
// placeholder becomes the thing everyone builds on.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';

/// The app's Home surface.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MTSpacing.s4),
          child: Center(
            child: Text(
              'MediTracker',
              style: MTTypography.headingLg.copyWith(
                color: MTColors.inkPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
