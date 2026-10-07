import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/body_age.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/settings_controller.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../profile/birth_date_sheet.dart';

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
String formatYears(double years) {
  final rounded = (years * 10).round() / 10;
  if (rounded == 0) return '±0 Jahre';
  return '${rounded < 0 ? '−' : '+'}${formatDecimal(rounded.abs())} Jahre';
}

/// How the body age comes about: every factor with the user's value, the
/// value it is judged against and the years it adds or takes.
class BodyAgePage extends StatelessWidget {
  const BodyAgePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([health, settings]),
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: theme.scaffoldBackgroundColor,
              title: Text(
                'Körperalter',
                style: context.emphasizedTextTheme.headlineMedium,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverToBoxAdapter(
                child: health.status == HealthStatus.ready
                    ? _content(context, health, settings)
                    : const SizedBox(
                        height: 240,
                        child: Center(child: M3ELoadingIndicator()),
                      ),
              ),
            ),
          ],
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
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final result = bodyAgeOf(health, settings);
    if (result == null) {
      return SectionCard(
        title: 'Geburtsdatum fehlt',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Das Körperalter geht von deinem echten Alter aus. Health '
              'Connect kennt es nicht, deshalb fragt Pulse danach.',
              style: muted,
            ),
            const SizedBox(height: 16),
            M3EFilledButton.tonal(
              onPressed: () => showBirthDateSheet(context),
              child: const Text('Geburtsdatum eintragen'),
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
      for (final factor in result.factors)
        _FactorCard(factor: factor, sex: settings.sex),
      SectionCard(
        title: 'Deine Angaben',
        child: Column(
          children: [
            _Line('Geburtsdatum', formatBirthDate(settings.birthDate!)),
            _Line('Geschlecht', switch (settings.sex) {
              Sex.female => 'Weiblich',
              Sex.male => 'Männlich',
              null => 'Nicht angegeben',
            }),
            _Line(
              'Größe',
              height == null ? 'Keine Messung' : '${height.value.round()} cm',
            ),
            _Line(
              'Gewicht',
              weight == null
                  ? 'Keine Messung'
                  : '${formatDecimal(weight.value)} kg, '
                        '${formatRelativeDay(weight.day, snapshot.today)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Geburtsdatum und Geschlecht änderst du im Profil.',
              style: muted,
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'So wird gerechnet',
        child: Text(
          'Pulse beginnt bei deinem echten Alter. Jeder Faktor zieht Jahre '
          'ab oder legt welche dazu, je nachdem, wo dein Wert der letzten '
          '${snapshot.dayCount} Tage zwischen dem besten und dem '
          'schlechtesten Ende liegt. Die Summe ist das Körperalter.\n\n'
          'Ein Faktor zählt erst ab $minFactorDays Tagen mit Daten, ein '
          'Alter gibt es ab $minAgeFactors Faktoren. Was fehlt, verändert '
          'nichts.\n\n'
          'Die Richtwerte folgen gängigen Empfehlungen. Wie viele Jahre '
          'ein Faktor wert ist, hat Pulse selbst festgelegt; das ist nicht '
          'wissenschaftlich geprüft. Das Körperalter ist eine Schätzung '
          'und keine medizinische Aussage.',
          style: muted,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          sections[i],
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
    final age = result.age;
    final difference = result.difference;
    final real = formatDecimal(result.chronological);
    return SurfaceCard(
      child: Row(
        children: [
          Text(
            age == null ? '–' : formatDecimal(age),
            style: context.emphasizedTextTheme.displayMedium?.copyWith(
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (difference) {
                  null => 'Noch zu wenig Daten',
                  final d when d.abs() < 0.05 => 'Genau dein Alter ($real)',
                  final d when d < 0 =>
                    '${formatDecimal(-d)} Jahre jünger als dein Alter ($real)',
                  final d =>
                    '${formatDecimal(d)} Jahre älter als dein Alter ($real)',
                }, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  age == null
                      ? 'Für eine Schätzung braucht es mindestens '
                            '$minAgeFactors Faktoren mit Daten.'
                      : 'Schätzung aus den letzten 30 Tagen',
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
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final years = factor.years;
    final position = factor.position;
    final value = factor.value;
    return SectionCard(
      title: _title,
      trailing: years == null ? null : formatYears(years),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value == null)
            Text(_missing, style: muted)
          else ...[
            Text(_reading(value), style: theme.textTheme.titleMedium),
            if (position != null) ...[
              const SizedBox(height: 12),
              M3ELinearWavyProgressIndicator(
                value: position,
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: 0.2),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              years == null
                  ? 'Zählt noch nicht: ${factor.days} von $minFactorDays '
                        'Tagen mit Daten.'
                  : _guide,
              style: muted,
            ),
          ],
        ],
      ),
    );
  }

  String get _title => switch (factor.kind) {
    AgeFactorKind.steps => 'Schritte',
    AgeFactorKind.intensity => 'Intensitätsminuten',
    AgeFactorKind.sleepDuration => 'Schlafdauer',
    AgeFactorKind.sleepRegularity => 'Schlafrhythmus',
    AgeFactorKind.restingHeartRate => 'Ruhepuls',
    AgeFactorKind.heartRateVariability => 'Herzfrequenzvariabilität',
    AgeFactorKind.bodyFat => 'Körperfett',
    AgeFactorKind.bodyMassIndex => 'Body-Mass-Index',
    AgeFactorKind.bloodPressure => 'Blutdruck',
    AgeFactorKind.strength => 'Krafttraining',
  };

  String get _missing => switch (factor.kind) {
    AgeFactorKind.bodyFat ||
    AgeFactorKind.bodyMassIndex => 'Gewicht oder Größe fehlen.',
    AgeFactorKind.bloodPressure => 'Keine Messung.',
    AgeFactorKind.strength => 'Keine Trainings in den letzten 30 Tagen.',
    _ => 'Keine Daten in den letzten 30 Tagen.',
  };

  String _reading(double value) {
    final days = 'aus ${factor.days} Tagen';
    return switch (factor.kind) {
      AgeFactorKind.steps => 'Ø ${formatInt(value.round())} am Tag, $days',
      AgeFactorKind.intensity => 'Ø ${value.round()} min pro Woche, $days',
      AgeFactorKind.sleepDuration =>
        'Ø ${formatDuration((value * 60).round())}, aus ${factor.days} Nächten',
      AgeFactorKind.sleepRegularity =>
        'Einschlafzeit schwankt um ${value.round()} min',
      AgeFactorKind.restingHeartRate => 'Ø ${value.round()} bpm, $days',
      AgeFactorKind.heartRateVariability => 'Ø ${value.round()} ms, $days',
      AgeFactorKind.bodyFat => '${formatDecimal(value)} %',
      AgeFactorKind.bodyMassIndex => formatDecimal(value),
      AgeFactorKind.bloodPressure =>
        '${value.round()}/${factor.second!.round()} mmHg',
      AgeFactorKind.strength => '${formatDecimal(value)} Einheiten pro Woche',
    };
  }

  String get _guide {
    String ends(AgeCurve curve, {String unit = ''}) {
      final lowIsBest = curve.first.$2 < curve.last.$2;
      final best = (lowIsBest ? curve.first : curve.last).$1;
      return 'Neutral bei ${_number(neutralOf(curve))}$unit, am besten '
          '${lowIsBest ? 'bis' : 'ab'} ${_number(best)}$unit.';
    }

    return switch (factor.kind) {
      AgeFactorKind.steps => ends(stepsCurve),
      AgeFactorKind.intensity => ends(intensityCurve, unit: ' min'),
      AgeFactorKind.sleepDuration =>
        'Am besten 7,5 bis 8,5 Stunden, neutral bei 7 und bei 9.',
      AgeFactorKind.sleepRegularity => ends(sleepRegularityCurve, unit: ' min'),
      AgeFactorKind.restingHeartRate => ends(
        restingHeartRateCurve(sex),
        unit: ' bpm',
      ),
      AgeFactorKind.heartRateVariability =>
        'Für dein Alter üblich: ${factor.second!.round()} ms. Am besten ab '
            '${(factor.second! * heartRateVariabilityCurve.last.$1).round()} '
            'ms.',
      AgeFactorKind.bodyFat => ends(bodyFatCurve(sex ?? Sex.male), unit: ' %'),
      AgeFactorKind.bodyMassIndex => 'Am besten um 22, neutral bei 25.',
      AgeFactorKind.bloodPressure =>
        'Neutral bei 130/85, am besten unter 120/80.',
      AgeFactorKind.strength => 'Am besten ab 2 Einheiten pro Woche.',
    };
  }

  static String _number(double value) => value == value.roundToDouble()
      ? formatInt(value.round())
      : formatDecimal(value);
}

/// A name and its value on one line.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
