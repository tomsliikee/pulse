import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/looks/insights_mono/search/search_index.dart';
import 'package:pulse/looks/insights_mono/search/search_synonyms.dart';

import 'support/fixtures.dart';

const _items = [
  SearchItem(
    kind: SearchKind.setting,
    id: 'zones',
    title: 'Heart rate zones',
    group: 'Settings',
  ),
  SearchItem(
    kind: SearchKind.value,
    id: 'heartRate',
    title: 'Heart rate',
    group: 'Heart',
    valueText: '71',
  ),
  SearchItem(
    kind: SearchKind.value,
    id: 'restingHeartRate',
    title: 'Resting heart rate',
    group: 'Heart',
  ),
  SearchItem(
    kind: SearchKind.exercise,
    id: 'benchPress',
    title: 'Bankdrücken (Langhantel)',
    group: 'Brust',
    terms: ['Barbell bench press'],
  ),
  SearchItem(
    kind: SearchKind.value,
    id: 'steps',
    title: 'Schritte',
    group: 'Aktivität',
  ),
  SearchItem(
    kind: SearchKind.day,
    id: '2026-11-10',
    title: 'Di., 10. Nov.',
    subtitle: 'Ruhepuls 54',
  ),
  SearchItem(
    kind: SearchKind.workout,
    id: 'w',
    title: 'Krafttraining',
    subtitle: 'Heute',
  ),
];

void main() {
  test('normalising folds case, umlauts and their spelled forms', () {
    expect(normalizeSearch('Übung'), normalizeSearch('UEBUNG'));
    expect(normalizeSearch('Größe'), 'grosse');
    expect(normalizeSearch('  Tętno  spoczynkowe '), 'tetno spoczynkowe');
  });

  test('matches substrings and groups by kind', () {
    // The day is found through "Ruhepuls", a synonym of heart rate.
    final hits = querySearch(_items, 'heart');
    expect(hits.map((h) => h.id), [
      'heartRate',
      'restingHeartRate',
      '2026-11-10',
      'zones',
    ]);
  });

  test('a title that starts with the text comes first in its group', () {
    final hits = querySearch(_items, 'rate');
    expect(hits.first.kind, SearchKind.value);
  });

  test('finds by the other language and by synonyms', () {
    expect(
      querySearch(_items, 'bench').map((h) => h.id),
      contains('benchPress'),
    );
    expect(querySearch(_items, 'bankdrucken').map((h) => h.id), ['benchPress']);
    expect(querySearch(_items, 'steps').map((h) => h.id), contains('steps'));
    expect(
      querySearch(_items, 'puls').map((h) => h.id),
      containsAll(['heartRate', '2026-11-10']),
    );
    expect(querySearch(_items, 'workout').map((h) => h.id), contains('w'));
  });

  test('nothing for an empty or unknown text', () {
    expect(querySearch(_items, '   '), isEmpty);
    expect(querySearch(_items, 'xylophon'), isEmpty);
  });

  test('short texts do not expand to synonyms', () {
    expect(synonymsOf('pu'), isEmpty);
    expect(synonymsOf('schl'), contains('sleep'));
  });

  test('pins keep their order and skip what is not pinnable', () {
    final pins = pinnedOf(_items, ['steps', 'benchPress', 'nope', 'heartRate']);
    expect(pins.map((p) => p.id), ['steps', 'heartRate']);
  });

  group('settings', () {
    test('pins default, toggle, cap at eight and persist', () async {
      final store = MemoryJsonStore();
      final s = SettingsController(store);
      await s.load();
      expect(s.searchPins, defaultSearchPins);
      s.toggleSearchPin('steps');
      expect(s.searchPins, isNot(contains('steps')));
      s.setSearchPins(['a', 'b', 'a', 'c', 'd', 'e', 'f', 'g', 'h', 'i']);
      expect(s.searchPins, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
      s.toggleSearchPin('z');
      expect(s.searchPins, hasLength(8));
      s.setDockShrink(false);
      await Future<void>.delayed(Duration.zero);
      final again = SettingsController(store);
      await again.load();
      expect(again.searchPins.first, 'a');
      expect(again.dockShrink, isFalse);
    });
  });
}
