// The controls the three add-medicine steps share.
//
// Five atoms, in one file because each of them appears on more than one step
// and a copy per step is how two chips end up a pixel apart. They are private
// to this feature rather than promoted to `lib/shared/widgets/`: the step
// progress bar was promoted because it has two callers in two *features*, and
// these have one feature each. The story that gives them a second feature is
// the story that should move them, with that caller in hand to shape them --
// the same rule the step bar was held to.
//
// ---------------------------------------------------------------------------
// TWO MEASURED VALUES COULD NOT BE TRANSCRIBED, and both are recorded here
// rather than absorbed silently.
//
// 1. THE 1.5px BORDER. The delivered screens draw `1.5px solid` around the
//    inputs, the chips, the repeat rows and the step-3 card, and `1px` for the
//    separators inside them. DESIGN.md declares no border-width family at all
//    -- there is no `dimensions/border-hairline` -- and this story may not add
//    a token. Nor may it write the number: `test/architecture_test.dart` flags
//    a literal on any `width:`, which is exactly the guard that should catch
//    this. So every border here takes `BorderSide`'s own default of 1.0 and
//    names no number anywhere. The visible cost is half a logical pixel on an
//    edge; the alternative was a magic number in a feature or a token invented
//    outside the contract. A `border-width` family is a real gap in DESIGN.md
//    and is the UX owner's call, in the same class as the type-size gap
//    `_PanelParagraph` records in onboarding.
//
// 2. THE 42px TIME STEPPER. Step 1's dose stepper is 46px, which is
//    `dimensions/control-md` exactly. Step 2's time stepper measures 42px,
//    which no token declares. `dimensions/control-sm` is 38 and its declared
//    role is literally "a compact square control: a stepper arrow", so the two
//    steppers take the two control tokens -- 46 and 38. They stay two sizes,
//    which is what the story's Design Notes insist on ("Transcribe both; do not
//    unify them"); the smaller is 4px under its measurement. Same reasoning as
//    above: no new token, and no number chosen by feel.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';

/// A step's question, in the type DESIGN.md reserves for it.
///
/// `heading-md` -- "The stepped-flow questions: 'What are you taking, and how
/// much?'". Announced as a heading so a screen reader can jump to it, and
/// never capped or ellipsised: at the largest accessibility size it wraps to
/// as many lines as it needs and the screen scrolls.
class AddMedicineStepHeading extends StatelessWidget {
  const AddMedicineStepHeading(this.text, {super.key});

  /// The question.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: MTTypography.headingMd.copyWith(color: MTColors.inkPrimary),
      ),
    );
  }
}

/// One of the flow's ALL-CAPS section labels -- `FORM`, `DOSE PER TIME`.
///
/// The capitals are a property of the copy, not of the style: DESIGN.md
/// declares no text transform on `label`, so none is applied here and the
/// strings are already shouted in `add_medicine_copy.dart`.
class AddMedicineSectionLabel extends StatelessWidget {
  const AddMedicineSectionLabel(this.text, {super.key});

  /// The label, already in capitals.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MTTypography.label.copyWith(color: MTColors.inkFaint),
    );
  }
}

/// A selectable chip, used for the form and the unit.
///
/// TOKENS. `pill`; selected is `accentWash` on `accentBorder` with **`accentInk`**
/// ink, unselected is `surfaceSunken` on `borderHairline` with `inkSecondary`.
///
/// The one sanctioned divergence from the mock is the selected ink. The mock
/// measures `#3D3568`, which is not in the palette; `accent-ink` `#5B4FBE`
/// already exists for exactly this role -- reading text on `accent-wash` -- and
/// both clear AA on that surface comfortably (5.43:1 for the token). Adding a
/// thirty-first colour one step darker for a role already covered is the scale
/// bloat the radius consolidation argued against.
class AddMedicineChip extends StatelessWidget {
  const AddMedicineChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The chip's word.
  final String label;

  /// Whether this chip is the chosen one.
  final bool selected;

