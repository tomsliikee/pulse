import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/weather.dart';
import 'package:pulse/data/weather_controller.dart';

import 'support/fixtures.dart';

final _now = DateTime(2026, 10, 6, 7, 5);

/// A day's answer as Open-Meteo documents it, cut to four hours.
Map<String, Object?> _answer() => {
  'current': {
    'time': '2026-10-06T07:00',
    'temperature_2m': 11.6,
    'weather_code': 2,
  },
  'daily': {
    'time': ['2026-10-06'],
    'temperature_2m_max': [17.8],
    'temperature_2m_min': [7.9],
    'precipitation_probability_max': [65],
  },
  'hourly': {
    'time': [
      '2026-10-06T00:00',
      '2026-10-06T01:00',
      '2026-10-06T02:00',
      '2026-10-06T03:00',
    ],
    'temperature_2m': [9.1, 8.7, 8.2, 7.9],
    'precipitation_probability': [0, 10, null, 65],
    'weather_code': [0, 3, 45, 61],
  },
};

void main() {
  test('a forecast of Open-Meteo is read into the day\'s weather', () {
    final weather = weatherFromOpenMeteo(_answer(), fixturePlace, _now)!;
    expect(weather.temperature, 11.6);
    expect(weather.sky, Sky.partlyCloudy);
    expect(weather.high, 17.8);
    expect(weather.low, 7.9);
    expect(weather.rainChance, 65);
    expect(weather.day, DateTime(2026, 10, 6));
    expect(weather.hours.map((hour) => hour.hour), [0, 1, 2, 3]);
    expect(weather.hours.map((hour) => hour.sky), [
      Sky.clear,
      Sky.cloudy,
      Sky.fog,
      Sky.rain,
    ]);
    // An hour without a chance of rain counts as none.
    expect(weather.hours.map((hour) => hour.rainChance), [0, 10, 0, 65]);
  });

  test('an answer that is not a forecast gives no weather', () {
    for (final broken in [
      null,
      'no',
      <String, Object?>{},
      {'error': true, 'reason': 'Latitude must be in range of -90 to 90°.'},
      _answer()..remove('daily'),
      _answer()..['current'] = {'temperature_2m': 'warm'},
    ]) {
      expect(weatherFromOpenMeteo(broken, fixturePlace, _now), isNull);
    }
  });

  test('the weather codes fall into the skies the app tells apart', () {
    expect(
      {
        for (final code in [
          0,
          1,
          2,
          3,
          45,
          48,
          51,
          65,
          67,
          71,
          77,
          80,
          82,
          85,
          95,
          99,
        ])
          code: Sky.ofCode(code),
      },
      {
        0: Sky.clear,
        1: Sky.clear,
        2: Sky.partlyCloudy,
        3: Sky.cloudy,
        45: Sky.fog,
        48: Sky.fog,
        51: Sky.rain,
        65: Sky.rain,
        67: Sky.rain,
        71: Sky.snow,
        77: Sky.snow,
        80: Sky.rain,
        82: Sky.rain,
        85: Sky.snow,
        95: Sky.thunder,
        99: Sky.thunder,
      },
    );
  });

  test('the places of a search carry their region', () {
    final places = placesFromOpenMeteo({
      'results': [
        {
          'name': 'Wien',
          'latitude': 48.20849,
          'longitude': 16.37208,
          'country': 'Österreich',
          'admin1': 'Wien',
        },
        {
          'name': 'Linz',
          'latitude': 48.30639,
          'longitude': 14.28611,
          'country': 'Österreich',
          'admin1': 'Oberösterreich',
        },
        {'name': 'Nowhere', 'latitude': 1, 'longitude': 2},
        {'name': 'Broken'},
      ],
    });
    expect(places.map((place) => (place.name, place.region)), [
      ('Wien', 'Österreich'),
      ('Linz', 'Oberösterreich, Österreich'),
      ('Nowhere', null),
    ]);
    // A search without a hit has no list at all.
    expect(placesFromOpenMeteo({'generationtime_ms': 0.5}), isEmpty);
  });

  test('weather and place survive being stored', () {
    final weather = weatherFromOpenMeteo(_answer(), fixturePlace, _now)!;
    final again = Weather.fromJson(weather.toJson())!;
    expect(again.place, fixturePlace);
    expect(again.place.region, fixturePlace.region);
    expect(again.fetchedAt, _now);
    expect(again.temperature, weather.temperature);
    expect(again.sky, weather.sky);
    expect(again.hours.length, weather.hours.length);
    expect(again.hours.last.rainChance, 65);
    expect(Weather.fromJson({'fetchedAt': 'x'}), isNull);
    expect(
      Place.fromJson({'name': 'X', 'latitude': 120, 'longitude': 0}),
      isNull,
    );
  });

  group('the weather the app holds', () {
    late MemoryJsonStore store;
    late FixtureWeather source;
    late DateTime now;
    late WeatherController weather;

    setUp(() {
      store = MemoryJsonStore();
      source = FixtureWeather();
      now = _now;
      weather = WeatherController(
        store: store,
        source: source,
        clock: () => now,
      );
    });

    test('asks nothing without a place', () async {
      await weather.refresh();
      expect(source.asked, 0);
      expect(weather.weather, isNull);
    });

    test('asks once an hour and stores the answer', () async {
      weather.place = fixturePlace;
      await pumpEventQueue();
      expect(source.asked, 1);
      expect(weather.weather!.temperature, 12.4);
      expect(await store.read(StoreKeys.weather), isNotNull);

      now = _now.add(const Duration(minutes: 59));
      await weather.refresh();
      expect(source.asked, 1);
      now = _now.add(const Duration(minutes: 61));
      await weather.refresh();
      expect(source.asked, 2);
    });

    test('starts from the stored answer of today', () async {
      weather.place = fixturePlace;
      await pumpEventQueue();
      final next = WeatherController(
        store: store,
        source: source,
        clock: () => _now.add(const Duration(minutes: 20)),
      )..place = fixturePlace;
      await pumpEventQueue();
      expect(next.weather, isNotNull);
      expect(source.asked, 1);

      // Yesterday's answer is not today's weather.
      source.reachable = false;
      final tomorrow = WeatherController(
        store: store,
        source: source,
        clock: () => _now.add(const Duration(days: 1)),
      )..place = fixturePlace;
      await pumpEventQueue();
      expect(tomorrow.weather, isNull);
    });

    test('keeps what it shows when the service cannot be reached', () async {
      weather.place = fixturePlace;
      await pumpEventQueue();
      source.reachable = false;
      now = _now.add(const Duration(hours: 2));
      await weather.refresh();
      expect(weather.weather!.temperature, 12.4);
    });

    test('another place asks again, and none drops the weather', () async {
      weather.place = fixturePlace;
      await pumpEventQueue();
      weather.place = const Place(
        name: 'Graz',
        latitude: 47.07,
        longitude: 15.44,
      );
      await pumpEventQueue();
      expect(source.asked, 2);
      expect(weather.weather!.place.name, 'Graz');
      weather.place = null;
      expect(weather.weather, isNull);
    });
  });
}
