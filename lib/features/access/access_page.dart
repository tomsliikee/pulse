import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../data/health_controller.dart';
import '../../widgets/morphing_shape.dart';

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
        'Deine Gesundheitsdaten',
        'Pulse liest Schritte, Puls, Schlaf und weitere Werte aus Health '
            'Connect und schreibt Wasser, Gewicht und Mahlzeiten, die du hier '
            'einträgst. Die Daten bleiben auf diesem Gerät.',
        'Zugriff erlauben',
        health.requestAccess,
        Shapes.c9SidedCookie,
        Icons.favorite_rounded,
      ),
      HealthStatus.unavailable => (
        'Health Connect fehlt',
        'Pulse liest seine Daten aus Health Connect. Die App ist auf diesem '
            'Gerät nicht installiert oder braucht ein Update.',
        'Health Connect öffnen',
        health.installStore,
        Shapes.softBurst,
        Icons.download_rounded,
      ),
      HealthStatus.failed => (
        'Daten nicht lesbar',
        'Health Connect hat nicht geantwortet. Versuche es noch einmal.',
        'Erneut versuchen',
        health.refresh,
        Shapes.puffy,
        Icons.refresh_rounded,
      ),
      _ => (
        'Nur auf Android',
        'Pulse zeigt Daten aus Health Connect. Das gibt es auf diesem System '
            'nicht.',
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
