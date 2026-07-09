import 'package:flutter/foundation.dart';

import '../../data/courier_profile_api.dart';
import '../../domain/courier_account.dart';

class CourierProfileController extends ChangeNotifier {
  CourierProfileController({CourierProfileApi api = const CourierProfileApi()})
    : _api = api;

  final CourierProfileApi _api;

  CourierAccount? _account;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  Future<void>? _loadInFlight;

  CourierAccount? get account => _account;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> loadAccountIfNeeded() async {
    if (_hasLoaded) return;
    await loadAccount();
  }

  Future<void> loadAccount() async {
    final activeLoad = _loadInFlight;
    if (activeLoad != null) return activeLoad;

    final loadFuture = _loadAccount();
    _loadInFlight = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_loadInFlight, loadFuture)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> refresh() => loadAccount();

  Future<void> _loadAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _account = await _api.loadAccount();
      _hasLoaded = true;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _arabicError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _arabicError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'تعذر تحميل بيانات حساب المندوب. حاول مرة أخرى.';
    }
    return message;
  }
}
