import 'package:web/web.dart' as web;

import 'browser_session_storage_base.dart';

BrowserSessionStorage createBrowserSessionStorage() {
  return const WebBrowserSessionStorage();
}

final class WebBrowserSessionStorage implements BrowserSessionStorage {
  const WebBrowserSessionStorage();

  @override
  void delete(String key) {
    web.window.sessionStorage.removeItem(key);
  }

  @override
  String? read(String key) => web.window.sessionStorage.getItem(key);

  @override
  void write(String key, String value) {
    web.window.sessionStorage.setItem(key, value);
  }
}