  /// Chooses this chip.
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onSelected,
      // One node per chip. Without this the label is announced by the inner
      // Text as well, so a reader hears every chip twice -- and the selected
      // state, which is on this node, would be announced apart from the word
      // it applies to.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onSelected,
        // Opaque, so the whole padded box is the target rather than the
        // glyphs of the word inside it.
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          // The tap floor applies to a chip as much as to a button. The chip's
          // own padding already clears it at the default text size; this holds
          // it if the copy or the padding ever shrinks.
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MTSpacing.s4,
                vertical: MTSpacing.s3,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: MTTypography.body.copyWith(
                    color: selected
                        ? MTColors.accentInk
                        : MTColors.inkSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One arrow of a stepper: a square control on `surfaceRaised`, inside a target
/// padded out to the platform floor.
///
/// The drawn box is [size] and the target is always
/// `MTDimensions.touchMinAndroid`, because both control tokens are smaller than
/// the floor -- `MTDimensions.controlMd` is 46 and its own doc says so: "Below
/// touchMinAndroid, so a control drawn at this size still needs its tappable
/// area padded out to the platform floor."
class AddMedicineStepperButton extends StatelessWidget {
  const AddMedicineStepperButton({
    required this.icon,
    required this.iconColor,
    required this.semanticsLabel,
    required this.size,
    required this.onPressed,
    super.key,
  });

  /// The arrow.
  final IconData icon;

  /// The arrow's ink. `inkSecondary` on step 1, `accent` on step 2 -- both
  /// measured, and both used twice.
  final Color iconColor;

  /// What a screen reader announces. The mock's control is an icon glyph, which
  /// announces as nothing, so every stepper arrow carries a composed label --
  /// see `add_medicine_copy.dart`.
  final String semanticsLabel;

  /// The drawn size: a `MTDimensions` control token.
  final double size;

  /// Steps the value. Never `null`: at a floor the step is *inert*, which the
  /// draft expresses by returning an equal draft, rather than disabled -- there
  /// is nothing to explain about a dose that cannot go below one, and a control
  /// that greys out mid-interaction is harder to read than one that does
  /// nothing.
  final VoidCallback onPressed;

  /// The arrow glyph's size.
  ///
  /// A single-use measurement inside one component, which DESIGN.md's
  /// `dimensions` note puts here rather than in the contract: "The other
  /// nineteen are single-use measurements inside one component -- an icon
  /// inset, a badge offset -- and belong to that component's own story rather
  /// than to the contract. The test that a size belongs there is whether two
  /// components built independently could disagree about it." Both steppers
  /// draw their arrows at 24, so there is nothing to disagree about.
  static const double _arrowSize = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: MTDimensions.touchMinAndroid,
          height: MTDimensions.touchMinAndroid,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: MTColors.surfaceRaised,
                  borderRadius: BorderRadius.all(Radius.circular(MTRadius.md)),
                ),
                child: Center(
                  child: Icon(icon, size: _arrowSize, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The standard stepper: two `control-md` buttons flanking a large numeral, on
/// a `surfaceApp` card.
///
/// DESIGN.md's Stepper component, and the shape both numeric controls in this
/// flow take -- the dose amount on step 1 and, per DESIGN.md's Interval stepper
/// entry ("the standard stepper on N, minimum 2"), the repeat interval on step
/// 2. One widget rather than two, so the two cannot drift apart.
///
/// The step-2 TIME control is deliberately NOT this widget: it is measured at a
/// different button size with accent-coloured arrows, and the story's Design
/// Notes are explicit that the two sizes are not a mistake and must not be
/// unified.
class AddMedicineValueStepper extends StatelessWidget {
  const AddMedicineValueStepper({
    required this.value,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.onDecrement,
    required this.onIncrement,
    super.key,
  });

  /// The numeral between the arrows.
  final int value;

  /// What a screen reader announces on the minus.
  final String decrementLabel;

  /// What a screen reader announces on the plus.
  final String incrementLabel;

  /// Steps down. Inert at the floor rather than disabled.
  final VoidCallback onDecrement;

  /// Steps up.
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MTColors.surfaceApp,
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.xl)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpacing.s3,
          vertical: MTSpacing.s2,
        ),
        child: Row(
          children: <Widget>[
            AddMedicineStepperButton(
              icon: Icons.remove,
              iconColor: MTColors.inkSecondary,
              semanticsLabel: decrementLabel,
              size: MTDimensions.controlMd,
              onPressed: onDecrement,
            ),
            // Expanded rather than a fixed width, so the numeral has the whole
            // middle of the card at any text size and the two buttons keep
            // their measured size.
            Expanded(
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: MTTypography.headingLg.copyWith(
                  color: MTColors.inkPrimary,
                ),
              ),
            ),
            AddMedicineStepperButton(
              icon: Icons.add,
              iconColor: MTColors.inkSecondary,
              semanticsLabel: incrementLabel,
              size: MTDimensions.controlMd,
              onPressed: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

/// A text input in the flow's own shape.
///
/// Stateful for one reason: it owns its `TextEditingController`, initialised
/// from the draft and never reset while the field is on screen. The draft is
/// the source of truth -- Back preserves it, and the field is rebuilt from it
/// when the step is revisited -- but writing the draft's value back into the
/// controller on every rebuild would move the cursor to the end on every
/// keystroke.
class AddMedicineTextInput extends StatefulWidget {
  const AddMedicineTextInput({
    required this.placeholder,
    required this.initialValue,
    required this.onChanged,
    this.textStyle = MTTypography.title,
    super.key,
  });

  /// The placeholder, which is also the field's screen-reader label -- there is
  /// no floating label in this design, so the hint is the only word the field
  /// has.
  final String placeholder;

  /// The value the field opens with, from the draft.
  final String initialValue;

  /// Called on every keystroke.
  final ValueChanged<String> onChanged;

  /// The type the value is set in. `title` 17 for the name, as measured.
  final TextStyle textStyle;

  @override
  State<AddMedicineTextInput> createState() => _AddMedicineTextInputState();
}

class _AddMedicineTextInputState extends State<AddMedicineTextInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: widget.textStyle.copyWith(color: MTColors.inkPrimary),
      cursorColor: MTColors.accent,
      // No maxLines and no ellipsis: at the largest accessibility size the
      // field grows rather than clipping what was typed.
      minLines: 1,
      maxLines: null,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: widget.textStyle.copyWith(color: MTColors.inkFaint),
        filled: true,
        fillColor: MTColors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MTSpacing.s4,
          vertical: MTSpacing.s4,
        ),
        enabledBorder: _border(MTColors.borderStrong),
        focusedBorder: _border(MTColors.accent),
        border: _border(MTColors.borderStrong),
      ),
    );
  }

  /// The field's outline. See the file comment for why no width is named.
  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
    borderSide: BorderSide(color: color),
  );
}

/// The flow's primary action: an accent-filled button with the accent-tinted
/// glow.
///
/// TOKENS. `accent` fill, `lg` 16, `title` 17/600, and **`elevation/accent`** --
/// `0 8px 20px rgba(108,92,231,.30)`, which is the shadow that token was
/// corrected to on 2026-09-07 precisely because this button is its most common
/// user in the delivered design.
///
/// The radius is `lg`, not the `pill` the app theme gives every other button:
/// the add flow's CTA is measured at 16 and the theme's shape is overridden
/// here rather than the theme being changed, because onboarding's actions are
/// genuinely pills.
///
/// The glow is dropped when the button is disabled. An accent-tinted lift under
/// a grey, unusable control reads as a rendering bug, and elevation in this
/// product signals actionability -- so an unactionable control has none.
class AddMedicinePrimaryAction extends StatelessWidget {
  const AddMedicinePrimaryAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// `Continue`, or `Save medicine` on step 3.
  final String label;

  /// The action, or `null` when the step is incomplete or a save is in flight.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
        boxShadow: enabled ? const <BoxShadow>[MTElevation.accent] : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MTRadius.lg)),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
