// The add-medicine surface: one route, three steps, one step bar, one action.
//
// ONE ROUTE, NOT THREE, for the reasons onboarding gives and one more of its
// own. The visible step is provider state, so the OS back gesture passes
// through this screen's `PopScope` and retreats a step instead of popping a
// route -- and on step 1 it leaves for Home, which is the matrix's "Back from
// step 1: exits to Home. Nothing created." Three routes would also let a deep
// link open step 3 with an empty draft, offering Save on a medicine with no
// name.
//
// THE HEADER IS THE MOCK'S. Back control (`control-sm` 38 at `sm` 12 on
// `surfaceMuted`), `STEP n OF 3` in `label`, `Add medicine` in `title` at
// weight 700, and `Cancel` in `body`. The step bar beneath it is the shared
// three-segment control -- the same component onboarding uses, which is why it
// now lives in `lib/shared/widgets/`.
//
// THE WHOLE SCREEN SCROLLS, header and step bar included. Onboarding learned
// this the hard way and its file records the failure: pinning a header above an
// `Expanded` scroll view starves the Expanded once the header is taller than
// the viewport -- a short screen at the largest accessibility text size -- and
// the Column overflows, which is a truncation and precisely what UX-DR20
// forbids. `ConstrainedBox(minHeight: viewport) + IntrinsicHeight` keeps both
// properties: short content puts the action on the bottom edge as the mock
// draws it, tall content scrolls.
//
// NOTHING IS WRITTEN UNTIL SAVE, and Save is the only thing that writes. Cancel
// and Back-off-step-1 leave, and the draft goes with the screen because the
// controller is `autoDispose`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/design/design.dart';
import '../../../shared/widgets/mt_step_progress_bar.dart';
import '../application/add_medicine_controller.dart';
import '../domain/add_medicine_draft.dart';
import 'add_medicine_controls.dart';
import 'add_medicine_copy.dart';
import 'add_medicine_step_one.dart';
import 'add_medicine_step_three.dart';
import 'add_medicine_step_two.dart';

/// The three-step add-medicine flow.
class AddMedicineScreen extends ConsumerWidget {
  const AddMedicineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AddMedicineFlow flow = ref.watch(addMedicineControllerProvider);

    return PopScope<Object?>(
      // Never pop the route. The gesture means "go back one step", and on step
      // 1 it means "leave the flow" -- which is a `go` to Home rather than a
      // pop, because Home is a sibling route and there is nothing beneath this
      // one to pop to.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _back(context, ref);
      },
      child: Scaffold(
        // The add flow is drawn on white, not on the app surface: the mock's
        // `isAdd` block sets `background:#fff`, unlike Home and Schedule.
        backgroundColor: MTColors.surfaceRaised,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MTSpacing.s5),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      // Two groups, pushed apart. Short content puts the action
                      // on the bottom edge as the mock draws it; tall content
                      // grows past the viewport and the scroll view takes over.
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: MTSpacing.s5),
                            _Header(
                              step: flow.step,
                              onBack: () => _back(context, ref),
                              onCancel: () => _cancel(context),
                            ),
                            const SizedBox(height: MTSpacing.s4),
                            MTStepProgressBar(
                              step: flow.step.step,
                              total: AddMedicineStep.count,
                              semanticsLabel: AddMedicineCopy.stepBarLabel(
                                flow.step.step,
                                AddMedicineStep.count,
                              ),
                            ),
                            const SizedBox(height: MTSpacing.s6),
                            _StepBody(step: flow.step, draft: flow.draft),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: MTSpacing.s6),
                            if (flow.failureMessage != null) ...<Widget>[
                              _FailureMessage(flow.failureMessage!),
                              const SizedBox(height: MTSpacing.s3),
                            ],
                            AddMedicinePrimaryAction(
                              label: flow.step.isLast
                                  ? AddMedicineCopy.actionSave
                                  : AddMedicineCopy.actionContinue,
                              onPressed: flow.canAdvance
                                  ? () => _forward(context, ref)
                                  : null,
                            ),
                            const SizedBox(height: MTSpacing.s6),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Continue on steps 1 and 2; Save on step 3.
  void _forward(BuildContext context, WidgetRef ref) {
    final AddMedicineController controller = ref.read(
      addMedicineControllerProvider.notifier,
    );
    if (!ref.read(addMedicineControllerProvider).step.isLast) {
      controller.advance();
      return;
    }
    // Not awaited at the call site because a `VoidCallback` cannot be; the
    // future is handled inside `_save`.
    _save(context, ref);
  }

  /// Writes the medicine, confirms what was recorded, and leaves for Home.
  ///
  /// The order matters and is the story's safety property. Nothing is confirmed
  /// and nothing is navigated unless `save` returned `true`: PRD ss9's worst bug
  /// is telling someone a medicine was saved when it was not, so the return
  /// value is the only thing acted on. On `false` the user stays on step 3 with
  /// `AddMedicineFlow.failureMessage` on screen -- a duplicate schedule, or a
  /// device that would not name its zone.
  Future<void> _save(BuildContext context, WidgetRef ref) async {
    // Both captured BEFORE the await. The messenger because this screen's
    // `context` is defunct the moment the route is replaced -- the messenger
    // itself lives above the router and survives -- and the draft because the
    // controller is `autoDispose` and its state is gone once the route goes.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AddMedicineDraft draft = ref
        .read(addMedicineControllerProvider)
        .draft;
    final GoRouter router = GoRouter.of(context);

    final bool saved = await ref
        .read(addMedicineControllerProvider.notifier)
        .save();
    if (!saved) return;

    router.go(MTRoutes.homePath);
    // The mock's own confirmation, and EXPERIENCE.md's rule for one: it states
    // exactly what was recorded -- the medicine, and when its first reminder
    // is -- rather than congratulating anybody.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AddMedicineCopy.savedConfirmation(
            draft.trimmedName,
            AddMedicineCopy.timeOfDayLabel(draft.hourOfDay),
          ),
        ),
      ),
    );
  }

  /// Retreats one step, or leaves for Home from step 1.
  void _back(BuildContext context, WidgetRef ref) {
    final bool retreated = ref
        .read(addMedicineControllerProvider.notifier)
        .retreat();
    if (retreated) return;
    // "Back from step 1: exits to Home. Nothing created."
    GoRouter.of(context).go(MTRoutes.homePath);
  }

  /// Closes the flow from any step, creating nothing.
  ///
  /// Nothing has to be cleared: the controller is `autoDispose`, so the draft's
  /// lifetime is the screen's.
  void _cancel(BuildContext context) =>
      GoRouter.of(context).go(MTRoutes.homePath);
}

