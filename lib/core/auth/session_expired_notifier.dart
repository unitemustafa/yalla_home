import 'package:flutter/foundation.dart';

class SessionExpiredNotifier extends ChangeNotifier {
  SessionExpiredNotifier._();

  static final instance = SessionExpiredNotifier._();

  int _eventId = 0;

  int get eventId => _eventId;

  void notifyExpired() {
    _eventId += 1;
    notifyListeners();
  }
}
