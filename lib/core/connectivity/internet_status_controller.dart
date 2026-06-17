import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'internet_reachability.dart';

class InternetStatusController extends ChangeNotifier {
  InternetStatusController({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _verificationTimer;
  bool _hasStatus = false;
  bool _isOffline = false;
  bool _isChecking = false;
  bool _started = false;
  bool _isDisposed = false;

  bool get hasStatus => _hasStatus;
  bool get isOffline => _hasStatus && _isOffline;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) => unawaited(_updateFromConnectivity(result)),
      onError: (_) => _setStatus(isOffline: false),
    );
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(refresh()),
    );

    await refresh();
  }

  Future<void> refresh() async {
    if (_isChecking || _isDisposed) return;
    _isChecking = true;

    try {
      final result = await _connectivity.checkConnectivity();
      await _updateFromConnectivity(result);
    } catch (_) {
      _setStatus(isOffline: false);
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _updateFromConnectivity(List<ConnectivityResult> result) async {
    if (_isDisposed) return;

    final hasNetwork =
        result.isNotEmpty &&
        result.any((connection) => connection != ConnectivityResult.none);

    if (!hasNetwork) {
      _setStatus(isOffline: true);
      return;
    }

    final canReachInternet = await hasInternetAccess();
    if (_isDisposed) return;

    _setStatus(isOffline: canReachInternet == false);
  }

  void _setStatus({required bool isOffline}) {
    if (_isDisposed) return;
    if (_hasStatus && _isOffline == isOffline) return;

    _hasStatus = true;
    _isOffline = isOffline;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }
}

class InternetStatusScope extends InheritedNotifier<InternetStatusController> {
  const InternetStatusScope({
    super.key,
    required InternetStatusController controller,
    required super.child,
  }) : super(notifier: controller);

  static InternetStatusController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InternetStatusScope>()
        ?.notifier;
  }
}
