import 'dart:convert';
import 'dart:io';

import 'json_store.dart';

/// A place the weather is asked for: what the user picked in the profile.
class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
  });

  final String name;

  /// Where the place lies, to tell two of the same name apart.
  final String? region;
  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
    'name': name,
    'region': ?region,
    'latitude': latitude,
    'longitude': longitude,
  };

  static Place? fromJson(Object? json) {
    if (json
        case {
          'name': final String name,
          'latitude': final num latitude,
          'longitude': final num longitude,
        }
        when name.isNotEmpty &&
            latitude.abs() <= 90 &&
            longitude.abs() <= 180) {
      return Place(
        name: name,
        region: switch (json['region']) {
          final String region when region.isNotEmpty => region,
          _ => null,
        },
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);
}

/// What the sky does, as far as the app tells it apart.
enum Sky {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  rain,
  snow,
  thunder;

  /// The sky of a WMO weather code, as weather services report it.
  static Sky ofCode(int code) => switch (code) {
    0 || 1 => Sky.clear,
    2 => Sky.partlyCloudy,
    3 => Sky.cloudy,
    45 || 48 => Sky.fog,
    >= 71 && <= 77 || 85 || 86 => Sky.snow,
    >= 95 => Sky.thunder,
    >= 51 && <= 82 => Sky.rain,
    _ => Sky.cloudy,
  };
}

/// One hour of a day's forecast.
class WeatherHour {
  const WeatherHour({
    required this.hour,
    required this.temperature,
    required this.rainChance,
    required this.sky,
  });

  /// The hour of the day, 0 to 23.
  final int hour;

  /// In degrees Celsius.
  final double temperature;

  /// In percent.
  final int rainChance;
  final Sky sky;
}

/// The weather of one day at a [Place].
class Weather {
  const Weather({
    required this.place,
    required this.fetchedAt,
    required this.temperature,
    required this.sky,
    required this.high,
    required this.low,
    required this.rainChance,
    required this.hours,
  });

  final Place place;
  final DateTime fetchedAt;

  /// Now, in degrees Celsius.
  final double temperature;
  final Sky sky;
  final double high;
  final double low;

  /// The highest chance of rain of the day, in percent.
  final int rainChance;

  /// The hours of the day in order; may be fewer than 24.
  final List<WeatherHour> hours;

  /// The day the forecast is for.
  DateTime get day => DateTime(fetchedAt.year, fetchedAt.month, fetchedAt.day);

  Map<String, Object?> toJson() => {
    'place': place.toJson(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'temperature': temperature,
    'sky': sky.name,
    'high': high,
    'low': low,
    'rainChance': rainChance,
    'hours': [
      for (final hour in hours)
        [hour.hour, hour.temperature, hour.rainChance, hour.sky.name],
    ],
  };

  static Sky? _sky(Object? name) {
    for (final sky in Sky.values) {
      if (sky.name == name) return sky;
    }
    return null;
  }

  static Weather? fromJson(Object? json) {
    if (json case {
      'fetchedAt': final String at,
      'temperature': final num temperature,
      'high': final num high,
      'low': final num low,
      'rainChance': final num rainChance,
      'hours': final List<Object?> hours,
    }) {
      final place = Place.fromJson(json['place']);
      final fetchedAt = DateTime.tryParse(at);
      final sky = _sky(json['sky']);
      if (place == null || fetchedAt == null || sky == null) return null;
      return Weather(
        place: place,
        fetchedAt: fetchedAt,
        temperature: temperature.toDouble(),
        sky: sky,
        high: high.toDouble(),
        low: low.toDouble(),
        rainChance: rainChance.round(),
        hours: [
          for (final entry in hours)
            if (entry case [
              final int hour,
              final num degrees,
              final num chance,
              final Object? name,
            ])
              if (_sky(name) case final sky?)
                WeatherHour(
                  hour: hour,
                  temperature: degrees.toDouble(),
                  rainChance: chance.round(),
                  sky: sky,
                ),
        ],
      );
    }
    return null;
  }
}

/// Where the weather and the places come from. Both answer null or nothing
/// when the service cannot be reached; the app then goes without.
abstract interface class WeatherSource {
  Future<Weather?> today(Place place, DateTime now);

  /// Places named like [query], the likeliest first, named in [language].
  Future<List<Place>> search(String query, String language);
}

/// The answer of Open-Meteo's forecast for one day, read into a [Weather];
/// null when it is not what the service documents.
Weather? weatherFromOpenMeteo(Object? json, Place place, DateTime now) {
  if (json case {
    'current': {
      'temperature_2m': final num temperature,
      'weather_code': final num code,
    },
    'daily': {
      'temperature_2m_max': [final num high, ...],
      'temperature_2m_min': [final num low, ...],
      'precipitation_probability_max': [final Object? chance, ...],
    },
    'hourly': {
      'time': final List<Object?> times,
      'temperature_2m': final List<Object?> degrees,
      'precipitation_probability': final List<Object?> chances,
      'weather_code': final List<Object?> codes,
    },
  }) {
    final hours = <WeatherHour>[];
    for (var i = 0; i < times.length; i++) {
      if (i >= degrees.length || i >= chances.length || i >= codes.length) {
        break;
      }
      if ((times[i], degrees[i], codes[i]) case (
        final String time,
        final num degree,
        final num hourCode,
      )) {
        final at = DateTime.tryParse(time);
        if (at == null) continue;
        hours.add(
          WeatherHour(
            hour: at.hour,
            temperature: degree.toDouble(),
            rainChance: switch (chances[i]) {
              final num chance => chance.round(),
              _ => 0,
            },
            sky: Sky.ofCode(hourCode.round()),
          ),
        );
      }
    }
    return Weather(
      place: place,
      fetchedAt: now,
      temperature: temperature.toDouble(),
      sky: Sky.ofCode(code.round()),
      high: high.toDouble(),
      low: low.toDouble(),
      rainChance: chance is num ? chance.round() : 0,
      hours: hours,
    );
  }
  return null;
}

String? _regionOf(Map<Object?, Object?> result, String name) {
  final parts = [
    if (result['admin1'] case final String region when region != name) region,
    if (result['country'] case final String country) country,
  ];
  return parts.isEmpty ? null : parts.join(', ');
}

/// The places in the answer of Open-Meteo's search.
List<Place> placesFromOpenMeteo(Object? json) {
  if (json case {'results': final List<Object?> results}) {
    return [
      for (final result in results)
        if (result case {
          'name': final String name,
          'latitude': final num latitude,
          'longitude': final num longitude,
        })
          Place(
            name: name,
            region: _regionOf(result, name),
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          ),
    ];
  }
  return const [];
}

/// Open-Meteo: free, without an account or a key. The only thing in the app
/// that uses the network, and only once a place is set.
class OpenMeteoWeather implements WeatherSource {
  const OpenMeteoWeather();

  static const Duration _patience = Duration(seconds: 8);

  Future<Object?> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _patience;
    try {
      final request = await client.getUrl(uri).timeout(_patience);
      final response = await request.close().timeout(_patience);
      if (response.statusCode != HttpStatus.ok) return null;
      final text = await utf8.decodeStream(response).timeout(_patience);
      return jsonDecode(text);
    } on Exception {
      // No network, a slow one or an answer that is not JSON.
      return null;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Weather?> today(Place place, DateTime now) async {
    final json = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${place.latitude}',
        'longitude': '${place.longitude}',
        'current': 'temperature_2m,weather_code',
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'daily':
            'temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '1',
      }),
    );
    return weatherFromOpenMeteo(json, place, now);
  }

  @override
  Future<List<Place>> search(String query, String language) async {
    final json = await _get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '6',
        'language': language,
        'format': 'json',
      }),
    );
    return placesFromOpenMeteo(json);
  }
}

/// How long a stored forecast is shown before the service is asked again.
const Duration weatherKeptFor = Duration(hours: 1);

/// The stored forecast, if it is for [place] and for the day of [now].
Future<Weather?> storedWeather(
  JsonStore store,
  Place place,
  DateTime now,
) async {
  final weather = Weather.fromJson(await store.read(StoreKeys.weather));
  if (weather == null || weather.place != place) return null;
  final today = DateTime(now.year, now.month, now.day);
  return weather.day == today ? weather : null;
}
