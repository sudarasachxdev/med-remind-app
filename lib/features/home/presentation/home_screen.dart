// Home's real content -- UX-DR23's fixed vertical order: greeting, date, week
// strip, progress card, notification-permission banner (conditional, Story
// 3.1b), budget banner (conditional, AD-8, Story 3.4), overdue banner
// (conditional), time-grouped dose list, privacy footnote.
//
// Story 1.3's placeholder ends here. `HomePlanController` is this screen's
// only data source (AD-13: the widget reads a provider, it touches no
// repository directly), and there is no pull-to-refresh, no manual reload
// button and no polling timer anywhere below -- UX-DR21 bans the first two
// outright, and the plan updates only because the provider itself reruns on
// remount (`home_plan_controller.dart`'s own file comment).
//
// STORY 1.9 adds one branch, not a rewrite: `_HomePlanBody` renders the week
// strip unconditionally (the mock's own `isHome` block draws it before either
// alternative, and this spec's own matrix never lists it as absent), then
// either `_PopulatedPlan` -- Story 1.8's progress card, overdue banner and
// dose list, unchanged -- or `EmptyStateCard`, keyed on `HomePlan.hasMedicines`
// and never on `dosesScheduled == 0` (this spec's own Boundaries).
//
// THE GREETING AND THE DATE READ THE CLOCK DIRECTLY, not through
// `HomePlanController`. Both are also `today`'s inputs inside that controller,
// but neither needs a Dose to exist first -- gating them behind the same
// `AsyncValue` that Doses arrive through would mean an interactive app with
// Medicines and Schedules already saved still shows nothing at all above the
// fold for the first few milliseconds of every launch, which is a blocking
// gate this story's own AD-21 criterion forbids. Only the sections that
// genuinely need a Dose (or the count of one) wait on the provider.
//
// THE ROUTE IN (Story 3.3): a tapped notification's `doseId`, from
// `notificationTapProvider`, opens that Dose's action sheet once Home is
// showing -- no new route, per that story's own Design Notes ("Why no new
// route"). Two orderings both happen in practice and neither may be skipped:
// a cold launch delivers the tap before `HomePlan` has loaded; a warm tap
// while Home is already showing delivers it after. `_pendingTapDoseId` holds
// whichever arrived first, and `_maybeOpenPendingActionSheet` is re-checked
// on BOTH events -- a fresh tap, and every rebuild this widget's own `build`
// runs, which covers the plan finishing its load -- so whichever ordering
// occurs, the check that finally has both pieces is the one that opens the
// sheet. This is why `HomeScreen` is a `ConsumerStatefulWidget` now, not the
// `ConsumerWidget` it was through Story 3.1b: the pending id needs to survive
// from one rebuild to the next, in `State` rather than recomputed each time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/clock_provider.dart';
import '../../../app/notification_tap_provider.dart';
import '../../../app/router.dart';
import '../../../shared/design/design.dart';
import '../../../shared/widgets/dose_action_sheet.dart';
import '../../add_medicine/presentation/add_medicine_copy.dart';
import '../application/home_plan_controller.dart';
import 'budget_banner.dart';
import 'dose_card.dart';
import 'home_copy.dart';
import 'home_empty_state.dart';
import 'overdue_banner.dart';
import 'permission_banner.dart';
import 'progress_card.dart';
import 'week_strip.dart';

/// The app's Home surface: today's plan.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// A tapped notification's `doseId`, held until it can be checked against
  /// a loaded `HomePlan` -- see this file's own header comment on why both
  /// orderings need this rather than acting the moment the tap arrives.
  String? _pendingTapDoseId;

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(clockProvider).now();
    final AsyncValue<HomePlan> planAsync = ref.watch(
      homePlanControllerProvider,
    );

    // A fresh tap: recorded and (re-)checked against whatever plan is
    // currently held. `ref.listen`, not `ref.watch` -- a tap is an event to
    // react to once, not a value this build should read every time it runs
    // for an unrelated reason.
    ref.listen<AsyncValue<String>>(notificationTapProvider, (
      AsyncValue<String>? previous,
      AsyncValue<String> next,
    ) {
      final String? doseId = next.valueOrNull;
      if (doseId != null) _pendingTapDoseId = doseId;
      _scheduleActionSheetCheck();
    });
    // The plan itself changing (including finishing its very first load) is
    // the other event that can complete a pending tap -- re-checked on every
    // build for that reason, not only when a tap just arrived.
    _scheduleActionSheetCheck();

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
            // 3-7: week strip, progress card, the two conditional banners,
            // and the dose list -- all of it needs the resolved plan.
            planAsync.when(
              data: (HomePlan plan) => _HomePlanBody(plan: plan),
              loading: () => const SizedBox.shrink(),
              error: (Object error, StackTrace stackTrace) =>
                  const _HomePlanUnavailable(),
            ),
            const SizedBox(height: MTSpacing.s6),
            // 8. Privacy footnote.
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

  /// Defers [_maybeOpenPendingActionSheet] to after this frame -- never
  /// mid-build, per this story's own Code Map: opening a sheet (which itself
  /// builds widgets) while `build` is still running is the exact re-entrant
  /// build Flutter forbids.
  void _scheduleActionSheetCheck() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _maybeOpenPendingActionSheet();
    });
  }

  /// Opens the pending tap's Dose in `DoseActionSheet`, once a loaded
  /// `HomePlan` actually names it.
  ///
  /// Three outcomes: nothing pending (no-op); pending, but the plan has not
  /// loaded yet (left pending -- a later build, once it has, checks again);
  /// pending and loaded, but no entry in today's plan names this doseId --
  /// this spec's own named edge case (the Dose was deleted), dropped
  /// silently here rather than retried forever, since no future plan update
  /// would ever make it match.
  void _maybeOpenPendingActionSheet() {
    if (!mounted) return;
    final String? doseId = _pendingTapDoseId;
    if (doseId == null) return;

    final HomePlan? plan = ref.read(homePlanControllerProvider).valueOrNull;
    if (plan == null) return;

    HomeDoseEntry? match;
    for (final HomeDoseEntry entry in plan.doses) {
      if (entry.dose.id == doseId) {
        match = entry;
        break;
      }
    }

    _pendingTapDoseId = null;
    if (match == null) return;

    DoseActionSheet.show(
      context,
      dose: match.dose,
      glyphIndex: match.glyphIndex,
      condition: match.condition,
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

/// The week strip, then either the populated plan or the empty state --
/// everything that needs a resolved [HomePlan].
class _HomePlanBody extends StatelessWidget {
  const _HomePlanBody({required this.plan});

  final HomePlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 3. Week strip -- unconditional. See the file comment.
        WeekStrip(days: plan.weekStrip),
        const SizedBox(height: MTSpacing.s4),
        // 4-6. The populated plan (progress card, overdue banner, dose
        // list), or the empty-state card -- never both (Story 1.9, UX-DR16).
        if (plan.hasMedicines)
          _PopulatedPlan(plan: plan)
        else
          EmptyStateCard(
            icon: Icons.medication,
            title: HomeCopy.emptyStateTitle,
            body: HomeCopy.emptyStateBody,
            actionLabel: AddMedicineCopy.screenTitle,
            // The same named route the add-medicine flow is reached by
            // everywhere else in the app (`app/router.dart`'s own file
            // comment: "go_router's named navigation needs the name") --
            // one route, one way in, per this spec's own Boundaries.
            onAction: () => context.goNamed(MTRoutes.addMedicine),
          ),
      ],
    );
  }
}

