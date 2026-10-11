import '../../app/formatters.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/links.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../detail/metric_spec.dart';
import '../goals/goal_format.dart';

final Expando<({Object state, List<Link> links})> _links = Expando();

/// The connections in the user's last three months, the strongest first.
/// Finding them reads every day of the stretch several times and several
/// tiles ask in one build, so the answer is kept until the data, the goals
/// or the day change.
List<Link> linksOf(HealthController health, SettingsController settings) {
  final targets = [for (final goal in Goal.values) settings.goalTarget(goal)];
  final state = (health.revision, health.today, Object.hashAll(targets));
  var kept = _links[health];
  if (kept == null || kept.state != state) {
    final today = health.today;
    kept = _links[health] = (
      state: state,
      links: findLinks(
        data: goalDataOf(health, settings),
        targetOf: settings.goalTarget,
        // Today is not over.
        until: DateTime(today.year, today.month, today.day - 1),
      ),
    );
  }
  return kept.links;
}

const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

String _cause(AppLocalizations l10n, Link link) {
  final goal = link.split == LinkSplit.goal;
  return switch (link.cause) {
    LinkCause.workout => l10n.linkCauseWorkout,
    LinkCause.steps =>
      goal ? l10n.linkCauseStepsGoal : l10n.linkCauseStepsUsual,
    LinkCause.activeEnergy =>
      goal ? l10n.linkCauseEnergyGoal : l10n.linkCauseEnergyUsual,
    LinkCause.intensity =>
      goal ? l10n.linkCauseIntensityGoal : l10n.linkCauseIntensityUsual,
    LinkCause.water =>
      goal ? l10n.linkCauseWaterGoal : l10n.linkCauseWaterUsual,
    LinkCause.intake => l10n.linkCauseIntake,
    LinkCause.asleep =>
      goal ? l10n.linkCauseAsleepGoal : l10n.linkCauseAsleepUsual,
    LinkCause.earlyBed => l10n.linkCauseEarlyBed,
    LinkCause.sleepScore => l10n.linkCauseSleepScore,
    // A night belongs to the day it ended on, which reads oddly for a
    // bedtime: the night is named by the day it leads into.
    LinkCause.weekday =>
      link.effect == LinkEffect.steps
          ? l10n.linkCauseWeekday(_weekdays[link.weekday! - 1])
          : l10n.linkCauseNightTo(_weekdays[link.weekday! - 1]),
    LinkCause.weekSteps => l10n.linkCauseWeekSteps,
    LinkCause.weekWorkouts => l10n.linkCauseWeekWorkouts,
  };
}

/// The size of a difference in [effect], without its sign.
String _difference(Formats formats, LinkEffect effect, double difference) {
  final size = difference.abs();
  return switch (effect) {
    LinkEffect.asleep ||
    LinkEffect.deep ||
    LinkEffect.bedtime => formats.duration(size.round()),
    LinkEffect.sleepScore ||
    LinkEffect.recovery ||
    LinkEffect.steps => formats.integer(size.round()),
    LinkEffect.restingPulse => Metric.restingHeartRate.formatWithUnit(
      formats,
      size,
    ),
    LinkEffect.variability => Metric.heartRateVariability.formatWithUnit(
      formats,
      size,
    ),
    LinkEffect.weight => Metric.weight.formatWithUnit(formats, size),
  };
}

/// The sentence of a connection: "Nach Tagen mit Training schläfst du im
/// Schnitt 22 min länger."
String linkSentence(Formats formats, Link link) {
  final l10n = formats.l10n;
  final diff = _difference(formats, link.effect, link.difference);
  final direction = link.difference > 0 ? 'more' : 'less';
  final effect = switch (link.effect) {
    LinkEffect.asleep => l10n.linkEffectAsleep(diff, direction),
    LinkEffect.sleepScore => l10n.linkEffectSleepScore(diff, direction),
    LinkEffect.deep => l10n.linkEffectDeep(diff, direction),
    LinkEffect.bedtime => l10n.linkEffectBedtime(diff, direction),
    LinkEffect.recovery => l10n.linkEffectRecovery(diff, direction),
    LinkEffect.restingPulse => l10n.linkEffectRestingPulse(diff, direction),
    LinkEffect.variability => l10n.linkEffectVariability(diff, direction),
    LinkEffect.steps => l10n.linkEffectSteps(diff, direction),
    LinkEffect.weight => l10n.linkEffectWeight(diff, direction),
  };
  return l10n.linkSentence(_cause(l10n, link), effect);
}

/// A mean of [effect] as it stands beside its bar.
String linkValue(Formats formats, LinkEffect effect, double value) =>
    switch (effect) {
      LinkEffect.asleep || LinkEffect.deep => formats.duration(value.round()),
      LinkEffect.bedtime => formatClock(value.round()),
      LinkEffect.sleepScore ||
      LinkEffect.recovery ||
      LinkEffect.steps => formats.integer(value.round()),
      LinkEffect.restingPulse => Metric.restingHeartRate.formatWithUnit(
        formats,
        value,
      ),
      LinkEffect.variability => Metric.heartRateVariability.formatWithUnit(
        formats,
        value,
      ),
      LinkEffect.weight => Metric.weight.formatWithUnit(formats, value),
    };

/// Where the bars of [effect] begin: nothing for an amount, six in the
/// evening for a bedtime, which has no nothing.
double linkBarFrom(LinkEffect effect) =>
    effect == LinkEffect.bedtime ? 18 * 60 : 0;

/// What the two sides of [link] are called.
({String with_, String without}) linkSides(AppLocalizations l10n, Link link) {
  final nights =
      link.kind == LinkKind.nightToDay ||
      (link.kind == LinkKind.weekday && link.effect != LinkEffect.steps);
  if (link.kind == LinkKind.weeks) {
    return (with_: l10n.linkSuchWeeks, without: l10n.linkOtherWeeks);
  }
  return nights
      ? (with_: l10n.linkSuchNights, without: l10n.linkOtherNights)
      : (with_: l10n.linkSuchDays, without: l10n.linkOtherDays);
}

extension LinkKindText on LinkKind {
  String label(AppLocalizations l10n) => switch (this) {
    LinkKind.dayToNight => l10n.linkKindDayToNight,
    LinkKind.nightToDay => l10n.linkKindNightToDay,
    LinkKind.weekday => l10n.linkKindWeekday,
    LinkKind.weeks => l10n.linkKindWeeks,
  };
}
