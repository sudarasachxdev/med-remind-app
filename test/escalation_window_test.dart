// The six Escalation Window rows of spec-1-6's I/O matrix (AD-16, AD-20).
// Testing depth is LIGHTER: one test per row, no mutation testing.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/policy/escalation_window_policy.dart';

void main() {
  final DateTime current = DateTime.utc(2026, 9, 9, 8, 0);

  test('twice daily: next dose of the same Medicine in 12h -> 3h', () {
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 12)),
        ),
      ],
    );

    expect(window, const Duration(hours: 3));
  });

  test('clamped low: next dose in 2h -> 1h floor', () {
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 2)),
        ),
      ],
    );

    expect(window, const Duration(hours: 1));
  });

  test('clamped high: next dose in 48h -> 6h ceiling', () {
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 48)),
        ),
      ],
    );

    expect(window, const Duration(hours: 6));
  });

  test('across Schedules: measured to the next dose of the same Medicine on a '
      'different Schedule, not the same Schedule (AD-20)', () {
    // Two Schedules of medicine-1: this occurrence's own Schedule has
    // nothing later today, but a *different* Schedule of the same
    // Medicine fires in 8h -- that is "the next dose" AD-20 means, and
    // picking it (8h/4=2h) rather than tomorrow's same-Schedule dose
    // (24h/4=6h, the ceiling) is what this test would catch getting wrong.
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 8)),
        ),
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 24)),
        ),
      ],
    );

    expect(window, const Duration(hours: 2));
  });

  test('none left today: measured to the Medicine\'s first dose on its next '
      'covered day', () {
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        // Nothing later today; the next occurrence is tomorrow morning.
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 24)),
        ),
      ],
    );

    expect(window, const Duration(hours: 6)); // 24h / 4 = 6h, the ceiling.
  });

  test('another medicine: the only nearer dose belongs to a different '
      'Medicine and is ignored (AD-20)', () {
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        // 30 minutes out, but a different Medicine -- must not be picked.
        (
          medicineId: 'medicine-2',
          scheduledAt: current.add(const Duration(minutes: 30)),
        ),
        // The real next dose of medicine-1, 12h out.
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 12)),
        ),
      ],
    );

    expect(
      window,
      const Duration(hours: 3),
      reason:
          'if the nearer, wrong-medicine candidate had been used the '
          'window would clamp to the 1h floor instead',
    );
  });

  test('a candidate at or before "now" is never picked as the next dose', () {
    final window = escalationWindowFor(
      current: (medicineId: 'medicine-1', scheduledAt: current),
      candidates: <DoseOccurrence>[
        (medicineId: 'medicine-1', scheduledAt: current), // itself
        (
          medicineId: 'medicine-1',
          scheduledAt: current.subtract(const Duration(hours: 1)),
        ), // in the past
        (
          medicineId: 'medicine-1',
          scheduledAt: current.add(const Duration(hours: 12)),
        ),
      ],
    );

    expect(window, const Duration(hours: 3));
  });

  test('no qualifying candidate throws rather than guessing a window', () {
    expect(
      () => escalationWindowFor(
        current: (medicineId: 'medicine-1', scheduledAt: current),
        candidates: const <DoseOccurrence>[],
      ),
      throwsArgumentError,
    );
  });
}
