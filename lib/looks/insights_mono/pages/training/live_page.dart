import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/haptics.dart';
import '../../../../data/training/exercise_library.dart';
import '../../../../data/training/training_controller.dart';
import '../../../../data/training/training_insights.dart';
import '../../../../data/training/training_models.dart';
import '../../data/mono_data.dart';
import '../../shell/mono_dock_controller.dart';
import '../../theme/mono_tokens.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_blocks.dart';
import '../../widgets/mono_card.dart';
import '../../widgets/mono_charts.dart';
import '../../widgets/mono_floating_bar.dart';
import '../../widgets/mono_motion.dart';
import '../../widgets/mono_page.dart';
import '../../widgets/mono_sheet.dart';
import 'exercise_page.dart';
import 'exercise_picker.dart';
import 'session_page.dart';
import 'training_text.dart';

/// The live screen of a training as a page without the dock: it has its
/// own controls at the bottom. Leaving it keeps the training running, and
/// the dock shows a pill that leads back.
class MonoLiveRoute extends MaterialPageRoute<void> with MonoNoDock {
  MonoLiveRoute() : super(builder: (_) => const MonoLivePage());
}

class MonoLivePage extends StatefulWidget {
  const MonoLivePage({super.key});

  @override
  State<MonoLivePage> createState() => _MonoLivePageState();
}

class _MonoLivePageState extends State<MonoLivePage> {
  /// The exercise opened by a tap, or none: then the current one is open.
  int? _chosen;

  /// Whether the chosen one still had sets to do when it was opened; once
  /// they are done, the next exercise opens by itself.
  bool _chosenOpen = false;

  void _choose(int i, TrainingSession session) {
    Haptics.selection();
    setState(() {
      _chosen = i;
      _chosenOpen = _hasOpenSet(session.exercises[i]);
    });
  }

