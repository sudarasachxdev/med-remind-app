// The design token layer, in one import.
//
// Every screen from Story 1.3 onward composes from the same colour, type,
// radius and spacing scales. Consumers write:
//
//     import 'package:med_remind_app/shared/design/design.dart';
//
// and reach `MTColors`, `MTTypography`, `MTRadius` and `MTSpacing`. Importing
// one of the three files directly is equally valid; this barrel exists so that
// a widget needing all four namespaces carries one line, not four.
//
// The tokens are values only. Nothing here builds a `ThemeData` — the
// composition root is Story 1.3's, and wiring a theme from this layer would put
// a piece of that story here where nothing points at it.

export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';
