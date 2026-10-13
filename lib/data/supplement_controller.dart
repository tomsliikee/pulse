import 'package:flutter/foundation.dart';

import 'json_store.dart';
import 'supplements.dart';

/// Holds the user's supplements and what they took of them, and keeps
/// both in the store. Nothing of it comes from or goes to the health
/// store, which has no place for supplements.
class SupplementController extends ChangeNotifier {
  SupplementController(this._store, {this.clock = DateTime.now});

  final JsonStore _store;

  /// Tests pass a fixed time.
  final DateTime Function() clock;
  SupplementData _data = const SupplementData();
  bool _disposed = false;

  SupplementData get data => _data;

  DateTime get now => clock();

  Future<void> load() async {
    final data = SupplementData.fromJson(
      await _store.read(StoreKeys.supplements),
    );
    if (_disposed) return;
    _data = data;
    notifyListeners();
  }

  Future<void> _set(SupplementData data) async {
    _data = data;
    notifyListeners();
    await _store.write(StoreKeys.supplements, data.toJson());
  }

  /// Puts [supplement] on the list, or changes the one with its key.
  Future<void> save(Supplement supplement) =>
      _set(_data.withSupplement(supplement));

  /// Puts the preset called [id] on the list as the app offers it.
  Future<Supplement?> addPreset(String id) async {
    final preset = presetOf(id);
    if (preset == null) return null;
    final known = _data.byKey(id);
    final supplement = known == null
        ? preset.added(clock())
        : known.copyWith(removedAt: () => null);
    await save(supplement);
    return supplement;
  }

  Future<void> remove(String key) => _set(_data.without(key, clock()));

  /// Notes that [supplement] was taken at [at], now where none is given,
  /// in its own dose unless another is given. Returns what was noted.
  Future<Intake> take(
    Supplement supplement, {
    DateTime? at,
    double? Function()? amount,
    SupplementUnit? Function()? unit,
    double? Function()? caffeineMg,
  }) async {
    final intake = Intake(
      key: supplement.key,
      at: at ?? clock(),
      amount: amount == null ? supplement.amount : amount(),
      unit: unit == null ? supplement.unit : unit(),
      caffeineMg: caffeineMg == null ? supplement.caffeineMg : caffeineMg(),
    );
    await _set(_data.withIntake(intake));
    return intake;
  }

  /// Puts [intake] back as it was, after it was taken away.
  Future<void> restore(Intake intake) => _set(_data.withIntake(intake));

  Future<void> untake(Intake intake) => _set(_data.withoutIntake(intake));

  Future<void> setMinute(SupplementTime time, int minute) =>
      _set(_data.withMinute(time, minute));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
