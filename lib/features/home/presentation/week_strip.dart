// UX-DR9: seven day pills, letter above number, dot below for "has doses".
// The current day is selected and highlighted; tapping another day does
// nothing yet (Story 4.4, this spec's own Never rule) -- so there is no
// `onTap` anywhere in this file.
//
// `rounded/pill`, not `rounded/lg`: DESIGN.md's Shapes prose names "day pills"
// by name among the pill-radius components, which the delivered mock's own
// literal `border-radius:16px` does not override -- `imports/README.md`'s own
// rule is that the contract wins only where it explicitly says so, and this is
// exactly that case, the same way this spec's own Code Map corrects the
// overdue card's colour against the mock rather than reproducing it.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';
import '../application/home_plan_controller.dart';
import 'home_copy.dart';

/// The seven-pill rolling week strip.
class WeekStrip extends StatelessWidget {
  const WeekStrip({required this.days, super.key});

  /// Exactly seven entries, today first (`HomePlanController`'s own
  /// contract).
  final List<HomeWeekDay> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < days.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: MTSpacing.s1),
          Expanded(child: _DayPill(day: days[i])),
        ],
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day});

  final HomeWeekDay day;

  @override
  Widget build(BuildContext context) {
    final bool selected = day.isToday;
    final Color letterColor = selected
        ? MTColors.surfaceRaised
        : MTColors.inkFaint;
    final Color numberColor = selected
        ? MTColors.surfaceRaised
        : MTColors.inkPrimary;
    final Color dotColor = selected ? MTColors.surfaceRaised : MTColors.accent;

    return Semantics(
      label: _label(day),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? MTColors.accent : null,
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.pill)),
          boxShadow: selected ? const <BoxShadow>[MTElevation.accent] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MTSpacing.s2,
            horizontal: MTSpacing.s1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                HomeCopy.weekdayLetters[day.date.weekday],
                style: MTTypography.label.copyWith(color: letterColor),
              ),
              const SizedBox(height: MTSpacing.s1),
              Text(
                '${day.date.day}',
                style: MTTypography.title.copyWith(color: numberColor),
              ),
              const SizedBox(height: MTSpacing.s1),
              SizedBox(
                height: MTSpacing.s1,
                child: day.hasDoses
                    ? Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: dotColor,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(MTRadius.pill),
                            ),
                          ),
                          child: const SizedBox(
                            width: MTSpacing.s1,
                            height: MTSpacing.s1,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _label(HomeWeekDay day) {
    final String named = HomeCopy.formattedDate(day.date);
    final String today = day.isToday ? 'Today, ' : '';
    final String doses = day.hasDoses ? ', has doses scheduled' : '';
    return '$today$named$doses';
  }
}
