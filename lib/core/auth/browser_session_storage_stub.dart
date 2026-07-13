import 'browser_session_storage_base.dart';

BrowserSessionStorage createBrowserSessionStorage() {
  return const _UnavailableBrowserSessionStorage();
}

final class _UnavailableBrowserSessionStorage implements BrowserSessionStorage {
  const _UnavailableBrowserSessionStorage();

  @override
  void delete(String key) {}

  @override
  String? read(String key) => null;

  @override
  void write(String key, String value) {}
}
