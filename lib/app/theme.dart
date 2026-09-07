// The one `ThemeData` in the product, built from the Story 1.2 token layer.
//
// Story 1.2 shipped the tokens as values and deliberately no theme, because a
// `ThemeData` is composition and `lib/app/` is the composition root. This is
// where the values become one.
//
// LIGHT ONLY. UX-DR22 puts dark mode out of scope for V1, so there is one
// theme, no `darkTheme`, no `themeMode`, and no brightness branch anywhere.
// `Brightness.light` is stated once, because `ColorScheme` requires it, and is
// never read back to choose between two palettes.
//
// The theme is a floor, not a replacement for the tokens. Framework widgets
// (`Scaffold`, `FilledButton`, `TextButton`) need defaults, and this supplies
// them from `MTColors` and `MTTypography` so nothing falls back to Material's
// own blues. Screens still name the token they mean — `MTTypography.headingXl`,
// `MTColors.inkTertiary` — rather than reaching for a Material text-theme slot
// whose mapping they would have to remember.
//
// Nothing here pins a font family or touches the text scaler: `fontSize` in a
// token is a base size that the ambient `TextScaler` multiplies, which is how
// NFR-5's Dynamic Type obligation is met — by not interfering.

import 'package:flutter/material.dart';

import '../shared/design/design.dart';

/// The product's light theme.
abstract final class MTTheme {
  /// The single `ThemeData` the app is built with.
  ///
  /// A `static final`, not a getter: the root widget reads it on every
  /// rebuild, and a getter would construct a fresh `ThemeData` -- and a fresh
  /// `TextTheme` and three fresh `ButtonStyle`s -- each time. Lazily
  /// initialised on first access, and immutable thereafter.
  static final ThemeData light = _buildLight();

  static ThemeData _buildLight() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      // `accent` is the only chromatic colour that carries interaction
      // meaning, so it is the only candidate for `primary`.
      primary: MTColors.accent,
      onPrimary: MTColors.surfaceRaised,
      // There is no second brand colour (DESIGN.md, Do's and Don'ts), so
      // `secondary` is the accent's low-emphasis partner rather than a new hue.
      secondary: MTColors.accentWash,
      onSecondary: MTColors.accentInk,
      // The only reds in the product, reserved for FR-3's Delete medicine
      // control (UX-DR21). Material insists on an error pair; these are it.
      error: MTColors.stateDangerInk,
      onError: MTColors.surfaceRaised,
      surface: MTColors.surfaceApp,
      onSurface: MTColors.inkPrimary,
      outline: MTColors.borderStrong,
      outlineVariant: MTColors.borderHairline,
      surfaceContainerHighest: MTColors.surfaceRaised,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MTColors.surfaceApp,
      canvasColor: MTColors.surfaceApp,
      textTheme: _textTheme,
      filledButtonTheme: FilledButtonThemeData(style: _primaryActionStyle),
      textButtonTheme: TextButtonThemeData(style: _secondaryActionStyle),
      // No `splashFactory` override. An earlier version pinned
      // `InkSparkle.splashFactory`, which no design document asks for and which
      // is not gated on `MediaQuery.disableAnimations` -- so it would have run
      // its animation for a user who had asked the OS to reduce motion.
      // Material's platform default already respects that setting.
    );
  }

  /// `MTTypography` mapped onto the Material slots, so a framework widget that
  /// reads the text theme gets the product's type rather than Material's.
  ///
  /// The mapping is by size order, largest first, which is the only mapping the
  /// design's roles support: the scale is six discrete heading steps plus
  /// title/body/meta/label/chip, and Material's slots are three families of
  /// three. Ink is applied once, here, because a token style carries no colour.
  static TextTheme get _textTheme => const TextTheme(
    displayLarge: MTTypography.figure,
    displayMedium: MTTypography.control,
    displaySmall: MTTypography.headingXl,
    headlineLarge: MTTypography.headingLg,
    headlineMedium: MTTypography.headingMd,
    headlineSmall: MTTypography.headingSm,
    titleLarge: MTTypography.title,
    titleMedium: MTTypography.title,
    titleSmall: MTTypography.title,
    bodyLarge: MTTypography.body,
    bodyMedium: MTTypography.body,
    bodySmall: MTTypography.meta,
    labelLarge: MTTypography.label,
    labelMedium: MTTypography.label,
    labelSmall: MTTypography.chip,
  ).apply(bodyColor: MTColors.inkPrimary, displayColor: MTColors.inkPrimary);

  /// The primary action: an accent-filled pill carrying white ink.
  ///
  /// `minimumSize` is [kMinInteractiveDimension] — 48 logical pixels, the
  /// framework's own name for the floor EXPERIENCE.md sets at 44pt/48dp. The
  /// height is a *minimum*, never a fixed size, so a label that grows under
  /// Dynamic Type grows the button instead of being clipped by it.
  static ButtonStyle get _primaryActionStyle => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return MTColors.surfaceInset;
      if (states.contains(WidgetState.pressed)) return MTColors.accentPressed;
      return MTColors.accent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return MTColors.inkDisabled;
      return MTColors.surfaceRaised;
    }),
    textStyle: const WidgetStatePropertyAll<TextStyle>(MTTypography.title),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size.fromHeight(kMinInteractiveDimension),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: MTSpacing.s5, vertical: MTSpacing.s3),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.pill)),
      ),
    ),
    elevation: const WidgetStatePropertyAll<double>(0),
  );

  /// The secondary action: accent ink on the page, no fill.
  ///
  /// Declining must never look like the lesser choice, so the secondary carries
  /// the same type weight and the same tap area as the primary. Only the fill
  /// differs, because two filled actions of equal weight would leave the user
  /// without a default.
  static ButtonStyle get _secondaryActionStyle => ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return MTColors.inkDisabled;
      if (states.contains(WidgetState.pressed)) return MTColors.accentPressed;
      return MTColors.accent;
    }),
    textStyle: const WidgetStatePropertyAll<TextStyle>(MTTypography.title),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size.fromHeight(kMinInteractiveDimension),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: MTSpacing.s5, vertical: MTSpacing.s3),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.pill)),
      ),
    ),
  );
}
