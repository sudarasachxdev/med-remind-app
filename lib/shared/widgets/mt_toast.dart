// The one toast every dose action confirms through (UX-DR14).
//
// DESIGN.md's `toast:` frontmatter: `'dark rounded rect · rounded/lg ·
// auto-dismiss 2.6s'` -- corrected 2026-09-11 against the mock's own measured
// 16px radius, which is exactly `MTRadius.lg`. Built as its own shared widget
// rather than reused from `AddMedicineScreen`'s bare `SnackBar`
// (`deferred-work.md`): that confirmation inherits Flutter's default look and
// 4-second duration, neither of which is the `toast` component this story's
// own acceptance criteria hold the sheet/overdue-row paths to.
//
// AN OVERLAY ENTRY, NOT A `SnackBar`. `ScaffoldMessenger` queues one SnackBar
// behind another and both its shape and its duration fight Material's own
// defaults at every turn; an `OverlayEntry` painted with the token trio
// (`inkPrimary` fill, `rounded/lg`, `elevation/overlay`) reproduces the mock's
// own `position:absolute` box exactly, and removes itself on a timer with no
// framework queue to fight.
//
// `Overlay.of(context)` is read before the timer starts, while the caller's
// context is still certainly mounted -- a caller that just popped a sheet or
// is about to trigger a list rebuild cannot be trusted to still have a valid
// context a whole toast-duration later, but the returned `OverlayEntry` needs
// nothing further from it once inserted.

import 'dart:async';

import 'package:flutter/material.dart';

import '../design/design.dart';

/// How long a toast shown by [showMtToast] stays before it removes itself --
/// DESIGN.md's own `auto-dismiss 2.6s`.
const Duration mtToastDuration = Duration(milliseconds: 2600);

/// Shows [message] in the product's toast, and returns once it has been
/// inserted (not once it has dismissed).
///
/// [context] must have an ancestor `Overlay` -- true of every screen reached
/// through the app's `MaterialApp`/`GoRouter` root, which is the only place
/// this is ever called from.
void showMtToast(BuildContext context, String message) {
  final OverlayState overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (context) => _MtToast(message: message));
  overlay.insert(entry);
  Timer(mtToastDuration, () {
    if (entry.mounted) entry.remove();
  });
}

/// The toast's own painted shape: `inkPrimary` fill, `rounded/lg`,
/// `elevation/overlay` -- DESIGN.md's `dark rounded rect`.
class _MtToast extends StatelessWidget {
  const _MtToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MTSpacing.s5,
      right: MTSpacing.s5,
      bottom: MTSpacing.s6,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          liveRegion: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: MTColors.inkPrimary,
              borderRadius: BorderRadius.all(Radius.circular(MTRadius.lg)),
              boxShadow: <BoxShadow>[MTElevation.overlay],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MTSpacing.s4,
                vertical: MTSpacing.s3,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: MTTypography.body.copyWith(
                  color: MTColors.surfaceRaised,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
