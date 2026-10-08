import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_type.dart';

/// A number standing free on the page with its label below.
class FreeFigure extends StatelessWidget {
  const FreeFigure({super.key, required this.label, required this.value});

  final String label;

  /// The number, usually one that counts up.
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = AppType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle.merge(
            style: type.figure(context.emphasizedTextTheme.titleLarge),
            maxLines: 1,
            child: value,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.label(
            theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
