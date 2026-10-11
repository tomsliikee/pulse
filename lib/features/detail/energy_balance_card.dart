import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../data/energy_balance.dart';
import '../../data/metric_catalog.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/detail_sections.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import 'metric_spec.dart';

/// What the person really burns, worked out from food and weight, with the
/// estimates beside it; or what is still missing for it.
class EnergyBalanceCard extends StatelessWidget {
  const EnergyBalanceCard({super.key, required this.balance});

  final EnergyBalance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final quiet = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final burn = balance.burn;
    const metric = Metric.totalEnergy;

    Widget row(String label, String value, {double? against}) => Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        Text(value, style: type.figure(theme.textTheme.titleMedium)),
        if (against != null) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: DifferenceText(
              text: against.round() == 0
                  ? '±0'
                  : '${against > 0 ? '+' : '−'}'
                        '${formats.integer(against.round().abs())}',
              good: null,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.balanceTitle),
        if (burn == null)
          SegmentGroup(
            children: [
              Text(l10n.balanceIntro(balanceDays), style: quiet),
              _Needed(
                done: balance.enoughFood,
                text: l10n.balanceFoodDays(balance.foodDays, balanceFoodDays),
              ),
              _Needed(
                done: balance.enoughWeight,
                text: l10n.balanceWeighIns(balance.weighIns, balanceWeighIns),
              ),
            ],
          )
        else
          SegmentGroup(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.formatWithUnit(formats, burn),
                    style: type.figure(
                      theme.textTheme.headlineMedium?.copyWith(
                        color: PageAccent.colorsOf(context).accent,
                      ),
                    ),
                  ),
                  Text(l10n.balancePerDay(balanceDays), style: quiet),
                ],
              ),
              row(
                l10n.balanceEaten,
                metric.formatWithUnit(formats, balance.eaten),
              ),
              row(
                l10n.balanceWeight,
                '${balance.kgPerWeek! > 0 ? '+' : ''}'
                '${formats.decimal(balance.kgPerWeek!, digits: 2)} kg',
              ),
              if (balance.source case final source?)
                row(
                  l10n.balanceSource,
                  metric.formatWithUnit(formats, source),
                  against: source - burn,
                ),
              if (balance.fine case final fine?)
                row(
                  l10n.balanceFine,
                  metric.formatWithUnit(formats, fine),
                  against: fine - burn,
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            l10n.balanceNote,
            style: type.aside(
              theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One thing the balance needs, ticked once it is there.
class _Needed extends StatelessWidget {
  const _Needed({required this.done, required this.text});

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
