// The add flow's only stateful surface: the draft, which step is showing, and
// the one write.
//
// AD-13 -- a provider carries state, never a rule. The rules are elsewhere and
// stay there: whether a step may be left is `AddMedicineDraft.canAdvanceFrom`,
// what a valid Medicine is is `Medicine.violation`, and whether a Schedule
// duplicates another is `Schedule.clashesWith` inside the repository. What is
// left here is the three things a caller actually asks for: move, edit, save.
//
// Hand-written, per the amended AD-13: `riverpod_generator` has no resolvable
// version in this project and must never be re-added (it caps `analyzer` below
// 13 and makes `drift_dev` unresolvable). One provider per file, named
// `<subject>Provider`, built from `NotifierProvider`.
//
// THE STEP IS NOT A ROUTE. One route holding one value, for the reasons
// onboarding gives: three routes would put the OS back gesture in charge of a
// sequence whose first step has to leave the flow rather than pop to nothing,
// and would let a deep link open step 3 with an empty draft -- which would then
// offer Save on a medicine with no name.
//
// AUTODISPOSE IS THE "CANCEL DISCARDS IT" ROW. The draft lives exactly as long
// as the screen: leaving the flow by any route -- Cancel, Back off step 1,
// Save, or the OS back gesture -- drops the last listener and the notifier goes
// with it. Nothing has to remember to clear anything, which is why the matrix's
// "Cancel at any step: No Medicine, no Schedule" cannot be broken by a path
// somebody forgot to handle.

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock_provider.dart';
import '../../../app/medicine_repository_provider.dart';
import '../../../domain/model/domain_failure.dart';
import '../../../domain/model/medicine.dart';
import '../../../domain/port/clock.dart';
import '../../../domain/port/medicine_repository.dart';
import '../domain/add_medicine_draft.dart';
import '../presentation/add_medicine_copy.dart';

/// The `dart:developer` log source for this feature. Logging is local-only:
/// NFR-6 forbids a crash reporter, so this name is how a developer finds it.
const String addMedicineLogName = 'meditracker.add_medicine';

/// Where the add flow is, what it has been told, and whether the last save
/// failed.
///
/// Separate from [AddMedicineDraft] because these three are not part of what is
/// written: the step is navigation, and `saving`/`failureMessage` describe an
/// attempt rather than a medicine. Keeping them out of the draft is what lets
/// `add_medicine_draft_test.dart` ask "is Continue enabled" of a plain value
/// with no notifier and no widget in sight.
final class AddMedicineFlow {
  /// Creates the flow state.
  const AddMedicineFlow({
    this.step = AddMedicineStep.what,
    this.draft = const AddMedicineDraft(),
    this.saving = false,
    this.failureMessage,
  });

  /// The step showing.
  final AddMedicineStep step;

  /// Everything the user has entered.
  final AddMedicineDraft draft;

  /// Whether a save is in flight.
  ///
  /// The primary action is disabled while it is, and [AddMedicineController.save]
  /// checks it as well -- two taps inside one frame both reach the handler
  /// before the widget has rebuilt, so a disabled button alone would not stop
  /// the second one. Onboarding learned this the same way, and its tests passed
  /// anyway because they tapped once.
  final bool saving;

  /// Why the last save wrote nothing, or `null`.
  ///
  /// A sentence, ready to show: every `MedicineRepositoryFailure` owes the
  /// caller one (`DomainFailure.message`), so this flow never invents copy for
  /// a case it cannot see the detail of. The two it can be are
  /// `DuplicateScheduleFailure` and a zone the device would not name.
  final String? failureMessage;

  /// Whether the forward action is enabled.
  bool get canAdvance => draft.canAdvanceFrom(step) && !saving;

  /// This state with the given fields replaced.
  ///
  /// [clearFailure] rather than a nullable `failureMessage` that could be
  /// cleared by passing `null`: `null` already means "not supplied" everywhere
  /// else in this codebase, and a message that cleared itself whenever any
  /// other field changed would erase a duplicate-schedule explanation the
  /// moment the user touched an unrelated control.
  AddMedicineFlow copyWith({
    AddMedicineStep? step,
    AddMedicineDraft? draft,
    bool? saving,
    String? failureMessage,
    bool clearFailure = false,
  }) => AddMedicineFlow(
    step: step ?? this.step,
    draft: draft ?? this.draft,
    saving: saving ?? this.saving,
    failureMessage: clearFailure
        ? null
        : (failureMessage ?? this.failureMessage),
  );

  /// Value equality, so a rebuild that changes nothing repaints nothing.
  @override
  bool operator ==(Object other) =>
      other is AddMedicineFlow &&
      other.step == step &&
      other.draft == draft &&
      other.saving == saving &&
      other.failureMessage == failureMessage;

  @override
  int get hashCode => Object.hash(step, draft, saving, failureMessage);

  @override
  String toString() =>
      'AddMedicineFlow(${step.name}, $draft, saving $saving, '
      'failure $failureMessage)';
}

