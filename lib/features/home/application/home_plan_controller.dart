// Home's one provider: calls the provisional generation step, reads today's
// Doses, resolves each, and exposes exactly the data the fixed vertical order
// (UX-DR23) renders.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`, built
// from `AsyncNotifierProvider` -- the async sibling of `AddMedicineController`'s
// `NotifierProvider`, needed here because this controller's own first act is
// two awaited calls (generate, then read) before it has anything to expose.
// `autoDispose`, for the same reason `AddMedicineController` is: Home is
// reached fresh on every route arrival in this app (there is no tab bar yet,
// Epic 4), so a provider that outlived the screen would go on being the one
// source `test/story_scope_test.dart`'s "no manual refresh" claim depends on,
// with nothing left watching it.
//
// AD-9, AMENDED 2026-09-10. Before `Reconciler` exists (Epic 3), Home's
// provider layer may call `DoseGenerator.generate(now)` directly -- exactly
// that one step, never the full five-step pipeline, and never anything that
// registers or cancels a notification. [_provisionalDoseGeneration] is the
// named exception the amendment describes: a reader cannot mistake it for
// `Reconciler.run()`, and Epic 3 replaces this call site rather than adding a
// second one beside it.
//
// AD-21. `build()` is `async`, and its first two lines are both awaited I/O:
// nothing here runs synchronously to completion, so the widget that watches
// this provider gets `AsyncLoading()` on its first build and paints A frame
// before either call resolves. That is what "dispatched after first frame,
// not gating it" means in an app with no manual scheduling of its own --
// there is no blocking spinner to remove, because nothing here blocks the
// first frame in order to show one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock_provider.dart';
import '../../../app/dose_generator_provider.dart';
import '../../../app/dose_repository_provider.dart';
import '../../../app/medicine_repository_provider.dart';
import '../../../domain/model/dose.dart';
import '../../../domain/model/dose_state.dart';
import '../../../domain/model/medicine.dart';
import '../../../domain/policy/dose_resolution_policy.dart';
import '../../../domain/policy/dose_resolver.dart';
import '../../../domain/port/dose_repository.dart';
import '../../../domain/port/medicine_repository.dart';

/// One day of the rolling week strip (UX-DR9).
///
/// Rolling from today rather than a fixed Monday-Sunday grid: the PRD's own
/// open question 6 ("fixed Mon-Sun or rolling 7") is recorded as deferred and
/// presentation-only, with no schema impact either way. Rolling is what this
/// story builds, because it needs no ISO-week arithmetic and it never has to
/// decide whether a day *before* today should show a dot for doses this
/// story's own forward-looking horizon query never asked about.
final class HomeWeekDay {
  const HomeWeekDay({
    required this.date,
    required this.isToday,
    required this.hasDoses,
  });

  /// The calendar day this pill represents.
  final DateTime date;

  /// Whether this is the first pill -- always true for exactly one entry,
  /// always the first, in a rolling window. The current day's highlight
  /// renders from this; *selecting* another day is Story 4.4 (UX-DR9,
  /// this spec's own Never rule).
  final bool isToday;

  /// Whether any Dose in the queried horizon falls on this day.
  final bool hasDoses;
}

/// One row of the dose list: a Dose, its resolved state, and the two fields
/// [Dose] itself does not carry.
///
/// [glyphIndex] and [condition] are the owning Medicine's -- AD-11 freezes
/// only `medicineName`/`dosageAmount`/`dosageUnit`/`form` onto a Dose, not the
/// glyph or the Condition, so both are read fresh from `MedicineRepository`
/// each time this controller builds rather than being invented as a fifth and
/// sixth frozen field nobody asked for.
final class HomeDoseEntry {
  const HomeDoseEntry({
    required this.dose,
    required this.resolution,
    required this.glyphIndex,
    required this.condition,
  });

  final Dose dose;
  final DoseResolution resolution;
  final int glyphIndex;
  final String? condition;
}

/// Everything Home's fixed vertical order (UX-DR23) renders, resolved once
/// against one `now`.
///
/// Carries data, not copy: every string the screen shows is composed at
/// render time by `home_copy.dart`, the same split `AddMedicineController`
/// draws between `AddMedicineFlow`/`AddMedicineDraft` and
/// `add_medicine_copy.dart`.
final class HomePlan {
  const HomePlan({
    required this.now,
    required this.weekStrip,
    required this.dosesTaken,
    required this.dosesScheduled,
    required this.nextDoseAt,
    required this.overdueCount,
    required this.doses,
  });

  /// The instant this plan was resolved against. The greeting and the date
  /// pill read from this rather than a second clock read, so the two cannot
  /// disagree about what "now" was.
  final DateTime now;

  /// Seven rolling days, today first. See [HomeWeekDay].
  final List<HomeWeekDay> weekStrip;

  /// How many of today's Doses have resolved to [DoseState.taken].
  ///
  /// Always `0` until `DoseRecorder` exists (Epic 2) -- computed rather than
  /// hardcoded, so this reads correctly on the day that stops being true
  /// instead of needing to be found and changed.
  final int dosesTaken;

  /// How many Doses are scheduled today, in any state.
  final int dosesScheduled;

