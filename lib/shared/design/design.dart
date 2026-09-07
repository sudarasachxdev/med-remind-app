// The design token layer, in one import.
//
// Every screen from Story 1.3 onward composes from the same colour, type,
// radius and spacing scales. Consumers write:
//
//     import 'package:med_remind_app/shared/design/design.dart';
//
// and reach every `MT*` namespace: `MTColors`, `MTTypography`, `MTRadius`,
// `MTSpacing`, `MTElevation`, `MTTranslucency`, `MTMotion` and `MTDimensions`.
// Importing one of the files directly is equally valid; this barrel exists so
// that a widget needing several namespaces carries one line, not several.
//
// The tokens are values only. Nothing here builds a `ThemeData` — the
// composition root is Story 1.3's, and wiring a theme from this layer would put
// a piece of that story here where nothing points at it.

export 'colors.dart';
export 'dimensions.dart';
export 'elevation.dart';
export 'motion.dart';
export 'spacing.dart';
export 'translucency.dart';
export 'typography.dart';
