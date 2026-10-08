import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/body_age.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/morphing_shape.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/wavy_bar.dart';
import '../../widgets/entrance.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/section_card.dart';
import '../profile/birth_date_sheet.dart';
import '../../l10n/generated/app_localizations.dart';

/// The body age from what the app holds, or null while the store is not
/// read or the date of birth is not known.
BodyAge? bodyAgeOf(HealthController health, SettingsController settings) {
  final birthDate = settings.birthDate;
  if (birthDate == null || health.status != HealthStatus.ready) return null;
  final snapshot = health.snapshot;
  double? latest(Metric metric) =>
      latestKnown(snapshot, health.history, metric)?.value;
  return estimateBodyAge(
    birthDate: birthDate,
    sex: settings.sex,
    snapshot: snapshot,
    weight: latest(Metric.weight),
    height: latest(Metric.height),
    bodyFat: latest(Metric.bodyFat),
    systolic: latest(Metric.systolic),
    diastolic: latest(Metric.diastolic),
  );
}

/// 0.6 becomes "+0,6 Jahre", -1 becomes "−1,0 Jahre".
String formatYears(Formats formats, double years) {
  final rounded = (years * 10).round() / 10;
  if (rounded == 0) return formats.l10n.yearsZero;
  return formats.l10n.yearsSigned(
    '${rounded < 0 ? '−' : '+'}${formats.decimal(rounded.abs())}',
  );
}