/// Holds the add flow's [AddMedicineFlow].
///
/// `autoDispose` -- see the file comment: the draft's lifetime IS the screen's,
/// which is what makes Cancel discard it without anything having to clear it.
final AutoDisposeNotifierProvider<AddMedicineController, AddMedicineFlow>
addMedicineControllerProvider =
    AutoDisposeNotifierProvider<AddMedicineController, AddMedicineFlow>(
      AddMedicineController.new,
    );

/// The add flow's notifier.
class AddMedicineController extends AutoDisposeNotifier<AddMedicineFlow> {
  @override
  AddMedicineFlow build() => const AddMedicineFlow();

  // --- Moving between steps ------------------------------------------------

  /// Advances one step, if the current one is complete.
  ///
  /// Gated on the same [AddMedicineDraft.canAdvanceFrom] the button's enabled
  /// state reads, rather than trusting the button: a keyboard Enter, a
  /// re-entrant tap and a future call site all arrive here without a disabled
  /// widget in front of them.
  void advance() {
    if (!state.canAdvance) return;
    final AddMedicineStep? next = state.step.next;
    if (next != null) state = state.copyWith(step: next, clearFailure: true);
  }

  /// Retreats one step, keeping every entry.
  ///
  /// Returns `false` on step 1, where there is no step behind it: the caller
  /// leaves for Home instead. It is the caller's decision because this notifier
  /// has no `BuildContext` and navigation is not state.
  ///
  /// "Back preserves the draft" needs no code at all -- the draft is not
  /// touched here -- and that is the point of holding it in one value rather
  /// than in three screens' widget state.
  bool retreat() {
    final AddMedicineStep? previous = state.step.previous;
    if (previous == null) return false;
    state = state.copyWith(step: previous, clearFailure: true);
    return true;
  }

  // --- Editing the draft ---------------------------------------------------

  /// Records [draft] and clears any failure message.
  ///
  /// Every edit clears it: a duplicate-schedule message describes a save that
  /// is now out of date the moment the user changes the thing it complained
  /// about, and leaving it on screen would have them re-reading a stale
  /// explanation of a state they have left.
  void _edit(AddMedicineDraft draft) =>
      state = state.copyWith(draft: draft, clearFailure: true);

  /// Sets the medicine's name.
  void setName(String value) => _edit(state.draft.withName(value));

  /// Sets the condition.
  void setCondition(String value) => _edit(state.draft.withCondition(value));

  /// Chooses the form.
  void chooseForm(String value) => _edit(state.draft.withForm(value));

  /// Chooses the dosage unit.
  void chooseUnit(String value) => _edit(state.draft.withUnit(value));

  /// Sets the free-text unit.
  void setCustomUnit(String value) => _edit(state.draft.withCustomUnit(value));

  /// One more per dose.
  void increaseAmount() => _edit(state.draft.withMoreAmount());

  /// One less per dose. Inert at the floor of one.
  void decreaseAmount() => _edit(state.draft.withLessAmount());

  /// One hour later.
  void laterTime() => _edit(state.draft.withLaterTime());

  /// One hour earlier.
  void earlierTime() => _edit(state.draft.withEarlierTime());

  /// Chooses a repeat pattern, collapsing and discarding the other option's
  /// inline control.
  void chooseRepeat(AddMedicineRepeat value) =>
      _edit(state.draft.withRepeat(value));

  /// Adds or removes a day of the week, 1 (Monday) .. 7 (Sunday).
  void toggleDay(int day) => _edit(state.draft.withDayToggled(day));

  /// One more day between doses.
  void increaseInterval() => _edit(state.draft.withLongerInterval());

  /// One fewer. Inert at the floor of two.
  void decreaseInterval() => _edit(state.draft.withShorterInterval());

  /// Turns reminders on or off. Records intent only -- Epic 3 schedules.
  void setReminders({required bool enabled}) =>
      _edit(state.draft.withReminders(enabled: enabled));

  // --- The write -----------------------------------------------------------

