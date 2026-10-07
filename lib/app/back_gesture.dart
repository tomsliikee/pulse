import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Lets a route follow Android's predictive back gesture with a transition
/// of its own.
///
/// The framework only listens for the gesture inside its page transition
/// builders, and it answers a release by restarting the route's animation
/// from the top. A route that draws its own transition would jump there, so
/// the gesture gets its own value, [backProgress], and the route's animation
/// is left alone until the pop.
mixin BackGestureRoute<T> on ModalRoute<T> {
  late final _BackGestureObserver _observer = _BackGestureObserver(this);
  AnimationController? _progress;
  SwipeEdge _edge = SwipeEdge.left;

  /// 0 at rest, up to 1 while the finger pulls. It keeps its value after a
  /// release, so the closing transition starts from where the finger left.
  Animation<double> get backProgress => _progress ?? kAlwaysDismissedAnimation;

  /// The screen edge the running gesture started from.
  SwipeEdge get backEdge => _edge;

  @override
  void install() {
    super.install();
    _progress = AnimationController(
      vsync: navigator!,
      duration: const Duration(milliseconds: 200),
    );
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    _progress?.dispose();
    _progress = null;
    super.dispose();
  }

  bool _start(PredictiveBackEvent event) {
    if (event.isButtonEvent || !isCurrent || !popGestureEnabled) return false;
    _edge = event.swipeEdge;
    _progress?.value = event.progress;
    navigator?.didStartUserGesture();
    return true;
  }

  void _update(PredictiveBackEvent event) {
    // Something else navigated during the gesture.
    if (!isCurrent) return;
    _progress?.value = event.progress;
  }

  void _commit() {
    final navigator = this.navigator;
    if (isCurrent) navigator?.pop();
    navigator?.didStopUserGesture();
  }

  void _cancel() {
    _progress?.animateBack(0, curve: Curves.easeOut);
    navigator?.didStopUserGesture();
  }
}

class _BackGestureObserver with WidgetsBindingObserver {
  _BackGestureObserver(this.route);

  final BackGestureRoute<dynamic> route;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      route._start(backEvent);

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      route._update(backEvent);

  @override
  void handleCommitBackGesture() => route._commit();

  @override
  void handleCancelBackGesture() => route._cancel();
}