/// The back control, the step position, the title, and Cancel.
class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.onBack,
    required this.onCancel,
  });

  final AddMedicineStep step;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  /// The back arrow glyph's size -- a single-use measurement inside one
  /// component, which is where DESIGN.md's `dimensions` note puts an icon
  /// inset.
  static const double _arrowSize = 21;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: AddMedicineCopy.actionBack,
          onTap: onBack,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              // `control-sm` is 38, which is under the platform floor, so the
              // drawn box sits inside a target padded out to it.
              width: MTDimensions.touchMinAndroid,
              height: MTDimensions.touchMinAndroid,
              child: Center(
                child: SizedBox(
                  width: MTDimensions.controlSm,
                  height: MTDimensions.controlSm,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MTColors.surfaceMuted,
                      borderRadius: BorderRadius.all(
                        Radius.circular(MTRadius.sm),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_back,
                        size: _arrowSize,
                        color: MTColors.inkSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: MTSpacing.s3),
        // Expanded, so the two lines wrap inside the header rather than pushing
        // it wider than the screen at a large text size.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AddMedicineCopy.stepLabel(step.step, AddMedicineStep.count),
                style: MTTypography.label.copyWith(color: MTColors.inkFaint),
              ),
              Text(
                AddMedicineCopy.screenTitle,
                style: MTTypography.title.copyWith(
                  color: MTColors.inkPrimary,
                  // The mock sets the title at 700 while `title` is 600. The
                  // weight is the only thing overridden, because the size is
                  // the token's and adding a thirteenth type style for one
                  // heading's weight is not this story's call.
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MTSpacing.s3),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            // `inkMuted`, not the theme's accent: the mock sets Cancel in the
            // muted ink, and an accent Cancel beside an accent primary action
            // would offer two equally-weighted ways out.
            foregroundColor: MTColors.inkMuted,
            textStyle: MTTypography.body,
            // Tighter than the theme's gutter padding, so a header at the
            // largest text size leaves room for the title beside it.
            padding: const EdgeInsets.symmetric(horizontal: MTSpacing.s2),
            // The theme sizes both button roles with
            // `Size.fromHeight(kMinInteractiveDimension)`, which is
            // `Size(double.infinity, 48)` -- a TIGHT infinite width. That is
            // right for the stacked, full-width actions every other screen
            // has, and fatal here: this button sits in a Row, a Row measures
            // its non-flex children with an unbounded width, and a tight
            // infinite width inside an unbounded parent is a layout assertion,
            // not a wide button. The whole screen failed to render.
            //
            // Only the width floor is released. The 48 stays on the height, so
            // the tap target still clears UX-DR20's floor -- which is what the
            // theme was expressing and the part worth keeping.
            minimumSize: const Size(
              kMinInteractiveDimension,
              kMinInteractiveDimension,
            ),
          ),
          child: const Text(AddMedicineCopy.actionCancel),
        ),
      ],
    );
  }
}

/// The body of whichever step is showing.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.draft});

  final AddMedicineStep step;
  final AddMedicineDraft draft;

  @override
  Widget build(BuildContext context) => switch (step) {
    AddMedicineStep.what => AddMedicineStepOne(draft: draft),
    AddMedicineStep.when => AddMedicineStepTwo(draft: draft),
    AddMedicineStep.review => AddMedicineStepThree(draft: draft),
  };
}

/// Why the last Save wrote nothing.
///
/// Shown above the action, where the tap that failed was, and set in the late
/// ink on the late tile -- the semantic pair DESIGN.md declares for "something
/// needs attention". Never red: UX-DR21 reserves the three red tokens for the
/// Delete medicine control, and a failed save is not destructive.
///
/// It carries a word and not only a colour, which is EXPERIENCE.md's rule, and
/// it is announced as a live region so a screen-reader user hears it without
/// having to go looking for what happened.
class _FailureMessage extends StatelessWidget {
  const _FailureMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: MTColors.stateLateTile,
          borderRadius: BorderRadius.all(Radius.circular(MTRadius.lg)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MTSpacing.s4),
          child: Text(
            message,
            style: MTTypography.body.copyWith(color: MTColors.stateLateInk),
          ),
        ),
      ),
    );
  }
}
