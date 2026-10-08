import 'package:flutter/foundation.dart';

/// What the last refresh in the background left behind, so that it can be
/// seen whether it runs.
@immutable
class SyncReport {
  const SyncReport({
    required this.at,
    this.seconds,
    this.full = false,
    this.error,
  });

  /// When the run ended.
  final DateTime at;

  /// How long reading and storing took.
  final double? seconds;

  /// Whether everything was read, rather than only what is new.
  final bool full;

  /// Why the run stored nothing; null after a run that did.
  final String? error;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'seconds': seconds,
    'full': full,
    'error': error,
  };

  static SyncReport? fromJson(Object? json) {
    if (json case {'at': final String text}) {
      final at = DateTime.tryParse(text);
      if (at == null) return null;
      return SyncReport(
        at: at,
        seconds: switch (json['seconds']) {
          final num v => v.toDouble(),
          _ => null,
        },
        full: json['full'] == true,
        error: switch (json['error']) {
          final String v => v,
          _ => null,
        },
      );
    }
    return null;
  }
}
