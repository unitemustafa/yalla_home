import 'package:flutter/foundation.dart';

class PasswordChangedNotifier extends ChangeNotifier {
  PasswordChangedNotifier._();

  static final instance = PasswordChangedNotifier._();

  int _eventId = 0;

  int get eventId => _eventId;

  void notifyPasswordChanged() {
    _eventId += 1;
    notifyListeners();
  }
}
