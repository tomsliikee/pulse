import 'package:flutter/foundation.dart';

import 'search_synonyms.dart';

/// What a result of the search is. The order is the order of the groups.
enum SearchKind { value, exercise, workout, supplement, day, setting }

/// One thing the search can find, already worded for the screen.
@immutable
class SearchItem {
  const SearchItem({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.valueText,
    this.group = '',
    this.terms = const [],
  });

  final SearchKind kind;

  /// Names the thing for its page: a metric's name, an exercise's id, a
  /// workout's key, a supplement's key, a day as yyyy-mm-dd, a setting.
  final String id;
  final String title;
  final String? subtitle;

  /// The current value, such as "7,432" or "80 kg × 8".
  final String? valueText;

  /// The name of the group it is listed under; searched as well.
  final String group;

  /// More words it is found by, such as its names in the other languages.
  final List<String> terms;

  /// Whether it can be pinned: numbers only, not exercises or days.
  bool get pinnable => kind == SearchKind.value;

  @override
  String toString() => 'SearchItem($kind, $id)';
}

/// [text] in lower case without accents, so "Übung", "ubung" and "UEBUNG"
/// meet. Umlauts become their bare vowel, ß becomes ss.
String normalizeSearch(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    out.write(_plain[c] ?? c);
  }
  return out
      .toString()
      .replaceAll('ae', 'a')
      .replaceAll('oe', 'o')
      .replaceAll('ue', 'u')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _plain = {
  'ä': 'a',
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ą': 'a',
  'ö': 'o',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ü': 'u',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ß': 'ss',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ę': 'e',
  'í': 'i',
  'ç': 'c',
  'ć': 'c',
  'ł': 'l',
  'ń': 'n',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
  '₂': '2',
};

/// What [items] has for [text]: every item whose title, group, subtitle or
/// one of its terms holds the text, or a word the text is a synonym of.
/// Grouped by kind in the order of [SearchKind]; within a kind, titles that
/// start with the text come first, then the order of [items].
List<SearchItem> querySearch(List<SearchItem> items, String text) {
  final q = normalizeSearch(text);
  if (q.isEmpty) return const [];
  final also = synonymsOf(q);
  final hits = <(SearchItem, int, int)>[];
  for (final (index, item) in items.indexed) {
    final title = normalizeSearch(item.title);
    final hay = [
      title,
      normalizeSearch(item.group),
      if (item.subtitle != null) normalizeSearch(item.subtitle!),
      for (final t in item.terms) normalizeSearch(t),
    ].join(' | ');
    final direct = hay.contains(q);
    final viaSynonym = !direct && also.any(hay.contains);
    if (!direct && !viaSynonym) continue;
    final rank = title.startsWith(q) ? 0 : (direct ? 1 : 2);
    hits.add((item, rank, index));
  }
  hits.sort((a, b) {
    final kind = a.$1.kind.index.compareTo(b.$1.kind.index);
    if (kind != 0) return kind;
    final rank = a.$2.compareTo(b.$2);
    return rank != 0 ? rank : a.$3.compareTo(b.$3);
  });
  return [for (final h in hits) h.$1];
}

/// The pinned items of [items] in the order of [pins]; pins the index does
/// not know are left out.
List<SearchItem> pinnedOf(List<SearchItem> items, List<String> pins) {
  final byId = {
    for (final item in items)
      if (item.pinnable) item.id: item,
  };
  return [for (final id in pins) ?byId[id]];
}
