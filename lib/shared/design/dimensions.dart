// The product's fixed component sizes.
//
// Transcribed from the `dimensions:` frontmatter of `DESIGN.md`, which is the
// source of truth.
//
// This is deliberately NOT a scale, and that distinction is the whole reason
// the file reads the way it does. `MTSpacing` and `MTRadius` are scales: a
// widget that needs some space picks a step, and any step is a defensible
// choice. Nothing here is interchangeable. A 52px glyph tile is 52 because the
// grid it sits in is built on 52; a 46px stepper button is 46 because that is
// the button. Naming these `d1`-`d19` would invite exactly the substitution the
// values cannot survive, so each is named for its role and there is no ordering
// to read into the list.
//
// The delivered screens use thirty-five distinct fixed sizes. Sixteen are
// declared here. The other nineteen are single-use measurements inside one
// component — an icon inset, a badge offset — and belong to that component's
// own story rather than to the contract. The test that a size belongs here is
// whether two components built independently could disagree about it.
//
// [touchMinIos] and [touchMinAndroid] are the exception to everything above:
// they are a floor, not a size. No interactive target may be smaller,
// regardless of how small the thing being drawn inside it looks.

/// The component sizes declared by `DESIGN.md`, in logical pixels.
///
/// Three of the frontmatter entries declare two numbers each — the two rings
/// declare an outer diameter and a knockout, and the toggle track declares a
/// width and a height — so sixteen declarations become nineteen constants. The
/// split is mechanical and the names keep the pairing visible.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTDimensions {
  /// `dimensions/touch-min-ios` — the smallest permissible interactive target
  /// on iOS. A floor, not a size.
  static const double touchMinIos = 44;

  /// `dimensions/touch-min-android` — the smallest permissible interactive
  /// target on Android. A floor, not a size.
  ///
  /// Larger than [touchMinIos]. A control sized to the iOS floor and shipped on
  /// both platforms is undersized on one of them, so a shared control takes
  /// this value.
  static const double touchMinAndroid = 48;

  /// `dimensions/tile-sm` — the smallest glyph tile: inline in a dense row.
  static const double tileSm = 38;

  /// `dimensions/tile-md` — the default glyph tile, as used in a dose card.
  static const double tileMd = 52;

  /// `dimensions/tile-lg` — a glyph tile carrying a medicine's identity in a
  /// list row.
  static const double tileLg = 64;

  /// `dimensions/tile-xl` — the glyph tile on a detail screen.
  static const double tileXl = 76;

  /// `dimensions/tile-2xl` — the glyph tile in the add-medicine chooser, where
  /// the tile is the thing being picked rather than a label on something else.
  static const double tile2xl = 88;

  /// `dimensions/control-sm` — a compact square control: a stepper arrow, a
  /// close button.
  static const double controlSm = 38;

  /// `dimensions/control-md` — the default square control, and the size of the
  /// add-medicine step buttons.
  ///
  /// Below [touchMinAndroid], so a control drawn at this size still needs its
  /// tappable area padded out to the platform floor.
  static const double controlMd = 46;

  /// `dimensions/ring-progress` outer diameter — the adherence ring on Home.
  static const double ringProgressOuter = 62;

  /// `dimensions/ring-progress` knockout diameter — the hole in the middle.
  ///
  /// The difference between this and [ringProgressOuter] is the stroke width,
  /// doubled. Deriving the stroke rather than declaring it keeps the ring from
  /// drifting thicker on one screen than another.
  static const double ringProgressKnockout = 48;

  /// `dimensions/ring-record` outer diameter — the larger ring on History.
  static const double ringRecordOuter = 74;

  /// `dimensions/ring-record` knockout diameter. See [ringProgressKnockout].
  static const double ringRecordKnockout = 58;

  /// `dimensions/toggle-track` width — the settings toggle.
  static const double toggleTrackWidth = 51;

  /// `dimensions/toggle-track` height.
  ///
  /// The track is a capsule, so its height is also its radius times two;
  /// `MTRadius.pill` rounds it without either number being restated.
  static const double toggleTrackHeight = 31;

  /// `dimensions/toggle-knob` diameter.
  ///
  /// Two pixels inside [toggleTrackHeight] on each side, which is the inset the
  /// knob's shadow needs to stay inside the track.
  static const double toggleKnob = 27;

  /// `dimensions/step-bar` — the height of one segment of the onboarding step
  /// bar.
  static const double stepBar = 4;

  /// `dimensions/timeline-dot` — the diameter of a node on the escalation
  /// timeline.
  static const double timelineDot = 11;

  /// `dimensions/timeline-connector` — the width of the line between two
  /// timeline dots.
  static const double timelineConnector = 2;
}
