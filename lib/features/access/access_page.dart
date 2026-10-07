import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../data/health_controller.dart';
import '../../widgets/morphing_shape.dart';
import '../../l10n/generated/app_localizations.dart';

/// Shown instead of the pages while there is no data to show: loading, no
/// permission yet, Health Connect missing, or a platform without it.
class AccessPage extends StatelessWidget {
  const AccessPage({super.key, required this.status});

  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final health = AppScope.of(context).health;
    final l10n = AppLocalizations.of(context);

    if (status == HealthStatus.loading) {
      return const Center(child: M3ELoadingIndicator());
    }

    final (
      String title,
      String body,
      String? action,
      VoidCallback? onAction,
      Shapes shape,
      IconData icon,
    ) = switch (status) {
      HealthStatus.needsAccess => (
        l10n.accessTitle,
        l10n.accessBody,
        l10n.accessAction,
        health.requestAccess,
        Shapes.c9SidedCookie,
        Icons.favorite_rounded,
      ),
      HealthStatus.unavailable => (
        l10n.missingTitle,
        l10n.missingBody,
        l10n.missingAction,
        health.installStore,
        Shapes.softBurst,
        Icons.download_rounded,
      ),
      HealthStatus.failed => (
        l10n.failedTitle,
        l10n.failedBody,
        l10n.failedAction,
        health.refresh,
        Shapes.puffy,
        Icons.refresh_rounded,
      ),
      _ => (
        l10n.androidOnlyTitle,
        l10n.androidOnlyBody,
        null,
        null,
        Shapes.gem,
        Icons.phone_android_rounded,
      ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MorphingShape(
              shape: shape,
              color: scheme.primaryContainer,
              size: 152,
              child: Icon(icon, size: 64, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.emphasizedTextTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 32),
              M3EFilledButton(
                size: M3EButtonSize.md,
                onPressed: onAction,
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
