// Step 1 -- what you are taking, and how much.
//
// Name, Condition, the form chips, the dose stepper, the unit chips, and the
// free-text unit FR-1 promises behind `Other`.
//
// TOKENS, as measured from the `st1` block of the delivered design:
//   * the two inputs: `lg` 16 on `surfaceSunken`, `title` 17 -- see
//     `AddMedicineTextInput`;
//   * the chips: `pill`, selected `accentWash`/`accentBorder`/`accentInk` --
//     see `AddMedicineChip`;
//   * the dose stepper: `control-md` 46 buttons at `md` 14 on a `surfaceApp`
//     card at `xl` 18, the value at `heading-lg` 30.
//
// CONDITION IS COMPLETING THE DESIGN, NOT CONTRADICTING IT. `Medicine.condition`
// exists, `addMedicine` takes it, and the design renders it as `Condition ·
// Form` on Home and on Medicine detail -- only the capture was missing, because
// the mock's add flow never asks. Its placeholder is the one composed visible
// string in this story; `add_medicine_copy.dart` records who decided it and
// what was rejected.
//
// EVERY VALUE IS A STEPPER, NOT A KEYBOARD. UX-DR: "Steppers, not free text,
// for numeric entry; the dose amount floors at 1." At the floor the decrement
// is inert rather than disabled -- there is nothing to explain about a dose
// that cannot go below one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/policy/medicine_vocabulary.dart';
import '../../../shared/design/design.dart';
import '../application/add_medicine_controller.dart';
import '../domain/add_medicine_draft.dart';
import 'add_medicine_controls.dart';
import 'add_medicine_copy.dart';

/// The first step's body.
class AddMedicineStepOne extends ConsumerWidget {
  const AddMedicineStepOne({required this.draft, super.key});

  /// Everything entered so far. Passed in rather than watched here so that the
  /// screen and its steps read one value from one place.
  final AddMedicineDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AddMedicineController controller = ref.read(
      addMedicineControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AddMedicineStepHeading(AddMedicineCopy.stepOneHeading),
        const SizedBox(height: MTSpacing.s5),
        AddMedicineTextInput(
          placeholder: AddMedicineCopy.namePlaceholder,
          initialValue: draft.name,
          onChanged: controller.setName,
        ),
        // The two gaps around the Condition input are one step tighter than
        // the flow's usual rhythm, and this is the only place that is true.
        //
        // Condition is the field FR-1 requires and the delivered design does
        // not have -- roughly 78px the mock's step 1 never carried. With it at
        // the mock's own spacing, step 1 is 7px taller than the design's
        // 402x874 frame at the default text size, which scrolls, which FR-1
        // says it must not have to.
        //
        // Seven pixels are reclaimed here rather than anywhere else because
        // this is the region the new field disturbed: the name and what it is
        // for are one question, so pairing them tightly is what the grouping
        // wanted anyway. Both values are still steps on the scale, and the
        // heading-to-name gap the mock does specify is untouched.
        const SizedBox(height: MTSpacing.s2),
        AddMedicineTextInput(
          placeholder: AddMedicineCopy.conditionPlaceholder,
          initialValue: draft.condition,
          onChanged: controller.setCondition,
        ),
        const SizedBox(height: MTSpacing.s4),
        const _Label(AddMedicineCopy.formLabel),
        const SizedBox(height: MTSpacing.s3),
        _ChipRow(
          children: <Widget>[
            for (final String form in addMedicineForms)
              AddMedicineChip(
                label: form,
                selected: draft.form == form,
                onSelected: () => controller.chooseForm(form),
              ),
          ],
        ),
        const SizedBox(height: MTSpacing.s5),
        const _Label(AddMedicineCopy.doseLabel),
        const SizedBox(height: MTSpacing.s3),
        AddMedicineValueStepper(
          value: draft.amount,
          decrementLabel: AddMedicineCopy.actionDecreaseDose,
          incrementLabel: AddMedicineCopy.actionIncreaseDose,
          onDecrement: controller.decreaseAmount,
          onIncrement: controller.increaseAmount,
        ),
        const SizedBox(height: MTSpacing.s3),
        _ChipRow(
          children: <Widget>[
            for (final String unit in dosageUnits)
              AddMedicineChip(
                // The domain's vocabulary is lower case; the chip's word is
                // the design's capitalisation of the same five options.
                label: AddMedicineCopy.unitLabels[unit]!,
                selected: draft.unit == unit,
                onSelected: () => controller.chooseUnit(unit),
              ),
          ],
        ),
        // FR-1: "selecting 'other' permits a free-text unit". Inline, beneath
        // the chips, and only while `Other` is the chosen one -- the same
        // reveal-in-place rule the repeat options follow on step 2. Continue
        // stays disabled until it holds something, because
        // `AddMedicineDraft.resolvedUnit` is empty while it is blank.
        if (draft.isCustomUnitChosen) ...<Widget>[
          const SizedBox(height: MTSpacing.s3),
          AddMedicineTextInput(
            // A key, so that this field is not reused as some other field's
            // state if the tree around it changes shape.
            key: const ValueKey<String>('add-medicine-custom-unit'),
            placeholder: AddMedicineCopy.customUnitPlaceholder,
            initialValue: draft.customUnit,
            onChanged: controller.setCustomUnit,
          ),
        ],
      ],
    );
  }
}

/// A section label, aligned to the leading edge inside a stretched column.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: AddMedicineSectionLabel(text),
  );
}

/// A row of chips that reflows onto more lines rather than running out of
/// horizontal room.
///
/// A `Wrap`, not a `Row`: at the largest accessibility text size four form
/// chips will not fit across a phone, and UX-DR20 requires the content to
/// reflow vertically instead of truncating.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: MTSpacing.s2, runSpacing: MTSpacing.s2, children: children);
}