  /// Writes the Medicine and its Schedule, and reports whether it happened.
  ///
  /// Returns `true` only when both writes completed. On `false` the caller must
  /// not navigate and must not confirm anything: PRD ss9's worst bug is telling
  /// someone a medicine was saved when it was not, so the return value is the
  /// only thing the screen is allowed to act on, and [AddMedicineFlow.failureMessage]
  /// carries the sentence to show while the user stays on step 3.
  ///
  /// THE ORDER, AND WHY THERE IS A ROLLBACK. `addMedicine` then `addSchedule`
  /// is forced: a Schedule needs a `medicineId`, and the id is minted inside
  /// the port (AD-22). So the pair is not atomic, and the matrix's "Duplicate
  /// schedule: nothing written" would be false the moment the second call
  /// failed -- leaving a Medicine with no Schedule, which FR-1 forbids
  /// outright ("never leave an unscheduled medicine"). The rollback deletes it,
  /// and `deleteMedicine` is idempotent and cascades, so the failure path ends
  /// with the database as it started.
  ///
  /// That the duplicate case is *unreachable here* is not a reason to skip it:
  /// a Medicine created a line earlier has no Schedules to clash with, so a
  /// clash means something about the port or the flow has changed, and the
  /// safety property should hold then too rather than being rediscovered.
  ///
  /// THE ZONE IS READ FIRST, before anything is written. AD-9 as amended lets
  /// `Clock.ianaTimezone` be read when a Schedule is created, and
  /// `UnresolvedZoneClock` THROWS rather than answering when the platform could
  /// not name one. Reading it before `addMedicine` means an unnameable zone
  /// costs nothing to recover from: there is no Medicine yet to roll back.
  Future<bool> save() async {
    // Checked here as well as reflected in the button's enabled state: two taps
    // inside one frame both run the handler, because the widget has not
    // rebuilt in between.
    if (state.saving) return false;
    if (!state.draft.isReviewComplete) return false;

    final AddMedicineDraft draft = state.draft;
    // `isReviewComplete` is false when the form is unchosen, and it was just
    // checked -- so this cannot be null here, and the flow has no other way in.
    final String form = draft.form!;

    state = state.copyWith(saving: true, clearFailure: true);

    final Clock clock = ref.read(clockProvider);
    final MedicineRepository repository = ref.read(medicineRepositoryProvider);

    final String zone;
    try {
      zone = clock.ianaTimezone;
    } on Object catch (error, stackTrace) {
      // `on Object` around one expression, not around the writes. Any throw
      // from this read means the same thing -- the device has not named its
      // zone -- and AD-6 forbids substituting one, so there is nothing to
      // distinguish between.
      developer.log(
        'The device zone could not be read, so no Schedule was written. AD-6: '
        'a guessed zone is permanently wrong and is read back as truth by dose '
        'resolution.',
        name: addMedicineLogName,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      state = state.copyWith(
        saving: false,
        failureMessage: AddMedicineCopy.timezoneUnavailable,
      );
      return false;
    }

    Medicine? medicine;
    try {
      medicine = await repository.addMedicine(
        name: draft.trimmedName,
        condition: draft.conditionOrNull,
        form: form,
        dosageAmount: draft.dosageAmount,
        dosageUnit: draft.resolvedUnit,
        // FR-1's "a start date of today", from the injected clock (AD-5).
        // `Medicine` truncates it to a calendar date in the zone it arrives
        // in, so this is the user's today rather than UTC's.
        startDate: clock.now(),
        // `instructions` and `endDate` are deliberately not passed. FR-1 and
        // FR-2 set both later, from Medicine detail; this flow never asks, so
        // it must not write a value for either.
      );
      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: draft.timeOfDay,
        ianaTimezone: zone,
        frequency: draft.frequency,
        daysOfWeek: draft.scheduleDaysOfWeek,
        intervalDays: draft.scheduleIntervalDays,
        // Defaults to the Medicine's amount, per FR-4: a Schedule carries its
        // own per-occurrence dose so that "two in the morning, one at night"
        // needs no second Medicine.
        dosageAmount: draft.dosageAmount,
      );
    } on DomainFailure catch (failure, stackTrace) {
      await _rollBack(repository, medicine);
      developer.log(
        'The medicine was not saved: ${failure.message}',
        name: addMedicineLogName,
        error: failure,
        stackTrace: stackTrace,
        level: 900,
      );
      state = state.copyWith(saving: false, failureMessage: failure.message);
      return false;
    } on Object catch (error, stackTrace) {
      // Unreachable by the port's own contract -- it documents that every
      // failure is a `MedicineRepositoryFailure` and that no other exception
      // type escapes. It is caught anyway so that "nothing was written" stays
      // true when the contract is broken, and then rethrown rather than
      // rendered: there is no honest sentence to show for a failure whose shape
      // the port never described, and inventing one would hide a bug behind
      // copy. Nothing is confirmed and nothing is navigated, because `save`
      // never returns.
      await _rollBack(repository, medicine);
      state = state.copyWith(saving: false);
      developer.log(
        'The repository threw something that is not a DomainFailure. Anything '
        'written has been rolled back.',
        name: addMedicineLogName,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }

    state = state.copyWith(saving: false);
    return true;
  }

  /// Removes [medicine] after a failed Schedule write.
  ///
  /// Idempotent and cascading, so it is safe whether or not the Schedule
  /// landed. A failure to roll back is logged and swallowed: the user is
  /// already being told nothing was saved, and throwing a second failure over
  /// the first would replace an explanation they can act on with one they
  /// cannot.
  Future<void> _rollBack(
    MedicineRepository repository,
    Medicine? medicine,
  ) async {
    if (medicine == null) return;
    try {
      await repository.deleteMedicine(medicine.id);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not roll back medicine ${medicine.id} after a failed schedule '
        'write. It is stored with no schedule.',
        name: addMedicineLogName,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }
}
