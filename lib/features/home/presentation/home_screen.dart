// Home's real content -- UX-DR23's fixed vertical order: greeting, date, week
// strip, progress card, overdue banner (conditional), time-grouped dose list,
// privacy footnote.
//
// Story 1.3's placeholder ends here. `HomePlanController` is this screen's
// only data source (AD-13: the widget reads a provider, it touches no
// repository directly), and there is no pull-to-refresh, no manual reload
// button and no polling timer anywhere below -- UX-DR21 bans the first two
// outright, and the plan updates only because the provider itself reruns on
// remount (`home_plan_controller.dart`'s own file comment).
//
// THE GREETING AND THE DATE READ THE CLOCK DIRECTLY, not through
// `HomePlanController`. Both are also `today`'s inputs inside that controller,
// but neither needs a Dose to exist first -- gating them behind the same
// `AsyncValue` that Doses arrive through would mean an interactive app with
// Medicines and Schedules already saved still shows nothing at all above the
// fold for the first few milliseconds of every launch, which is a blocking
// gate this story's own AD-21 criterion forbids. Only the sections that
// genuinely need a Dose (or the count of one) wait on the provider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock_provider.dart';
import '../../../shared/design/design.dart';
import '../application/home_plan_controller.dart';
import 'dose_card.dart';
import 'home_copy.dart';
import 'overdue_banner.dart';
import 'progress_card.dart';
import 'week_strip.dart';

/// The app's Home surface: today's plan.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(clockProvider).now();
    final AsyncValue<HomePlan> planAsync = ref.watch(
      homePlanControllerProvider,
    );

    return Scaffold(
      backgroundColor: MTColors.surfaceApp,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpacing.s4,
            vertical: MTSpacing.s4,
          ),
          children: <Widget>[
            // 1. Greeting.
            Text(
              HomeCopy.greetingFor(now),
              style: MTTypography.headingLg.copyWith(
                color: MTColors.inkPrimary,
              ),
            ),
            const SizedBox(height: MTSpacing.s2),
            // 2. Date.
            _DatePill(now: now),
            const SizedBox(height: MTSpacing.s5),
            // 3-6: week strip, progress card, the conditional overdue banner,
            // and the dose list -- all of it needs the resolved plan.
            planAsync.when(
              data: (HomePlan plan) => _HomePlanBody(plan: plan),
              loading: () => const SizedBox.shrink(),
              error: (Object error, StackTrace stackTrace) =>
                  const _HomePlanUnavailable(),
            ),
            const SizedBox(height: MTSpacing.s6),
            // 7. Privacy footnote.
            Text(
              HomeCopy.privacyFootnote,
              textAlign: TextAlign.center,
              style: MTTypography.meta.copyWith(color: MTColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// The date pill: a calendar glyph (decorative) and the formatted date.
class _DatePill extends StatelessWidget {
  const _DatePill({required this.now});

  final DateTime now;

  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: MTColors.accentWash,
          borderRadius: BorderRadius.all(Radius.circular(MTRadius.pill)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpacing.s3,
            vertical: MTSpacing.s2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ExcludeSemantics(
                child: Icon(
                  Icons.calendar_today,
                  size: _iconSize,
                  color: MTColors.accentInk,
                ),
              ),
              const SizedBox(width: MTSpacing.s2),
              // `Flexible`, not a bare `Text`: `mainAxisSize.min` says "no
              // wider than my content", but says nothing about a ceiling --
              // without this, a long formatted date at the largest
              // accessibility text size sizes the Row to its own unbounded
              // intrinsic width and overflows past the `Align` that is
              // supposed to be containing it. `Flexible` lets the text wrap
              // inside whatever width the pill is actually given instead.
              Flexible(
                child: Text(
                  HomeCopy.formattedDate(now),
                  style: MTTypography.chip.copyWith(color: MTColors.accentInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The week strip, progress card, conditional overdue banner, and
/// time-grouped dose list -- everything that needs a resolved [HomePlan].
class _HomePlanBody extends StatelessWidget {
  const _HomePlanBody({required this.plan});

  final HomePlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 3. Week strip.
        WeekStrip(days: plan.weekStrip),
        const SizedBox(height: MTSpacing.s4),
        // 4. Progress card.
        ProgressCard(
          dosesTaken: plan.dosesTaken,
          dosesScheduled: plan.dosesScheduled,
          nextDoseAt: plan.nextDoseAt,
        ),
        // 5. Overdue banner -- present only when there is one to show
        // (this spec's own "banner absent entirely" row: not empty, not
        // hidden, simply not built).
        if (plan.overdueCount > 0) ...<Widget>[
          const SizedBox(height: MTSpacing.s4),
          OverdueBanner(overdueCount: plan.overdueCount),
        ],
        // 6. The time-grouped dose list.
        _DoseList(entries: plan.doses),
      ],
    );
  }
}

/// Today's Doses, grouped under one time divider per distinct scheduled time
/// -- FR-12's "grouped by time in scheduled-time order", already guaranteed
/// ascending by `HomePlanController`'s own range query.
class _DoseList extends StatelessWidget {
  const _DoseList({required this.entries});

  final List<HomeDoseEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final List<Widget> children = <Widget>[];
    DateTime? previousTime;

    for (final HomeDoseEntry entry in entries) {
      final DateTime time = entry.dose.scheduledLocal;
      final bool isNewTime =
          previousTime == null ||
          previousTime.hour != time.hour ||
          previousTime.minute != time.minute;

      if (isNewTime) {
        children
          ..add(const SizedBox(height: MTSpacing.s5))
          ..add(_TimeDivider(time: time));
      }
      children
        ..add(const SizedBox(height: MTSpacing.s2))
        ..add(DoseCard(entry: entry));

      previousTime = time;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _TimeDivider extends StatelessWidget {
  const _TimeDivider({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // The time is read aloud as part of each card's own merged label
      // (`dose_card.dart`'s `_cardLabel`), so the divider itself carries no
      // separate announcement -- otherwise a screen reader hears "8:00 AM"
      // once as a heading and again inside every card beneath it.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            HomeCopy.timeLabel(time),
            style: MTTypography.meta.copyWith(
              color: MTColors.inkFaint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: MTSpacing.s3),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: MTTranslucency.hairlineOnInk),
                ),
              ),
              child: SizedBox(height: 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the plan could not be read. The fixed chrome above (greeting,
/// date) and below (the privacy footnote) still render -- a failed read here
/// is not the same failure as a corrupt database (AD-18, Story 4.7's own
/// recovery surface), so this is a plain, honest line rather than that
/// screen's error code.
class _HomePlanUnavailable extends StatelessWidget {
  const _HomePlanUnavailable();

  static const String _message = "Today's plan could not be loaded.";

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        _message,
        style: MTTypography.body.copyWith(color: MTColors.inkMuted),
      ),
    );
  }
}
