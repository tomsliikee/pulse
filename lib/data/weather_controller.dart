import 'package:flutter/foundation.dart';

import 'json_store.dart';
import 'weather.dart';

/// The weather of today at the place of the profile. Asks the service at
/// most once in [weatherKeptFor] and keeps the answer for the next start.
/// Without a place it asks nothing and holds nothing.
class WeatherController extends ChangeNotifier {
  WeatherController({
    required this._store,
    required this._source,
    this._clock = DateTime.now,
  });

  final JsonStore _store;
  final WeatherSource _source;
  final DateTime Function() _clock;

  Place? _place;
  Weather? _weather;
  bool _loading = false;
  bool _disposed = false;

  /// Null without a place, before the first answer and when the service
  /// could not be reached and nothing of today is stored.
  Weather? get weather => _weather;

  WeatherSource get source => _source;

  /// The place of the profile; a change asks again.
  set place(Place? value) {
    if (value == _place) return;
    _place = value;
    _weather = null;
    notifyListeners();
    refresh();
  }

  /// Brings the weather up to date, from the store where that is fresh
  /// enough and from the service otherwise.
  Future<void> refresh() async {
    final place = _place;
    if (place == null || _loading) return;
    final now = _clock();
    final shown = _weather;
    if (shown != null &&
        shown.day == DateTime(now.year, now.month, now.day) &&
        now.difference(shown.fetchedAt) < weatherKeptFor) {
      return;
    }
    _loading = true;
    try {
      final stored = await storedWeather(_store, place, now);
      if (_disposed || place != _place) return;
      if (stored != null) {
        _weather = stored;
        notifyListeners();
        if (now.difference(stored.fetchedAt) < weatherKeptFor) return;
      }
      final fresh = await _source.today(place, now);
      if (_disposed || place != _place || fresh == null) return;
      _weather = fresh;
      notifyListeners();
      await _store.write(StoreKeys.weather, fresh.toJson());
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