/// How the body age comes about: every factor with the user's value, the
/// value it is judged against and the years it adds or takes.
class BodyAgePage extends StatelessWidget {
  const BodyAgePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return PageAccent.day(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, settings]),
        builder: (context, _) => SubPage(
          title: AppLocalizations.of(context).bodyAge,
          glass: settings.liquidGlass,
          child: health.status == HealthStatus.ready
              ? _content(context, health, settings)
              : const SizedBox(
                  height: 240,
                  child: Center(child: M3ELoadingIndicator()),
                ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    HealthController health,
    SettingsController settings,
  ) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final result = bodyAgeOf(health, settings);
    if (result == null) {
      return SectionCard(
        title: l10n.birthDateMissing,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.birthDateWhy, style: muted),
            const SizedBox(height: 16),
            M3EFilledButton.tonal(
              onPressed: () => showBirthDateSheet(context),
              child: Text(l10n.enterBirthDate),
            ),
          ],
        ),
      );
    }

    final snapshot = health.snapshot;
    final weight = latestKnown(snapshot, health.history, Metric.weight);
    final height = latestKnown(snapshot, health.history, Metric.height);
    final sections = <Widget>[
      _Overview(result: result),
      TitledSection(
        title: l10n.ageFactorsTitle,
        child: SegmentGroup(
          from: 1,
          children: [
            for (final factor in result.factors)
              _FactorCard(factor: factor, sex: settings.sex),
          ],
        ),
      ),
      TitledSection(
        title: l10n.yourDetails,
        note: l10n.changeInProfile,
        child: SegmentGroup(
          children: [
            _Line(l10n.birthDate, formats.birthDate(settings.birthDate!)),
            _Line(l10n.sex, switch (settings.sex) {
              Sex.female => l10n.female,
              Sex.male => l10n.male,
              null => l10n.notGiven,
            }),
            _Line(
              l10n.heightLabel,
              height == null
                  ? l10n.noMeasurement
                  : '${height.value.round()} cm',
            ),
            _Line(
              l10n.metricWeight,
              weight == null
                  ? l10n.noMeasurement
                  : '${formats.decimal(weight.value)} kg, '
                        '${formats.relativeDay(weight.day, snapshot.today)}',
            ),
          ],
        ),
      ),
      SectionCard(
        title: l10n.howCalculated,
        child: Text(
          l10n.howCalculatedBody(
            snapshot.dayCount,
            minFactorDays,
            minAgeFactors,
          ),
          style: muted,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Entrance(order: i, child: sections[i]),
        ],
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.result});

  final BodyAge result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final age = result.age;
    final difference = result.difference;
    final real = formats.decimal(result.chronological);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    // The age stands free on its shape: the younger, the sunnier.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          MorphingShape(
            shape: switch (difference) {
              null => Shapes.circle,
              final d when d < -0.05 => Shapes.verySunny,
              final d when d > 0.05 => Shapes.c6SidedCookie,
              _ => Shapes.c9SidedCookie,
            },
            color: accent.accent,
            size: 132,
            child: Text(
              age == null ? '–' : formats.decimal(age),
              style: type.hero(
                context.emphasizedTextTheme.headlineLarge?.copyWith(
                  color: accent.onAccent,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (difference) {
                  null => l10n.tooLittleData,
                  final d when d.abs() < 0.05 => l10n.exactlyYourAge(real),
                  final d when d < 0 => l10n.yearsYounger(
                    formats.decimal(-d),
                    real,
                  ),
                  final d => l10n.yearsOlder(formats.decimal(d), real),
                }, style: type.title(context.emphasizedTextTheme.titleLarge)),
                const SizedBox(height: 4),
                Text(
                  age == null
                      ? l10n.needFactors(minAgeFactors)
                      : l10n.estimateLast30,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One factor: the user's value, what it is judged against, and where it
/// lies between the worst and the best end.
class _FactorCard extends StatelessWidget {
  const _FactorCard({required this.factor, required this.sex});

  final AgeFactor factor;
  final Sex? sex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final years = factor.years;
    final position = factor.position;
    final value = factor.value;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _title(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.strong(theme.textTheme.titleMedium),
              ),
            ),
            if (years != null)
              Text(
                formatYears(formats, years),
                style: type.figure(
                  context.emphasizedTextTheme.titleMedium?.copyWith(
                    color: accent.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (value == null)
          Text(_missing(l10n), style: muted)
        else ...[
          Text(_reading(formats, value), style: theme.textTheme.bodyLarge),
          if (position != null) ...[
            const SizedBox(height: 10),
            WavyBar(value: position, color: accent.accent),
          ],
          const SizedBox(height: 8),
          Text(
            years == null
                ? l10n.notCountedYet(factor.days, minFactorDays)
                : _guide(formats),
            style: muted,
          ),
        ],
      ],
    );
  }

  String _title(AppLocalizations l10n) => switch (factor.kind) {
    AgeFactorKind.steps => l10n.metricSteps,
    AgeFactorKind.intensity => l10n.factorIntensity,
    AgeFactorKind.sleepDuration => l10n.sleepDuration,
    AgeFactorKind.sleepRegularity => l10n.factorSleepRhythm,
    AgeFactorKind.restingHeartRate => l10n.metricRestingHeartRate,
    AgeFactorKind.heartRateVariability => l10n.metricHeartRateVariability,
    AgeFactorKind.bodyFat => l10n.metricBodyFat,
    AgeFactorKind.bodyMassIndex => l10n.metricBodyMassIndex,
    AgeFactorKind.bloodPressure => l10n.bloodPressure,
    AgeFactorKind.strength => l10n.workoutStrength,
  };

  String _missing(AppLocalizations l10n) => switch (factor.kind) {
    AgeFactorKind.bodyFat ||
    AgeFactorKind.bodyMassIndex => l10n.missingWeightOrHeight,
    AgeFactorKind.bloodPressure => l10n.noMeasurementSentence,
    AgeFactorKind.strength => l10n.noWorkouts30,
    _ => l10n.noData30,
  };

  String _reading(Formats formats, double value) {
    final l10n = formats.l10n;
    final days = factor.days;
    final whole = '${value.round()}';
    return switch (factor.kind) {
      AgeFactorKind.steps => l10n.readingSteps(
        formats.integer(value.round()),
        days,
      ),
      AgeFactorKind.intensity => l10n.readingIntensity(whole, days),
      AgeFactorKind.sleepDuration => l10n.readingSleep(
        formats.duration((value * 60).round()),
        days,
      ),
      AgeFactorKind.sleepRegularity => l10n.readingRegularity(value.round()),
      AgeFactorKind.restingHeartRate => l10n.readingBpm(whole, days),
      AgeFactorKind.heartRateVariability => l10n.readingMs(whole, days),
      AgeFactorKind.bodyFat => l10n.percentText(formats.decimal(value)),
      AgeFactorKind.bodyMassIndex => formats.decimal(value),
      AgeFactorKind.bloodPressure =>
        '${value.round()}/${factor.second!.round()} mmHg',
      AgeFactorKind.strength => l10n.readingStrength(formats.decimal(value)),
    };
  }

  String _guide(Formats formats) {
    final l10n = formats.l10n;
    String number(double value) => value == value.roundToDouble()
        ? formats.integer(value.round())
        : formats.decimal(value);
    String ends(AgeCurve curve, [String Function(String)? withUnit]) {
      String unit(String number) => withUnit?.call(number) ?? number;
      final lowIsBest = curve.first.$2 < curve.last.$2;
      final neutral = unit(number(neutralOf(curve)));
      final best = unit(number((lowIsBest ? curve.first : curve.last).$1));
      return lowIsBest
          ? l10n.guideLowBest(neutral, best)
          : l10n.guideHighBest(neutral, best);
    }

    return switch (factor.kind) {
      AgeFactorKind.steps => ends(stepsCurve),
      AgeFactorKind.intensity => ends(intensityCurve, (n) => '$n min'),
      AgeFactorKind.sleepDuration => l10n.guideSleep(
        formats.decimal(7.5),
        formats.decimal(8.5),
        '7',
        '9',
      ),
      AgeFactorKind.sleepRegularity => ends(
        sleepRegularityCurve,
        (n) => '$n min',
      ),
      AgeFactorKind.restingHeartRate => ends(
        restingHeartRateCurve(sex),
        (n) => '$n bpm',
      ),
      AgeFactorKind.heartRateVariability => l10n.guideHrv(
        factor.second!.round(),
        (factor.second! * heartRateVariabilityCurve.last.$1).round(),
      ),
      AgeFactorKind.bodyFat => ends(
        bodyFatCurve(sex ?? Sex.male),
        l10n.percentText,
      ),
      AgeFactorKind.bodyMassIndex => l10n.guideBmi,
      AgeFactorKind.bloodPressure => l10n.guideBloodPressure,
      AgeFactorKind.strength => l10n.guideStrength,
    };
  }
}

/// A name and its value on one line.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = AppType.of(context);
    return Row(
      children: [
        Text(label, style: type.strong(theme.textTheme.titleSmall)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: type.figure(theme.textTheme.titleMedium),
          ),
        ),
      ],
    );
  }
}