  /// The next actionable (Scheduled or Due) Dose's instant, searched across
  /// today and the rest of the generation horizon -- `null` when none exists
  /// anywhere in it (this spec's own "nothing scheduled" row).
  final DateTime? nextDoseAt;

  /// How many of today's Doses have resolved to [DoseState.overdue].
  final int overdueCount;

  /// Today's Doses, ascending by scheduled time, each carrying its resolved
  /// state and the two Medicine fields it does not itself freeze.
  final List<HomeDoseEntry> doses;
}

/// Holds Home's [HomePlan].
final AutoDisposeAsyncNotifierProvider<HomePlanController, HomePlan>
homePlanControllerProvider =
    AutoDisposeAsyncNotifierProvider<HomePlanController, HomePlan>(
      HomePlanController.new,
    );

/// Builds [HomePlan] from already-generated (or freshly generated) Doses.
class HomePlanController extends AutoDisposeAsyncNotifier<HomePlan> {
  @override
  Future<HomePlan> build() async {
    final DateTime now = ref.read(clockProvider).now();

    await _provisionalDoseGeneration(now);

    final DoseRepository doseRepository = ref.read(doseRepositoryProvider);
    final MedicineRepository medicineRepository = ref.read(
      medicineRepositoryProvider,
    );

    // `Medicine.dateOnly` rather than a zone lookup: this is exactly the
    // "what is today" question `AddMedicineController.save()` already answers
    // the same way for `Medicine.startDate`, and it never has to fail --
    // unlike `Clock.ianaTimezone`, which throws when the platform could not
    // name a zone (`UnresolvedZoneClock`). Home must render regardless.
    final DateTime today = Medicine.dateOnly(now);
    final DateTime tomorrow = today.add(const Duration(days: 1));
    // The same rolling horizon `DoseGenerator` just wrote to -- reusing
    // `doseResolveWindowDays` rather than a second constant, per this spec's
    // own Design Notes on why the range query belongs here and nowhere else.
    final DateTime horizonEnd = today.add(
      const Duration(days: doseResolveWindowDays),
    );

    // One query covers three needs at once: today's list, the overdue count,
    // and the next-actionable search that falls back past today when it must.
    final List<Dose> visible = await doseRepository.dosesScheduledBetween(
      today,
      horizonEnd,
    );
    final Map<String, Medicine> medicineById = <String, Medicine>{
      for (final Medicine medicine in await medicineRepository.allMedicines())
        medicine.id: medicine,
    };

    final List<Dose> todaysDoses = visible
        .where((Dose dose) => dose.scheduledAt.isBefore(tomorrow))
        .toList();

    final List<HomeDoseEntry> entries = <HomeDoseEntry>[
      for (final Dose dose in todaysDoses)
        HomeDoseEntry(
          dose: dose,
          resolution: resolve(dose, now),
          glyphIndex: medicineById[dose.medicineId]?.glyphIndex ?? 0,
          condition: medicineById[dose.medicineId]?.condition,
        ),
    ];

    final int taken = entries
        .where(
          (HomeDoseEntry entry) => entry.resolution.state == DoseState.taken,
        )
        .length;
    final int overdue = entries
        .where(
          (HomeDoseEntry entry) => entry.resolution.state == DoseState.overdue,
        )
        .length;

    // `visible` is ascending by scheduled time (the range query's own
    // contract), so the first Dose here that is still Scheduled or Due --
    // whether that is later today or on a later day entirely -- is "the next
    // actionable Dose" the matrix's three next-dose rows describe. A Dose
    // whose own time has not yet arrived is always Scheduled, never Overdue
    // or Missed, so this one loop answers all three rows without a second
    // query: doses remain today, none left today (falls through to the first
    // later Dose in the same list), and nothing anywhere (the loop finds
    // nothing at all).
    DateTime? nextDoseAt;
    for (final Dose dose in visible) {
      final DoseState state = resolve(dose, now).state;
      if (state == DoseState.scheduled || state == DoseState.due) {
        nextDoseAt = dose.scheduledAt;
        break;
      }
    }

    final List<HomeWeekDay> weekStrip = <HomeWeekDay>[
      for (int offset = 0; offset < 7; offset++)
        HomeWeekDay(
          date: today.add(Duration(days: offset)),
          isToday: offset == 0,
          hasDoses: visible.any((Dose dose) {
            final DateTime dayStart = today.add(Duration(days: offset));
            final DateTime dayEnd = today.add(Duration(days: offset + 1));
            return !dose.scheduledAt.isBefore(dayStart) &&
                dose.scheduledAt.isBefore(dayEnd);
          }),
        ),
    ];

    return HomePlan(
      now: now,
      weekStrip: weekStrip,
      dosesTaken: taken,
      dosesScheduled: entries.length,
      nextDoseAt: nextDoseAt,
      overdueCount: overdue,
      doses: entries,
    );
  }

  /// AD-9, amended 2026-09-10: the one permitted step of the eventual
  /// `Reconciler.run()`, and only that step. Named so that no reader mistakes
  /// it for the real thing -- Epic 3 replaces this call site, it does not add
  /// a second one beside it.
  Future<void> _provisionalDoseGeneration(DateTime now) =>
      ref.read(doseGeneratorProvider).generate(now);
}
