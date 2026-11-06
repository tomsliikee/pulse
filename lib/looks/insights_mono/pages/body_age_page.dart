import 'package:material_ui/material_ui.dart';

import '../../../data/body_age.dart';
import '../../../data/health_controller.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../features/age/body_age_page.dart' show AgeFactorView, bodyAgeOf;
import '../../../features/profile/birth_date_sheet.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_page.dart';

/// How the body age comes about, in the look: every factor with the
/// person's value, what it is judged against and the years it adds or
/// takes, the details it rests on, and how it is worked out.
class MonoBodyAgePage extends StatelessWidget {
  const MonoBodyAgePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final formats = c.formats;
        final t = c.t;
        final health = c.health;
        final settings = c.settings;
        final result = health.status == HealthStatus.ready
            ? bodyAgeOf(health, settings)
            : null;
        if (result == null) {
          return MonoSubPage(
            category: MonoCategory.body,
            icon: Icons.cake_rounded,
            categoryLabel: l10n.bodyAge,
            backLabel: l10n.monoLongevity,
            statement: l10n.birthDateMissing,
            children: [
              MonoSurface(
                child: Text(l10n.birthDateWhy, style: MonoType.body(t)),
              ),
              MonoSurface(
                onTap: () => showBirthDateSheet(context),
                child: MonoRow(title: l10n.enterBirthDate),
              ),
            ],
          );
        }
        final snapshot = health.snapshot;
        final weight = latestKnown(snapshot, health.history, Metric.weight);
        final height =
            settings.heightCm ??
            latestKnown(snapshot, health.history, Metric.height)?.value.round();
        final age = result.age;
        final real = formats.decimal(result.chronological);
        final statement = switch (result.difference) {
          null => l10n.tooLittleData,
          final d when d.abs() < 0.05 => l10n.exactlyYourAge(real),
          final d when d < 0 => l10n.yearsYounger(formats.decimal(-d), real),
          final d => l10n.yearsOlder(formats.decimal(d), real),
        };
        return MonoSubPage(
          category: MonoCategory.body,
          icon: Icons.cake_rounded,
          categoryLabel: l10n.bodyAge,
          backLabel: l10n.monoLongevity,
          statement: statement,
          children: [
            MonoSurface(
              child: Row(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.recovery,
                    ),
                    child: Text(
                      age == null ? '–' : formats.decimal(age),
                      style: MonoType.number(t, size: 30).copyWith(color: t.bg),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      age == null
                          ? l10n.needFactors(minAgeFactors)
                          : l10n.estimateLast30,
                      style: MonoType.sub(t),
                    ),
                  ),
                ],
              ),
            ),
            MonoBlock(
              title: l10n.ageFactorsTitle,
              child: MonoList(
                gap: 22,
                children: [
                  for (final factor in result.factors)
                    AgeFactorView(factor: factor, sex: settings.sex),
                ],
              ),
            ),
            MonoBlock(
              title: l10n.yourDetails,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoList(
                    children: [
                      MonoPair(
                        label: l10n.birthDate,
                        value: formats.birthDate(settings.birthDate!),
                      ),
                      MonoPair(
                        label: l10n.sex,
                        value: switch (settings.sex) {
                          Sex.female => l10n.female,
                          Sex.male => l10n.male,
                          null => l10n.notGiven,
                        },
                      ),
                      MonoPair(
                        label: l10n.heightLabel,
                        value: height == null
                            ? l10n.noMeasurement
                            : '$height cm',
                      ),
                      MonoPair(
                        label: l10n.metricWeight,
                        value: weight == null
                            ? l10n.noMeasurement
                            : '${formats.decimal(weight.value)} kg',
                        sub: weight == null
                            ? null
                            : formats.relativeDay(weight.day, snapshot.today),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MonoNote(l10n.changeInProfile),
                ],
              ),
            ),
            MonoBlock(
              title: l10n.howCalculated,
              child: MonoSurface(
                child: Text(
                  l10n.howCalculatedBody(
                    snapshot.dayCount,
                    minFactorDays,
                    minAgeFactors,
                  ),
                  style: MonoType.sub(t),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
