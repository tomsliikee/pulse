import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../../../data/health_controller.dart';
import '../../../data/models.dart';
import '../../../data/supplements.dart';
import '../../../features/entry/entry_sheet.dart';
import '../../../features/supplements/supplement_sheet.dart';
import '../../../app/formatters.dart';
import '../../../app/app_scope.dart';

/// Millilitres in a glass.
const double monoGlassMl = 250;

/// Enters one glass of water; what it wrote can be taken back from the
/// message that follows.
Future<void> monoAddGlass(BuildContext context, HealthController health) async {
  final messenger = ScaffoldMessenger.of(context);
  final formats = Formats.of(context);
  final l10n = formats.l10n;
  final draft = EntryDraft(
    kind: EntryKind.water,
    time: health.now,
    amount: monoGlassMl,
  );
  Haptics.tap();
  try {
    await health.addEntry(draft);
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(l10n.entrySaveFailed)));
    return;
  }
  Haptics.confirm();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          l10n.glassAdded('${formats.integer(monoGlassMl.round())} ml'),
        ),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            HealthEntry? written;
            for (final entry in health.snapshot.entries) {
              if (entry.isOwn &&
                  entry.draft.kind == EntryKind.water &&
                  entry.draft.time == draft.time) {
                written = entry;
              }
            }
            if (written == null) return;
            try {
              await health.deleteEntry(written);
            } on Exception {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.deleteFailed)),
              );
            }
          },
        ),
      ),
    );
}

/// Notes [supplement] as taken, or takes the note of today back.
Future<void> monoToggleSupplement(
  BuildContext context,
  Supplement supplement,
) async {
  final scope = AppScope.of(context);
  final controller = scope.supplements;
  final today = scope.health.now;
  final taken = controller.data.takenOn(supplement.key, today);
  Haptics.tap();
  if (taken != null) {
    await controller.untake(taken);
  } else {
    await controller.take(supplement, at: today);
    Haptics.confirm();
  }
}

Future<void> monoAddEntry(BuildContext context, EntryKind kind) =>
    showEntrySheet(context, kind);

Future<void> monoAddSupplement(BuildContext context) =>
    showSupplementSheet(context);
