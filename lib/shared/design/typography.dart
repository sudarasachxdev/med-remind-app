// The product's twelve type styles.
//
// Transcribed from the `typography:` frontmatter of `DESIGN.md`, which is the
// source of truth for both the names and the values. Names are the
// frontmatter's keys, lower-camelled: `display`, `figure`, `control`,
// `headingXl`, `headingLg`, `headingMd`, `headingSm`, `title`, `body`, `meta`,
// `label`, `chip`. Nothing the frontmatter does not declare is set here — no
// `fontFamily`, no `height`, no `letterSpacing`, no colour. Ink comes from
// `MTColors`; a type style says how text is set, never what colour it is.
//
// PLATFORM-NATIVE FACES. No `fontFamily` is set on any style, so text renders
// in the platform stack — SF Pro on iOS, Roboto on Android. `pubspec.yaml`
// bundles no font and this story adds none.
//
// DYNAMIC TYPE (NFR-5). A `fontSize` here is a base size, not a fixed one:
// Flutter multiplies it by the ambient `TextScaler`, which follows the OS text
// size setting. Honouring Dynamic Type therefore means *not* interfering —
// nothing in this layer sets `TextScaler`, overrides `MediaQuery.textScaler`,
// or pins a `height` that would stop a scaled line from growing. The dose card
// is the critical case: at the largest accessibility size its name, meta line
// and status chip must reflow vertically rather than truncate, which is a
// layout obligation on the widgets that consume these styles.
//
// ALL-CAPS is a property of the copy passed to `label`, not of the style: the
// frontmatter declares no `letterSpacing` or text transform, so none is
// invented here. `DOSAGE`, `SCHEDULES`, `REMINDERS` and `DATA` are the only
// capitals in the product.

import 'package:flutter/painting.dart';

/// The twelve type styles declared by `DESIGN.md`.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTTypography {
  /// `display` — the platform's large title, used only for the lock-screen
  /// clock.
  ///
  /// Deliberately empty. The frontmatter declares no size and no weight for
  /// this style, only the note *"Platform native — iOS Large Title"*, so
  /// nothing is pinned: the style inherits whatever the platform's large title
  /// resolves to. Inventing a size here would be inventing a value the design
  /// does not declare.
  static const TextStyle display = TextStyle();

  /// `figure` — the History record card count. The largest number in the
  /// product.
  static const TextStyle figure = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
  );

  /// `control` — the add-medicine time control numeral.
  static const TextStyle control = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
  );

  /// `heading-xl` — the onboarding lead alone: "Never lose track of a dose".
  static const TextStyle headingXl = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
  );

  /// `heading-lg` — screen titles: the Home greeting name, Schedule, History,
  /// Settings, onboarding panels 2 and 3, the error title, and the dose-amount
  /// stepper. The workhorse of the heading scale.
  static const TextStyle headingLg = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
  );

  /// `heading-md` — the stepped-flow questions: "What are you taking, and how
  /// much?"
  static const TextStyle headingMd = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w700,
  );

  /// `heading-sm` — the medicine detail name and the dose action-sheet title.
  static const TextStyle headingSm = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
  );

  /// `title` — card names, medicine names, section headers.
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  /// `body` — primary reading text and explanatory copy.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  /// `meta` — dose metadata, timestamps, secondary rows.
  ///
  /// The frontmatter declares the size as the range `13-13.5px`. A constant
  /// cannot carry a range, so this takes its lower bound rather than inventing
  /// a second token for the upper one. It is the last ranged size left: the
  /// heading range became six discrete steps on 2026-09-06.
  static const TextStyle meta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// `label` — the ALL-CAPS section labels that group form sections: `DOSAGE`,
  /// `SCHEDULES`, `REMINDERS`, `DATA`.
  static const TextStyle label = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  /// `chip` — status chips and dose badges. A chip always carries a word, never
  /// a colour alone.
  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
}
