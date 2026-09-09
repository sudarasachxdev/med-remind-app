// Step 2 -- when you take it.
//
// The time control, the four repeat options, and the two inline controls two of
// those options reveal.
//
// INLINE, NEVER A SUB-SCREEN. UX-DR: "Day selector and interval stepper appear
// *inline* beneath their repeat option and collapse when another is chosen --
// never a sub-screen. Specific days requires at least one day; every N days has
// a minimum of 2 and defaults to 2." Both are rendered directly beneath the row
// that reveals them, so the option and its value are read as one thing; and
// choosing another option discards what the collapsed one held -- see
// `AddMedicineDraft.withRepeat`, which is where "its value stops constraining
// Continue" actually happens.
//
// TOKENS, as measured from the `st2` block of the delivered design:
//   * the time card: `surfaceApp` at `2xl` 20, the value at `control` 36 --
//     DESIGN.md reserves that style for exactly this ("The add-medicine time
//     control numeral");
//   * its arrows: a square control at `md` 14 with **`accent`** icons, which is
//     what makes this stepper a different control from step 1's -- see
//     `add_medicine_controls.dart` for the 42-vs-38 note;
//   * the repeat rows: `lg` 16 with a 1.5px border, selected
//     `accentWash`/`accentBorder`, unselected `surfaceSunken`/`borderHairline`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design/design.dart';
import '../application/add_medicine_controller.dart';
import '../domain/add_medicine_draft.dart';
import 'add_medicine_controls.dart';
import 'add_medicine_copy.dart';

/// The second step's body.
class AddMedicineStepTwo extends ConsumerWidget {
  const AddMedicineStepTwo({required this.draft, super.key});