/// The progress card, the three conditional banners, and the time-grouped
/// dose list -- Story 1.8's populated plan, extracted so `_HomePlanBody` can
/// branch above it (Story 1.9) without touching what either branch renders.
/// Story 3.1b adds the notification-permission banner between the progress
/// card and the overdue banner; Story 3.4 adds the budget banner directly
/// after it, independent of both permission reasons (a user can have
/// notifications denied AND more doses than the budget covers at once, and
/// both facts are worth surfacing); neither of Story 1.8's own two
/// renderings changes.
class _PopulatedPlan extends StatelessWidget {
  const _PopulatedPlan({required this.plan});

  final HomePlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 4. Progress card.
        ProgressCard(
          dosesTaken: plan.dosesTaken,
          dosesScheduled: plan.dosesScheduled,
          nextDoseAt: plan.nextDoseAt,
        ),
        // 5. Permission banner -- present only while one of the two
        // degradations `PermissionGateway` reports currently applies. Full
        // denial (Story 3.1b) takes priority over the milder exact-alarm
        // denial (AD-14, Story 3.3) when both are true: the weaker fact
        // (reminders may be late) is entirely subsumed by the stronger one
        // (reminders will not fire), so the two are never shown together
        // (this spec's own Design Notes). Sits above the overdue banner
        // (UX-DR23, amended 2026-09-16): a capability-level degradation
        // outranks an item-level one.
        if (plan.notificationsDenied) ...<Widget>[
          const SizedBox(height: MTSpacing.s4),
          const PermissionBanner(
            reason: PermissionBannerReason.notificationsDenied,
          ),
        ] else if (plan.exactAlarmsDenied) ...<Widget>[
          const SizedBox(height: MTSpacing.s4),
          const PermissionBanner(
            reason: PermissionBannerReason.exactAlarmsDenied,
          ),
        ],
        // 6. Budget banner (AD-8, Story 3.4) -- present only while more
        // Doses need their notification chain considered than the budget
        // reaches. Not mutually exclusive with either permission reason
        // above: a user can have notifications denied AND more doses than
        // the budget covers at once, and both facts are independently worth
        // surfacing (this spec's own Design Notes). Sits directly after the
        // permission-banner slot and before the overdue banner (UX-DR23):
        // capability-level degradations cluster together, ahead of the
        // item-level overdue banner.
        if (plan.budgetExceeded) ...<Widget>[
          const SizedBox(height: MTSpacing.s4),
          const BudgetBanner(),
        ],
        // 7. Overdue banner -- present only when there is one to show
        // (this spec's own "banner absent entirely" row: not empty, not
        // hidden, simply not built).
        if (plan.overdueCount > 0) ...<Widget>[
          const SizedBox(height: MTSpacing.s4),
          OverdueBanner(overdueCount: plan.overdueCount),
        ],
        // 8. The time-grouped dose list. `plan.now` -- the one instant this
        // whole plan was resolved against -- rather than a second clock read,
        // so a Snoozed card's own "reminder in {n} min" cannot disagree with
        // what `resolve()` itself used (Story 2.3).
        _DoseList(entries: plan.doses, now: plan.now),
      ],
    );
  }
}

/// Today's Doses, grouped under one time divider per distinct scheduled time
/// -- FR-12's "grouped by time in scheduled-time order", already guaranteed
/// ascending by `HomePlanController`'s own range query.
class _DoseList extends StatelessWidget {
  const _DoseList({required this.entries, required this.now});

  final List<HomeDoseEntry> entries;

  /// Threaded through to each `DoseCard` -- see `_PopulatedPlan`'s own
  /// comment for why this is `plan.now`, not a second clock read.
  final DateTime now;

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
        ..add(DoseCard(entry: entry, now: now));

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
