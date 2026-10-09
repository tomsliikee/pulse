import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/haptics.dart';
import '../../data/weather.dart';
import '../../theme/app_shapes.dart';
import '../../l10n/generated/app_localizations.dart';

/// Picks the place the weather is asked for: a search, and its answers to
/// tap. The search is the first thing in the app that uses the network, so
/// it only runs when the user asks for it.
Future<void> showPlaceSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _PlaceSheet(),
);

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet();

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Place>? _found;
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 2 || _searching) return;
    final scope = AppScope.of(context);
    final language = Localizations.localeOf(context).languageCode;
    setState(() => _searching = true);
    final found = await scope.weather.source.search(query, language);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _found = found;
    });
  }

  void _pick(Place? place) {
    AppScope.of(context).settings.setPlace(place);
    Haptics.confirm();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = AppScope.of(context).settings.place;
    final found = _found;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.placeLabel,
            style: context.emphasizedTextTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: l10n.placeSearch,
              filled: true,
              suffixIcon: IconButton(
                onPressed: _search,
                tooltip: l10n.placeSearch,
                icon: const Icon(Icons.search_rounded),
              ),
              border: UnderlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (found != null && found.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.placeNoResults),
            )
          else if (found != null)
            // A few answers; a small phone with the keyboard up scrolls.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final place in found)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(place.name),
                      subtitle: switch (place.region) {
                        final region? => Text(region),
                        null => null,
                      },
                      onTap: () => _pick(place),
                    ),
                ],
              ),
            ),
          Text(
            l10n.placeNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (current != null) ...[
            const SizedBox(height: 16),
            M3EFilledButton.tonal(
              size: M3EButtonSize.md,
              onPressed: () => _pick(null),
              child: Text(l10n.placeRemove),
            ),
          ],
        ],
      ),
    );
  }
}