  /// Everything entered so far.
  final AddMedicineDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AddMedicineController controller = ref.read(
      addMedicineControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AddMedicineStepHeading(AddMedicineCopy.stepTwoHeading),
        const SizedBox(height: MTSpacing.s5),
        _TimeCard(hourOfDay: draft.hourOfDay, controller: controller),
        const SizedBox(height: MTSpacing.s6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: const AddMedicineSectionLabel(AddMedicineCopy.repeatLabel),
        ),
        const SizedBox(height: MTSpacing.s3),
        for (final AddMedicineRepeat repeat in AddMedicineRepeat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: MTSpacing.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _RepeatRow(
                  repeat: repeat,
                  draft: draft,
                  onSelected: () => controller.chooseRepeat(repeat),
                ),
                // The inline reveal. Rendered inside the option's own Column so
                // that it sits beneath that row and moves with it, rather than
                // in a slot below the list where it would be a panel about
                // whichever option happened to be chosen.
                if (draft.repeat == repeat && repeat.revealsDays) ...<Widget>[
                  const SizedBox(height: MTSpacing.s2),
                  _DayRow(
                    selected: draft.daysOfWeek,
                    onToggled: controller.toggleDay,
                  ),
                ],
                if (draft.repeat == repeat &&
                    repeat.revealsInterval) ...<Widget>[
                  const SizedBox(height: MTSpacing.s2),
                  AddMedicineValueStepper(
                    value: draft.intervalDays,
                    decrementLabel: AddMedicineCopy.actionShorterInterval,
                    incrementLabel: AddMedicineCopy.actionLongerInterval,
                    onDecrement: controller.decreaseInterval,
                    onIncrement: controller.increaseInterval,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The time control: `TIME`, then the hour between two accent arrows.
class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.hourOfDay, required this.controller});

  final int hourOfDay;
  final AddMedicineController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MTColors.surfaceApp,
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.xl2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MTSpacing.s5),
        child: Column(
          children: <Widget>[
            const AddMedicineSectionLabel(AddMedicineCopy.timeLabel),
            const SizedBox(height: MTSpacing.s2),
            // A Wrap over a Row, with the value constrained to the card's own
            // width. At the default text size the three sit on one line, as the
            // mock draws them. At the largest accessibility size the value
            // alone is wider than a phone, so it takes a run of its own and the
            // arrows fall below it -- vertical reflow, which is what UX-DR20
            // asks for, instead of a RenderFlex overflow.
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: MTSpacing.s4,
                  runSpacing: MTSpacing.s3,
                  children: <Widget>[
                    AddMedicineStepperButton(
                      icon: Icons.remove,
                      iconColor: MTColors.accent,
                      semanticsLabel: AddMedicineCopy.actionEarlierTime,
                      size: MTDimensions.controlSm,
                      onPressed: controller.earlierTime,
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Text(
                        AddMedicineCopy.timeOfDayLabel(hourOfDay),
                        textAlign: TextAlign.center,
                        style: MTTypography.control.copyWith(
                          color: MTColors.inkPrimary,
                        ),
                      ),
                    ),
                    AddMedicineStepperButton(
                      icon: Icons.add,
                      iconColor: MTColors.accent,
                      semanticsLabel: AddMedicineCopy.actionLaterTime,
                      size: MTDimensions.controlSm,
                      onPressed: controller.laterTime,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable repeat option, with its radio ring.
class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.repeat,
    required this.draft,
    required this.onSelected,
  });

  final AddMedicineRepeat repeat;
  final AddMedicineDraft draft;
  final VoidCallback onSelected;

  /// The radio ring's outer diameter, and the dot inside it.
  ///
  /// Single-use measurements inside one component, which is where DESIGN.md's
  /// `dimensions` note puts them: "The other nineteen are single-use
  /// measurements inside one component -- an icon inset, a badge offset -- and
  /// belong to that component's own story rather than to the contract. The test
  /// that a size belongs there is whether two components built independently
  /// could disagree about it." There is one radio ring in the product, so there
  /// is nothing to disagree about; a `dimensions/radio-ring` family would be a
  /// contract entry with a single member.
  static const double _ringSize = 20;
  static const double _dotSize = 10;

  @override
  Widget build(BuildContext context) {
    final bool selected = draft.repeat == repeat;
    final String label = AddMedicineCopy.repeatOptionLabel(
      repeat,
      intervalDays: draft.intervalDays,
    );

    return Semantics(
      button: true,
      selected: selected,
      // `inMutuallyExclusiveGroup`, so a reader announces the row as one of a
      // set of alternatives rather than as an independent switch: choosing one
      // deselects the others, and that is the fact a reader needs.
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onSelected,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? MTColors.accentWash : MTColors.surfaceSunken,
            borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
            border: Border.all(
              color: selected ? MTColors.accentBorder : MTColors.borderHairline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpacing.s4,
              vertical: MTSpacing.s4,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: _ringSize,
                  height: _ringSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        // `borderStrong` is DESIGN.md's own off state for a
                        // toggle track, and a radio ring's off state is the
                        // same role: an unfilled control outline. The mock
                        // measures `#D2D1E0`, which no token declares, and this
                        // story may not add a thirty-first colour for a role
                        // already covered.
                        color: selected
                            ? MTColors.accent
                            : MTColors.borderStrong,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: _dotSize,
                        height: _dotSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Transparent rather than absent, so the ring does
                            // not change size between states.
                            // `Colors.transparent` expresses absence and
                            // carries no brand decision, which is exactly why
                            // the literal-colour rule exempts it by name.
                            color: selected
                                ? MTColors.accent
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: MTSpacing.s3),
                // Expanded, so the label wraps inside the row instead of
                // pushing the row wider than the screen at a large text size.
                Expanded(
                  child: Text(
                    label,
                    style: MTTypography.body.copyWith(
                      color: selected
                          ? MTColors.accentInk
                          : MTColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The inline seven-day row revealed beneath `Specific days`.
///
/// DESIGN.md's Day selector: "seven `rounded/pill` toggles in a row, `M T W T F
/// S S`, selected in `accent-wash` with `accent-border`. At least one must be
/// on." The letters are the design's; the names a screen reader hears are not,
/// because `M T W T F S S` announces two Ts and two Ss with nothing to tell
/// them apart.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.selected, required this.onToggled});

  final Set<int> selected;
  final ValueChanged<int> onToggled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int day = DateTime.monday; day <= DateTime.sunday; day++) ...[
          if (day > DateTime.monday) const SizedBox(width: MTSpacing.s1),
          // Expanded, so the seven share the width evenly and each target is
          // over the platform floor on a phone without any of them being given
          // a measured width the design does not declare.
          Expanded(
            child: _DayToggle(
              day: day,
              selected: selected.contains(day),
              onToggled: () => onToggled(day),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.day,
    required this.selected,
    required this.onToggled,
  });

  final int day;
  final bool selected;
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: AddMedicineCopy.dayNames[day],
      onTap: onToggled,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onToggled,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MTDimensions.touchMinAndroid,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? MTColors.accentWash : MTColors.surfaceSunken,
              borderRadius: const BorderRadius.all(
                Radius.circular(MTRadius.pill),
              ),
              border: Border.all(
                color: selected
                    ? MTColors.accentBorder
                    : MTColors.borderHairline,
              ),
            ),
            child: Center(
              child: Text(
                AddMedicineCopy.dayLetters[day],
                style: MTTypography.body.copyWith(
                  color: selected ? MTColors.accentInk : MTColors.inkSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
