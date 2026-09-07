// AD-22 — the glyph rule, on its own, without a database.
//
// The rule is `count(existing medicines) mod 4`, and this file pins both halves
// of it: the modulus, and the sequence it produces. A review pass changed the
// modulus in source and the whole suite stayed green, which is what these
// assertions exist to stop -- so they name 4 and they name 0,1,2,3,0 rather
// than recomputing the expected value with the same expression the code uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/policy/glyph_policy.dart';

void main() {
  group('glyphCount', () {
    test('is four, the number of glyphs DESIGN.md provides', () {
      expect(
        glyphCount,
        4,
        reason:
            'Four tile/silhouette pairs exist. Changing this permanently '
            'splits the record into medicines numbered under the old modulus '
            'and medicines numbered under the new one, because AD-22 forbids '
            'renumbering the ones already stored.',
      );
    });
  });

  group('glyphIndexForNewMedicine', () {
    test('the first five medicines get 0, 1, 2, 3, 0', () {
      // Spelled out rather than computed. `expect(f(i), i % glyphCount)` would
      // pass for any modulus, which is exactly the mutation that survived a
      // review round.
      expect(glyphIndexForNewMedicine(0), 0);
      expect(glyphIndexForNewMedicine(1), 1);
      expect(glyphIndexForNewMedicine(2), 2);
      expect(glyphIndexForNewMedicine(3), 3);
      expect(glyphIndexForNewMedicine(4), 0);
    });

    test('consecutive additions always differ', () {
      // The half of AD-22 that is a promise to the user: two medicines added
      // one after the other never wear the same glyph.
      for (int count = 0; count < 40; count++) {
        expect(
          glyphIndexForNewMedicine(count),
          isNot(glyphIndexForNewMedicine(count + 1)),
          reason: 'medicine $count and medicine ${count + 1} share a glyph',
        );
      }
    });

    test('the answer is always a glyph that exists', () {
      for (int count = 0; count < 40; count++) {
        expect(glyphIndexForNewMedicine(count), inInclusiveRange(0, 3));
      }
    });

    test('a negative count is a programming error, not a glyph', () {
      // Dart's `%` returns a non-negative result, so -1 would quietly become
      // a plausible-looking 3.
      expect(() => glyphIndexForNewMedicine(-1), throwsArgumentError);
    });
  });
}