  Future<void> _finish(MonoCtx c) async {
    final training = c.scope.training;
    final session = training.active;
    if (session == null) return;
    final navigator = Navigator.of(context);
    final anyDone = session.exercises.any((e) => e.sets.any((s) => s.done));
    if (!anyDone) {
      final discard = await _confirm(
        c,
        c.l10n.trainingNothingDone,
        c.l10n.trainingDiscard,
      );
      if (discard != true) return;
      await training.discard();
      navigator.pop();
      return;
    }
    Haptics.confirm();
    final done = await training.finish(c.health.workouts);
    if (done == null) {
      navigator.pop();
      return;
    }
    await navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MonoSessionPage(sessionId: done.id, fresh: true),
      ),
    );
  }

  Future<bool?> _confirm(MonoCtx c, String text, String action) =>
      showMonoSheet<bool>(
        context,
        title: text,
        builder: (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonoPrimaryButton(
              label: action,
              danger: true,
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: 10),
            MonoPrimaryButton(
              label: c.l10n.cancel,
              tonal: true,
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      );

  Future<void> _addExercise(MonoCtx c) async {
    final id = await pickExercise(context);
    if (id != null) await c.scope.training.addExerciseToSession(id);
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: scope.training,
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final t = c.t;
        final l10n = c.l10n;
        final training = c.scope.training;
        final session = training.active;
        final top = MediaQuery.paddingOf(context).top;
        if (session == null) {
          return Scaffold(
            backgroundColor: t.bg,
            body: Center(
              child: Text(l10n.trainingNone, style: MonoType.sub(t)),
            ),
          );
        }
        final language = l10n.localeName;
        final current = currentExerciseOf(session);
        if (_chosen case final chosen?) {
          if (chosen >= session.exercises.length ||
              _chosenOpen && !_hasOpenSet(session.exercises[chosen])) {
            _chosen = null;
          }
        }
        final open = _chosen ?? current;
        return Scaffold(
          backgroundColor: t.bg,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  top + MonoFloatingBack.room,
                  16,
                  160 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Text(l10n.trainingLive, style: MonoType.category(t.recovery)),
                  const SizedBox(height: 8),
                  MonoSerif(
                    session.name.isEmpty ? l10n.trainingSession : session.name,
                    spec: const (32, 38, -0.02, 1.1),
                  ),
                  const SizedBox(height: 18),
                  // Only the dashboard ticks each second, not the page.
                  _Tick(
                    builder: (context) => _Dashboard(
                      c: c,
                      session: session,
                      training: training,
                      current: current,
                      language: language,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (final (i, e) in session.exercises.indexed) ...[
                    if (i == open)
                      MonoExerciseEditor(
                        key: ValueKey('${session.id}/$i/${e.exerciseId}'),
                        c: c,
                        index: i,
                        entry: e,
                        count: session.exercises.length,
                        exercise: exerciseById(
                          e.exerciseId,
                          training.data.customExercises,
                        ),
                        language: language,
                      )
                    else
                      _FoldedExercise(
                        key: ValueKey('${session.id}/$i/${e.exerciseId}/f'),
                        c: c,
                        entry: e,
                        current: i == current,
                        name:
                            exerciseById(
                              e.exerciseId,
                              training.data.customExercises,
                            )?.name(language) ??
                            e.exerciseId,
                        onTap: () => _choose(i, session),
                      ),
                    SizedBox(height: i == open ? 16 : 10),
                  ],
                  MonoPrimaryButton(
                    label: l10n.trainingAddExercise,
                    icon: Icons.add_rounded,
                    tonal: true,
                    onTap: () => _addExercise(c),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: TextButtonLike(
                      label: l10n.trainingDiscard,
                      color: t.heart,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final yes = await _confirm(
                          c,
                          l10n.trainingDiscardAsk,
                          l10n.trainingDiscard,
                        );
                        if (yes != true) return;
                        await training.discard();
                        navigator.pop();
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                top: top + 14,
                child: Row(
                  children: [
                    Flexible(
                      child: MonoBackPill(
                        label: l10n.navTraining,
                        backLabel: l10n.trainingMinimize,
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: l10n.trainingFinish,
                      child: ExcludeSemantics(
                        child: MonoPress(
                          onTap: () => _finish(c),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.solid,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              l10n.trainingFinish,
                              style: MonoType.inter(
                                15,
                                20,
                                FontWeight.w600,
                                t.onSolid,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 20 + MediaQuery.paddingOf(context).bottom,
                child: _Tick(
                  builder: (context) => _RestBar(
                    c: c,
                    left: training.restLeft,
                    training: training,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _hasOpenSet(SessionExercise e) =>
    e.sets.any((s) => !s.done && s.kind.counts);

/// The exercise to do now: the first with a set still open, or none once
/// everything is done.
int? currentExerciseOf(TrainingSession session) {
  for (final (i, e) in session.exercises.indexed) {
    if (_hasOpenSet(e)) return i;
  }
  return null;
}

/// The last finished session of the same template, to measure against.
TrainingSession? lastOfTemplate(
  TrainingSession session,
  Iterable<TrainingSession> sessions,
) {
  final id = session.templateId;
  if (id == null) return null;
  TrainingSession? last;
  for (final s in sessions) {
    if (s.id == session.id || !s.finished || s.templateId != id) continue;
    if (last == null || s.start.isAfter(last.start)) last = s;
  }
  return last;
}

/// How many exercises of [session] beat their best so far, by estimated
/// maximum or heaviest weight.
int liveRecordsOf(TrainingSession session, List<TrainingSession> sessions) {
  final before = [
    for (final s in sessions)
      if (s.id != session.id && s.finished) s,
  ];
  var n = 0;
  for (final id in {for (final e in session.exercises) e.exerciseId}) {
    final now = bestOf(id, [session]);
    final best = bestOf(id, before);
    final orm =
        now.oneRepMax != null &&
        best.oneRepMax != null &&
        now.oneRepMax! > best.oneRepMax! + 0.01;
    final heavy =
        now.heaviest != null &&
        best.heaviest != null &&
        now.heaviest! > best.heaviest! + 0.01;
    if (orm || heavy) n++;
  }
  return n;
}

/// The top of the live screen: the time, the sets done of all, the volume,
/// what comes now, and how it stands against last time.
class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.c,
    required this.session,
    required this.training,
    required this.current,
    required this.language,
  });

  final MonoCtx c;
  final TrainingSession session;
  final TrainingController training;
  final int? current;
  final String language;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final l10n = c.l10n;
    final f = c.formats;
    final all = [
      for (final e in session.exercises)
        for (final s in e.sets)
          if (s.kind.counts) s,
    ];
    final done = all.where((s) => s.done).length;
    final volume = session.volume;
    final elapsed = training.now.difference(session.start);
    final rest = training.restLeft;
    final sessions = training.data.sessions;
    final last = lastOfTemplate(session, sessions);
    final records = liveRecordsOf(session, sessions);
    final tabular = const [FontFeature.tabularFigures()];

    String? next;
    String? nowName;
    if (current case final i?) {
      final e = session.exercises[i];
      nowName =
          exerciseById(
            e.exerciseId,
            training.data.customExercises,
          )?.name(language) ??
          e.exerciseId;
      final set = e.sets.firstWhere((s) => !s.done && s.kind.counts);
      if (set.kg != null || set.reps != null) next = setText(f, set);
    }

    return MonoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MonoStat(
                  label: l10n.trainingDuration,
                  value: clockText(elapsed),
                ),
              ),
              if (rest != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.trainingRest, style: MonoType.label(t)),
                    const SizedBox(height: 2),
                    Text(
                      clockText(rest),
                      style: MonoType.inter(
                        22,
                        28,
                        FontWeight.w600,
                        t.recovery,
                      ).copyWith(fontFeatures: tabular),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          MonoTrack(
            value: all.isEmpty ? 0 : done / all.length,
            color: t.recovery,
            semantics: l10n.trainingSetsOf(done, all.length),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MonoStat(
                  small: true,
                  label: l10n.trainingSetsLabel,
                  value: l10n.trainingSetsOf(done, all.length),
                ),
              ),
              Expanded(
                child: MonoStat(
                  small: true,
                  label: l10n.trainingVolume,
                  value: f.integer(volume.round()),
                  unit: 'kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(l10n.trainingNow, style: MonoType.label(t)),
          const SizedBox(height: 4),
          Text(
            nowName ?? l10n.trainingAllSetsDone,
            style: MonoType.inter(17, 22, FontWeight.w600, t.ink),
          ),
          if (next != null)
            Text(l10n.trainingNextSet(next), style: MonoType.sub(t)),
          if (last != null && last.volume > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.trainingLastSession(
                      f.integer(last.volume.round()),
                      f.duration(last.duration.inMinutes),
                    ),
                    style: MonoType.label(t),
                  ),
                ),
                const SizedBox(width: 10),
                volume > last.volume
                    ? MonoDelta(
                        l10n.trainingAboveLast(
                          f.integer((volume - last.volume).round()),
                        ),
                        good: true,
                      )
                    : MonoDelta(
                        l10n.trainingShareOfLast(
                          (volume / last.volume * 100).round(),
                        ),
                      ),
              ],
            ),
          ],
          if (records > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 18, color: t.recovery),
                const SizedBox(width: 6),
                Text(
                  l10n.trainingRecordsCount(records),
                  style: MonoType.inter(14, 18, FontWeight.w600, t.recovery),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// An exercise not open right now: its name and its sets done of all; a
/// tap opens it.
class _FoldedExercise extends StatelessWidget {
  const _FoldedExercise({
    super.key,
    required this.c,
    required this.entry,
    required this.name,
    required this.current,
    required this.onTap,
  });

  final MonoCtx c;
  final SessionExercise entry;
  final String name;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final l10n = c.l10n;
    final counting = entry.sets.where((s) => s.kind.counts);
    final total = counting.length;
    final done = counting.where((s) => s.done).length;
    final finished = total > 0 && done == total;
    return Semantics(
      button: true,
      label: l10n.trainingOpenExercise(name),
      child: ExcludeSemantics(
        child: MonoSurface(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MonoType.inter(
                    16,
                    22,
                    FontWeight.w600,
                    finished ? t.ink2 : t.ink,
                  ),
                ),
              ),
              Text(
                l10n.trainingSetsOf(done, total),
                style: MonoType.label(
                  t,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 10),
              Icon(
                finished
                    ? Icons.check_circle_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: finished ? t.recovery : t.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds [builder] again every second while it is shown.
class _Tick extends StatefulWidget {
  const _Tick({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// A text action without a frame.
class TextButtonLike extends StatelessWidget {
  const TextButtonLike({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      button: true,
      child: MonoPress(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            label,
            style: MonoType.inter(15, 20, FontWeight.w600, color ?? t.ink),
          ),
        ),
      ),
    );
  }
}

/// The rest, floating at the bottom: what is left with a bar that runs
/// down, a quarter minute less or more, and skip. Without a rest, a quiet
/// hint that a done set starts one.
class _RestBar extends StatelessWidget {
  const _RestBar({required this.c, required this.left, required this.training});

  final MonoCtx c;
  final Duration? left;
  final TrainingController training;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final l10n = c.l10n;
    final rest = left;
    final still = monoStill(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      transitionBuilder: (child, a) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: rest == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : MonoGlass(
              key: const ValueKey('rest'),
              radius: 30,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.trainingRest, style: MonoType.label(t)),
                          Text(
                            clockText(rest),
                            style:
                                MonoType.inter(
                                  28,
                                  32,
                                  FontWeight.w600,
                                  t.ink,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressBar(
                              share:
                                  rest.inMilliseconds /
                                  math.max(
                                    1,
                                    (training.restLength ?? rest)
                                        .inMilliseconds,
                                  ),
                              color: t.recovery,
                              track: t.fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RoundText(
                      label: '−15',
                      semantics: l10n.trainingRestLess,
                      onTap: () =>
                          training.addRest(const Duration(seconds: -15)),
                    ),
                    _RoundText(
                      label: '+15',
                      semantics: l10n.trainingRestMore,
                      onTap: () =>
                          training.addRest(const Duration(seconds: 15)),
                    ),
                    _RoundText(
                      label: l10n.trainingSkip,
                      semantics: l10n.trainingSkip,
                      solid: true,
                      onTap: training.stopRest,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A thin bar that is [share] full.
class LinearProgressBar extends StatelessWidget {
  const LinearProgressBar({
    super.key,
    required this.share,
    required this.color,
    required this.track,
    this.height = 5,
  });

  final double share;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: track)),
        FractionallySizedBox(
          widthFactor: share.clamp(0.0, 1.0),
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ],
    ),
  );
}

class _RoundText extends StatelessWidget {
  const _RoundText({
    required this.label,
    required this.semantics,
    required this.onTap,
    this.solid = false,
  });

  final String label;
  final String semantics;
  final VoidCallback onTap;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          squash: 0.08,
          child: Container(
            height: 48,
            constraints: const BoxConstraints(minWidth: 48),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: solid ? t.solid : t.fill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              label,
              style: MonoType.inter(
                14,
                18,
                FontWeight.w600,
                solid ? t.onSolid : t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One exercise of the running training, or with [sessionId] of a finished
/// one being corrected: its name, what it was last time, a hint when it is
/// time for more weight, and its sets.
class MonoExerciseEditor extends StatelessWidget {
  const MonoExerciseEditor({
    super.key,
    required this.c,
    required this.index,
    required this.entry,
    required this.count,
    required this.exercise,
    required this.language,
    this.sessionId,
  });

  final MonoCtx c;
  final String? sessionId;
  final int index;
  final SessionExercise entry;
  final int count;
  final Exercise? exercise;
  final String language;

  Future<void> _menu(BuildContext context) async {
    final l10n = c.l10n;
    final training = c.scope.training;
    await showMonoSheet<void>(
      context,
      title: exercise?.name(language) ?? entry.exerciseId,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sessionId == null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(l10n.trainingRestTime, style: MonoType.label(c.t)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in const [45, 60, 90, 120, 150, 180, 240])
                  _Chip(
                    label: clockText(Duration(seconds: s)),
                    chosen: entry.restSeconds == s,
                    onTap: () {
                      training.setRest(index, s);
                      Navigator.of(sheet).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (index > 0)
            MonoChoiceRow(
              icon: Icons.arrow_upward_rounded,
              label: l10n.trainingMoveUp,
              onTap: () {
                training.moveExercise(index, index - 1, session: sessionId);
                Navigator.of(sheet).pop();
              },
            ),
          if (index < count - 1)
            MonoChoiceRow(
              icon: Icons.arrow_downward_rounded,
              label: l10n.trainingMoveDown,
              onTap: () {
                training.moveExercise(index, index + 1, session: sessionId);
                Navigator.of(sheet).pop();
              },
            ),
          MonoChoiceRow(
            icon: Icons.delete_outline_rounded,
            label: l10n.trainingRemoveExercise,
            onTap: () {
              training.removeExerciseFromSession(index, session: sessionId);
              Navigator.of(sheet).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final l10n = c.l10n;
    final sessions = c.scope.training.data.sessions;
    final last = lastSetOf(entry.exerciseId, sessions);
    final more =
        sessionId == null &&
        suggestsMore(entry.exerciseId, sessions, targetReps: entry.targetReps);
    final name = exercise?.name(language) ?? entry.exerciseId;
    return MonoSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: MonoPress(
                  squash: 0.01,
                  onTap: () =>
                      c.push(MonoExercisePage(exerciseId: entry.exerciseId)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: MonoType.inter(17, 22, FontWeight.w600, t.ink),
                      ),
                      Text(
                        [
                          if (exercise?.muscle case final m?)
                            muscleLabel(l10n, m),
                          if (last != null)
                            l10n.trainingLastTime(setText(c.formats, last.$1)),
                        ].join(' · '),
                        style: MonoType.label(t),
                      ),
                    ],
                  ),
                ),
              ),
              if (more)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: t.recoveryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.trainingMore,
                    style: MonoType.inter(13, 16, FontWeight.w600, t.recovery),
                  ),
                ),
              Semantics(
                button: true,
                label: l10n.trainingExerciseMenu,
                child: ExcludeSemantics(
                  child: MonoPress(
                    onTap: () => _menu(context),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.more_horiz_rounded, color: t.ink2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(l10n.trainingSet, style: MonoType.label(t)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('kg', style: MonoType.label(t))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.trainingReps, style: MonoType.label(t)),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final (i, s) in entry.sets.indexed)
            _SetRow(
              key: ValueKey('$index/$i'),
              c: c,
              sessionId: sessionId,
              exercise: index,
              index: i,
              set: s,
              number: entry.sets
                  .take(i + 1)
                  .where((x) => x.kind != SetKind.warmup)
                  .length,
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButtonLike(
              label: l10n.trainingAddSet,
              onTap: () => c.scope.training.addSet(index, session: sessionId),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.chosen, required this.onTap});

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      button: true,
      selected: chosen,
      child: MonoPress(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chosen ? t.solid : t.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: MonoType.inter(
              15,
              20,
              FontWeight.w600,
              chosen ? t.onSolid : t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip of a choice, for sheets of the training.
class MonoChip extends StatelessWidget {
  const MonoChip({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _Chip(label: label, chosen: chosen, onTap: onTap);
}

/// One set: its number or kind, the weight and the reps to type, and the
/// round check that marks it done and starts the rest.
class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.c,
    required this.exercise,
    required this.index,
    required this.set,
    required this.number,
    this.sessionId,
  });

  final MonoCtx c;
  final String? sessionId;
  final int exercise;
  final int index;
  final TrainingSet set;
  final int number;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _kg = TextEditingController(
    text: _kgText(widget.set.kg),
  );
  late final TextEditingController _reps = TextEditingController(
    text: widget.set.reps?.toString() ?? '',
  );
  final FocusNode _kgFocus = FocusNode();
  final FocusNode _repsFocus = FocusNode();

  String _kgText(double? kg) {
    if (kg == null) return '';
    final s = kgText(widget.c.formats, kg);
    return s;
  }

  @override
  void didUpdateWidget(_SetRow old) {
    super.didUpdateWidget(old);
    if (!_kgFocus.hasFocus && old.set.kg != widget.set.kg) {
      _kg.text = _kgText(widget.set.kg);
    }
    if (!_repsFocus.hasFocus && old.set.reps != widget.set.reps) {
      _reps.text = widget.set.reps?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    _kgFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  double? _parseKg(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _save() {
    final s = widget.set;
    widget.c.scope.training.updateSet(
      widget.exercise,
      widget.index,
      s.copyWith(
        kg: () => _parseKg(_kg.text),
        reps: () => int.tryParse(_reps.text.trim()),
      ),
      typing: true,
      session: widget.sessionId,
    );
  }

  Future<void> _kind() async {
    final c = widget.c;
    final l10n = c.l10n;
    final training = c.scope.training;
    var s = widget.set;
    await showMonoSheet<void>(
      context,
      title: l10n.trainingSetNumber(widget.number),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          void put(TrainingSet next) {
            s = next;
            training.updateSet(
              widget.exercise,
              widget.index,
              next,
              session: widget.sessionId,
            );
            setSheet(() {});
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final kind in SetKind.values)
                MonoChoiceRow(
                  label: setKindLabel(l10n, kind),
                  chosen: s.kind == kind,
                  onTap: () => put(s.copyWith(kind: kind)),
                ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('RPE', style: MonoType.label(c.t)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in const [
                    6.0,
                    7.0,
                    7.5,
                    8.0,
                    8.5,
                    9.0,
                    9.5,
                    10.0,
                  ])
                    _Chip(
                      label: kgText(c.formats, v),
                      chosen: s.rpe == v,
                      onTap: () =>
                          put(s.copyWith(rpe: () => s.rpe == v ? null : v)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('RIR', style: MonoType.label(c.t)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in const [0, 1, 2, 3, 4])
                    _Chip(
                      label: '$v',
                      chosen: s.rir == v,
                      onTap: () =>
                          put(s.copyWith(rir: () => s.rir == v ? null : v)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              MonoPrimaryButton(
                label: l10n.trainingRemoveSet,
                danger: true,
                onTap: () {
                  training.removeSet(
                    widget.exercise,
                    widget.index,
                    session: widget.sessionId,
                  );
                  Navigator.of(sheet).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = c.t;
    final s = widget.set;
    final mark = setKindMark(c.l10n, s.kind);
    final still = monoStill(context);
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 6, right: 8),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: s.done ? t.recoveryBg : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: c.l10n.trainingSetNumber(widget.number),
            child: ExcludeSemantics(
              child: MonoPress(
                onTap: _kind,
                child: Container(
                  width: 40,
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(
                    mark.isEmpty ? '${widget.number}' : mark,
                    style: MonoType.inter(
                      16,
                      20,
                      FontWeight.w600,
                      s.kind == SetKind.working ? t.ink : t.recovery,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MonoField(
              controller: _kg,
              focusNode: _kgFocus,
              dense: true,
              hint: '–',
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MonoField(
              controller: _reps,
              focusNode: _repsFocus,
              dense: true,
              hint: '–',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            toggled: s.done,
            label: c.l10n.trainingSetDone,
            child: ExcludeSemantics(
              child: MonoPress(
                squash: 0.12,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  if (s.done) {
                    Haptics.tap();
                  } else {
                    Haptics.confirm();
                  }
                  c.scope.training.toggleSet(
                    widget.exercise,
                    widget.index,
                    session: widget.sessionId,
                  );
                },
                child: AnimatedContainer(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  width: 48,
                  height: 44,
                  decoration: BoxDecoration(
                    color: s.done ? t.recovery : t.fill,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 22,
                    color: s.done ? t.bg : t.ink3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
